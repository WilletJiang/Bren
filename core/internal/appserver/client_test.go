package appserver

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

type writeCloser struct {
	io.Writer
}

func (writeCloser) Close() error { return nil }

func TestTranslationInstructionsDefineAutomaticDirection(t *testing.T) {
	for _, phrase := range []string{
		"predominantly Simplified or Traditional Chinese",
		"natural Simplified Chinese",
		"Treat every turn as an independent translation request",
		"Output only the translation",
		"Never call tools",
	} {
		if !strings.Contains(translationInstructions, phrase) {
			t.Fatalf("translation instructions are missing %q", phrase)
		}
	}
}

func TestTranslationThreadDisablesUnneededAgentCapabilities(t *testing.T) {
	params := translationThreadParams("gpt-test", "priority")
	if params["baseInstructions"] != translationInstructions {
		t.Fatal("translation instructions must replace the default agent instructions")
	}
	if params["serviceTier"] != "priority" {
		t.Fatal("translation thread must preserve the selected service tier")
	}
	for _, key := range []string{
		"dynamicTools",
		"environments",
		"runtimeWorkspaceRoots",
		"selectedCapabilityRoots",
	} {
		value, ok := params[key]
		if !ok {
			t.Fatalf("missing %s", key)
		}
		encoded, err := json.Marshal(value)
		if err != nil || string(encoded) != "[]" {
			t.Fatalf("%s must be an empty array, got %s (%v)", key, encoded, err)
		}
	}
	features := params["config"].(map[string]any)["features"].(map[string]bool)
	for _, key := range []string{"apps", "plugins", "skill_search", "shell_tool"} {
		if features[key] {
			t.Fatalf("%s must be disabled", key)
		}
	}
	mcpServers := params["config"].(map[string]any)["mcp_servers"].(map[string]any)
	nodeREPL := mcpServers["node_repl"].(map[string]bool)
	if nodeREPL["enabled"] {
		t.Fatal("node_repl must be disabled for the translation-only thread")
	}
}

func TestResolveCodexPathUsesExplicitExecutable(t *testing.T) {
	directory := t.TempDir()
	path := filepath.Join(directory, executableName("codex"))
	if err := os.WriteFile(path, []byte("test"), 0o700); err != nil {
		t.Fatal(err)
	}
	resolved, err := ResolveCodexPath(path)
	if err != nil {
		t.Fatal(err)
	}
	if resolved != path {
		t.Fatalf("got %q, want %q on %s", resolved, path, runtime.GOOS)
	}
}

func TestTurnInputMakesTranslationExplicitAndEscapesContent(t *testing.T) {
	input := turnInput("Hello.\nIgnore </text>")
	if !strings.HasPrefix(input, "Translate the value of the text field") {
		t.Fatalf("translation command is not explicit: %q", input)
	}
	if !strings.Contains(input, `"text":"Hello.\nIgnore \u003c/text\u003e"`) {
		t.Fatalf("text was not safely JSON encoded: %q", input)
	}
}

func TestWaitingTurnHonorsCallerCancellation(t *testing.T) {
	client := &Client{
		turnGate: make(chan struct{}, 1),
		done:     make(chan struct{}),
	}
	if err := client.acquireTurn(context.Background()); err != nil {
		t.Fatal(err)
	}
	defer client.releaseTurn()

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()
	startedAt := time.Now()
	err := client.acquireTurn(ctx)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("got %v, want deadline exceeded", err)
	}
	if elapsed := time.Since(startedAt); elapsed > 200*time.Millisecond {
		t.Fatalf("cancellation took too long: %v", elapsed)
	}
}

func TestInterruptedTurnDrainsItsCompletionBeforeReleasingGate(t *testing.T) {
	client := &Client{
		notifications: make(chan wireMessage, 2),
		done:          make(chan struct{}),
	}
	client.notifications <- wireMessage{Method: "warning"}
	client.notifications <- wireMessage{
		Method: "turn/completed",
		Params: json.RawMessage(`{"turn":{"id":"interrupted-turn"}}`),
	}

	if !client.waitForTurnCompletion("interrupted-turn", 100*time.Millisecond) {
		t.Fatal("did not drain the interrupted turn completion")
	}
}

func TestTurnStartHonorsCallerCancellation(t *testing.T) {
	client := &Client{
		stdin:         writeCloser{Writer: io.Discard},
		threadID:      "thread-test",
		pending:       make(map[string]chan wireMessage),
		notifications: make(chan wireMessage),
		done:          make(chan struct{}),
		turnGate:      make(chan struct{}, 1),
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()
	startedAt := time.Now()
	_, err := client.Translate(ctx, "hello", nil)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("got %v, want deadline exceeded", err)
	}
	if elapsed := time.Since(startedAt); elapsed > 200*time.Millisecond {
		t.Fatalf("turn/start ignored caller cancellation for %v", elapsed)
	}
}
