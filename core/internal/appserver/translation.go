package appserver

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"
)

const translationInstructions = `You are Bren, a dedicated translation engine. Treat every turn as an independent translation request and ignore earlier turns when deciding direction or wording.

If the input is predominantly Simplified or Traditional Chinese, translate it into natural English. Otherwise, translate it into natural Simplified Chinese. For mixed-language text, infer the direction that makes the entire result most useful to a Chinese-English bilingual reader.

Preserve meaning, tone, names, numbers, code, Markdown, and line breaks. Do not add commentary, labels, quotes, alternatives, pronunciation, or explanations. Output only the translation. Never call tools.`

type turnError struct {
	Message string `json:"message"`
}

func (c *Client) initialize(ctx context.Context) error {
	var initialized struct {
		UserAgent string `json:"userAgent"`
	}
	if err := c.call(ctx, "initialize", map[string]any{
		"clientInfo": map[string]string{
			"name":    "bren",
			"title":   "Bren",
			"version": "0.1.0",
		},
		"capabilities": map[string]bool{
			"experimentalApi": true,
		},
	}, &initialized); err != nil {
		return fmt.Errorf("initialize app-server: %w", err)
	}
	if err := c.notify("initialized", map[string]any{}); err != nil {
		return fmt.Errorf("acknowledge app-server initialization: %w", err)
	}
	var started struct {
		Thread struct {
			ID string `json:"id"`
		} `json:"thread"`
	}
	if err := c.call(ctx, "thread/start", translationThreadParams(c.model, c.serviceTier), &started); err != nil {
		return fmt.Errorf("start translation thread: %w", err)
	}
	if started.Thread.ID == "" {
		return errors.New("app-server returned an empty thread id")
	}
	c.threadID = started.Thread.ID
	return nil
}

func translationThreadParams(model, serviceTier string) map[string]any {
	params := map[string]any{
		"model":                   model,
		"cwd":                     os.TempDir(),
		"ephemeral":               true,
		"approvalPolicy":          "never",
		"sandbox":                 "read-only",
		"serviceName":             "bren",
		"baseInstructions":        translationInstructions,
		"developerInstructions":   "Translate only the supplied text value.",
		"environments":            []any{},
		"runtimeWorkspaceRoots":   []string{},
		"selectedCapabilityRoots": []any{},
		"dynamicTools":            []any{},
		"config": map[string]any{
			"mcp_servers": map[string]any{
				"node_repl": map[string]bool{"enabled": false},
			},
			"features": map[string]bool{
				"apps":         false,
				"plugins":      false,
				"skill_search": false,
				"shell_tool":   false,
			},
		},
	}
	if serviceTier != "" {
		params["serviceTier"] = serviceTier
	}
	return params
}

func (c *Client) Translate(ctx context.Context, text string, onDelta func(string)) (string, error) {
	if err := c.acquireTurn(ctx); err != nil {
		return "", err
	}
	defer c.releaseTurn()

	startContext, cancelStart := context.WithTimeout(ctx, 10*time.Second)
	defer cancelStart()
	var started struct {
		Turn struct {
			ID string `json:"id"`
		} `json:"turn"`
	}
	params := map[string]any{
		"threadId": c.threadID,
		"input": []map[string]string{{
			"type": "text",
			"text": turnInput(text),
		}},
		"model":        c.model,
		"effort":       "low",
		"personality":  "none",
		"summary":      "none",
		"environments": []any{},
	}
	if c.serviceTier != "" {
		params["serviceTier"] = c.serviceTier
	}
	if err := c.call(startContext, "turn/start", params, &started); err != nil {
		return "", fmt.Errorf("start translation turn: %w", err)
	}
	if started.Turn.ID == "" {
		return "", errors.New("app-server returned an empty turn id")
	}

	turnID := started.Turn.ID
	var output strings.Builder
	var terminalError error
	for {
		select {
		case <-ctx.Done():
			c.stopTurn(c.threadID, turnID)
			return "", ctx.Err()
		case <-c.done:
			return "", errors.New("app-server stopped")
		case message := <-c.notifications:
			switch message.Method {
			case "item/agentMessage/delta":
				var event struct {
					TurnID string `json:"turnId"`
					Delta  string `json:"delta"`
				}
				if json.Unmarshal(message.Params, &event) == nil && event.TurnID == turnID {
					output.WriteString(event.Delta)
					if onDelta != nil {
						onDelta(event.Delta)
					}
				}
			case "error":
				var event struct {
					TurnID    string    `json:"turnId"`
					WillRetry bool      `json:"willRetry"`
					Error     turnError `json:"error"`
				}
				if json.Unmarshal(message.Params, &event) == nil && event.TurnID == turnID && !event.WillRetry {
					terminalError = errors.New(event.Error.Message)
				}
			case "turn/completed":
				var event struct {
					Turn struct {
						ID     string     `json:"id"`
						Status string     `json:"status"`
						Error  *turnError `json:"error"`
					} `json:"turn"`
				}
				if json.Unmarshal(message.Params, &event) != nil || event.Turn.ID != turnID {
					continue
				}
				switch event.Turn.Status {
				case "completed":
					return output.String(), nil
				case "interrupted":
					return "", context.Canceled
				default:
					if event.Turn.Error != nil && event.Turn.Error.Message != "" {
						return "", errors.New(event.Turn.Error.Message)
					}
					if terminalError != nil {
						return "", terminalError
					}
					return "", fmt.Errorf("translation turn ended with status %q", event.Turn.Status)
				}
			}
		}
	}
}

func (c *Client) stopTurn(threadID, turnID string) {
	c.interrupt(threadID, turnID)
	c.waitForTurnCompletion(turnID, 2*time.Second)
}

func (c *Client) waitForTurnCompletion(turnID string, timeout time.Duration) bool {
	timer := time.NewTimer(timeout)
	defer timer.Stop()
	for {
		select {
		case <-timer.C:
			return false
		case <-c.done:
			return false
		case message := <-c.notifications:
			if message.Method != "turn/completed" {
				continue
			}
			var event struct {
				Turn struct {
					ID string `json:"id"`
				} `json:"turn"`
			}
			if json.Unmarshal(message.Params, &event) == nil && event.Turn.ID == turnID {
				return true
			}
		}
	}
}

func (c *Client) acquireTurn(ctx context.Context) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	select {
	case c.turnGate <- struct{}{}:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	case <-c.done:
		return errors.New("app-server stopped")
	}
}

func (c *Client) releaseTurn() {
	<-c.turnGate
}

func turnInput(text string) string {
	encoded, _ := json.Marshal(map[string]string{"text": text})
	return "Translate the value of the text field in this JSON object now. Output only the translation.\n" + string(encoded)
}

func (c *Client) interrupt(threadID, turnID string) {
	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()
	var ignored struct{}
	_ = c.call(ctx, "turn/interrupt", map[string]string{
		"threadId": threadID,
		"turnId":   turnID,
	}, &ignored)
}
