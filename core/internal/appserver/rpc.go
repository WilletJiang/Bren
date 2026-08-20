package appserver

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
)

type wireMessage struct {
	ID     json.RawMessage `json:"id,omitempty"`
	Method string          `json:"method,omitempty"`
	Params json.RawMessage `json:"params,omitempty"`
	Result json.RawMessage `json:"result,omitempty"`
	Error  *rpcError       `json:"error,omitempty"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func (c *Client) call(ctx context.Context, method string, params any, result any) error {
	id := c.nextID.Add(1)
	key := fmt.Sprintf("%d", id)
	responseChannel := make(chan wireMessage, 1)
	c.pendingMu.Lock()
	c.pending[key] = responseChannel
	c.pendingMu.Unlock()

	if err := c.send(map[string]any{"id": id, "method": method, "params": params}); err != nil {
		c.removePending(key)
		return err
	}

	select {
	case <-ctx.Done():
		c.removePending(key)
		return ctx.Err()
	case <-c.done:
		c.removePending(key)
		return errors.New("app-server stopped")
	case response := <-responseChannel:
		if response.Error != nil {
			return fmt.Errorf("rpc %d: %s", response.Error.Code, response.Error.Message)
		}
		if result == nil || len(response.Result) == 0 {
			return nil
		}
		if err := json.Unmarshal(response.Result, result); err != nil {
			return fmt.Errorf("decode %s response: %w", method, err)
		}
		return nil
	}
}

func (c *Client) notify(method string, params any) error {
	return c.send(map[string]any{"method": method, "params": params})
}

func (c *Client) send(message any) error {
	encoded, err := json.Marshal(message)
	if err != nil {
		return err
	}
	encoded = append(encoded, '\n')
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_, err = c.stdin.Write(encoded)
	return err
}

func (c *Client) readLoop(reader io.Reader) {
	defer close(c.done)
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 64*1024), 8*1024*1024)
	for scanner.Scan() {
		var message wireMessage
		if err := json.Unmarshal(scanner.Bytes(), &message); err != nil {
			continue
		}
		if len(message.ID) > 0 && message.Method == "" {
			key := string(message.ID)
			c.pendingMu.Lock()
			channel := c.pending[key]
			delete(c.pending, key)
			c.pendingMu.Unlock()
			if channel != nil {
				channel <- message
			}
			continue
		}
		if len(message.ID) > 0 && message.Method != "" {
			_ = c.send(map[string]any{
				"id": message.ID,
				"error": map[string]any{
					"code":    -32601,
					"message": "Bren does not support server-initiated requests",
				},
			})
			continue
		}
		if message.Method != "" {
			c.notifications <- message
		}
	}
}

func (c *Client) removePending(key string) {
	c.pendingMu.Lock()
	delete(c.pending, key)
	c.pendingMu.Unlock()
}
