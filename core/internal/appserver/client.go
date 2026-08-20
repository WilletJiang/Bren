package appserver

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sync"
	"sync/atomic"
	"time"
)

type Config struct {
	CodexPath   string
	Model       string
	ServiceTier string
}

type Client struct {
	command       *exec.Cmd
	stdin         io.WriteCloser
	model         string
	serviceTier   string
	threadID      string
	nextID        atomic.Int64
	writeMu       sync.Mutex
	pendingMu     sync.Mutex
	pending       map[string]chan wireMessage
	notifications chan wireMessage
	done          chan struct{}
	closeOnce     sync.Once
	turnGate      chan struct{}
}

func Start(ctx context.Context, config Config) (*Client, error) {
	if config.Model == "" {
		config.Model = "gpt-5.6-luna"
	}
	if config.ServiceTier == "" && config.Model == "gpt-5.6-luna" {
		config.ServiceTier = "priority"
	}
	codexPath, err := ResolveCodexPath(config.CodexPath)
	if err != nil {
		return nil, err
	}

	command := exec.CommandContext(ctx, codexPath, "app-server")
	stdin, err := command.StdinPipe()
	if err != nil {
		return nil, fmt.Errorf("create app-server stdin: %w", err)
	}
	stdout, err := command.StdoutPipe()
	if err != nil {
		return nil, fmt.Errorf("create app-server stdout: %w", err)
	}
	command.Stderr = os.Stderr
	if err := command.Start(); err != nil {
		return nil, fmt.Errorf("start codex app-server: %w", err)
	}

	client := &Client{
		command:       command,
		stdin:         stdin,
		model:         config.Model,
		serviceTier:   config.ServiceTier,
		pending:       make(map[string]chan wireMessage),
		notifications: make(chan wireMessage, 256),
		done:          make(chan struct{}),
		turnGate:      make(chan struct{}, 1),
	}
	go client.readLoop(stdout)

	startupContext, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	if err := client.initialize(startupContext); err != nil {
		_ = client.Close()
		return nil, err
	}
	return client, nil
}

func ResolveCodexPath(explicit string) (string, error) {
	if explicit != "" {
		if info, err := os.Stat(explicit); err == nil && !info.IsDir() {
			return explicit, nil
		}
		return "", fmt.Errorf("codex executable not found at %q", explicit)
	}
	if runtime.GOOS == "darwin" {
		bundled := "/Applications/ChatGPT.app/Contents/Resources/codex"
		if info, err := os.Stat(bundled); err == nil && !info.IsDir() {
			return bundled, nil
		}
	}
	if path, err := exec.LookPath("codex"); err == nil {
		return path, nil
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return "", errors.New("codex is not on PATH and the home directory is unavailable")
	}
	candidates := []string{
		filepath.Join(home, ".local", "bin", executableName("codex")),
		filepath.Join(home, ".npm-global", "bin", executableName("codex")),
	}
	if runtime.GOOS == "darwin" {
		candidates = append(candidates, "/opt/homebrew/bin/codex", "/usr/local/bin/codex")
	}
	for _, candidate := range candidates {
		if info, statErr := os.Stat(candidate); statErr == nil && !info.IsDir() {
			return candidate, nil
		}
	}
	return "", errors.New("Codex CLI was not found; install Codex or set BREN_CODEX_PATH")
}

func executableName(name string) string {
	if runtime.GOOS == "windows" {
		return name + ".exe"
	}
	return name
}

func (c *Client) Model() string {
	return c.model
}

func (c *Client) Close() error {
	var closeError error
	c.closeOnce.Do(func() {
		closeError = c.stdin.Close()
		wait := make(chan error, 1)
		go func() { wait <- c.command.Wait() }()
		select {
		case err := <-wait:
			if closeError == nil && err != nil {
				closeError = err
			}
		case <-time.After(3 * time.Second):
			if c.command.Process != nil {
				_ = c.command.Process.Kill()
			}
			<-wait
		}
	})
	return closeError
}
