package transport

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"sync"
	"time"

	"bren/internal/protocol"
	"bren/internal/translation"
)

type Translator interface {
	Translate(ctx context.Context, text string, onDelta func(string)) (string, error)
}

type Server struct {
	translator Translator
	model      string
	writerMu   sync.Mutex
	activeMu   sync.Mutex
	active     map[string]context.CancelFunc
	wait       sync.WaitGroup
}

const translationTimeout = 30 * time.Second

func New(translator Translator, model string) *Server {
	return &Server{
		translator: translator,
		model:      model,
		active:     make(map[string]context.CancelFunc),
	}
}

func (s *Server) Serve(ctx context.Context, reader io.Reader, writer io.Writer) error {
	if err := s.write(writer, protocol.NewEvent("", "ready", map[string]any{
		"backend": "codex-app-server",
		"model":   s.model,
		"version": "0.1.0",
	})); err != nil {
		return err
	}

	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 64*1024), 4*1024*1024)
	for scanner.Scan() {
		var request protocol.Request
		if err := json.Unmarshal(scanner.Bytes(), &request); err != nil {
			if writeErr := s.write(writer, protocol.NewError("", "invalid_json", err.Error(), false)); writeErr != nil {
				return writeErr
			}
			continue
		}
		if request.Version != protocol.Version {
			if err := s.write(writer, protocol.NewError(request.ID, "unsupported_version", "expected protocol version 1", false)); err != nil {
				return err
			}
			continue
		}
		if request.ID == "" {
			if err := s.write(writer, protocol.NewError("", "invalid_request", "id is required", false)); err != nil {
				return err
			}
			continue
		}

		switch request.Method {
		case "translate":
			s.startTranslation(ctx, writer, request)
		case "cancel":
			s.cancel(writer, request)
		case "health":
			if err := s.write(writer, protocol.NewEvent(request.ID, "completed", map[string]bool{"ok": true})); err != nil {
				return err
			}
		default:
			if err := s.write(writer, protocol.NewError(request.ID, "unknown_method", fmt.Sprintf("unknown method %q", request.Method), false)); err != nil {
				return err
			}
		}
	}

	s.cancelAll()
	s.wait.Wait()
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read Bren protocol: %w", err)
	}
	return nil
}

func (s *Server) startTranslation(parent context.Context, writer io.Writer, request protocol.Request) {
	var params protocol.TranslateParams
	if err := json.Unmarshal(request.Params, &params); err != nil {
		_ = s.write(writer, protocol.NewError(request.ID, "invalid_params", err.Error(), false))
		return
	}

	ctx, cancel := context.WithTimeout(parent, translationTimeout)
	s.activeMu.Lock()
	if _, exists := s.active[request.ID]; exists {
		s.activeMu.Unlock()
		cancel()
		_ = s.write(writer, protocol.NewError(request.ID, "duplicate_id", "request id is already active", false))
		return
	}
	for _, activeCancel := range s.active {
		activeCancel()
	}
	s.active[request.ID] = cancel
	s.activeMu.Unlock()

	s.wait.Add(1)
	go func() {
		defer s.wait.Done()
		defer s.removeActive(request.ID)
		startedAt := time.Now()
		if err := s.write(writer, protocol.NewEvent(request.ID, "started", map[string]string{"model": s.model})); err != nil {
			return
		}
		result, err := s.translator.Translate(ctx, params.Text, func(delta string) {
			_ = s.write(writer, protocol.NewEvent(request.ID, "delta", map[string]string{"text": delta}))
		})
		if err != nil {
			if errors.Is(err, context.Canceled) {
				_ = s.write(writer, protocol.NewEvent(request.ID, "cancelled", nil))
				return
			}
			if errors.Is(err, context.DeadlineExceeded) {
				_ = s.write(writer, protocol.NewError(request.ID, "timeout", "translation timed out", true))
				return
			}
			code := "backend_error"
			if errors.Is(err, translation.ErrEmptyInput) || errors.Is(err, translation.ErrInputTooLong) {
				code = "invalid_request"
			}
			_ = s.write(writer, protocol.NewError(request.ID, code, err.Error(), code == "backend_error"))
			return
		}
		_ = s.write(writer, protocol.NewEvent(request.ID, "completed", map[string]any{
			"text":      result,
			"latencyMs": time.Since(startedAt).Milliseconds(),
		}))
	}()
}

func (s *Server) cancel(writer io.Writer, request protocol.Request) {
	var params protocol.CancelParams
	if err := json.Unmarshal(request.Params, &params); err != nil || params.RequestID == "" {
		_ = s.write(writer, protocol.NewError(request.ID, "invalid_params", "requestId is required", false))
		return
	}
	s.activeMu.Lock()
	cancel := s.active[params.RequestID]
	s.activeMu.Unlock()
	if cancel != nil {
		cancel()
	}
	_ = s.write(writer, protocol.NewEvent(request.ID, "completed", map[string]bool{"cancelled": cancel != nil}))
}

func (s *Server) removeActive(id string) {
	s.activeMu.Lock()
	delete(s.active, id)
	s.activeMu.Unlock()
}

func (s *Server) cancelAll() {
	s.activeMu.Lock()
	for _, cancel := range s.active {
		cancel()
	}
	s.activeMu.Unlock()
}

func (s *Server) write(writer io.Writer, event protocol.Event) error {
	s.writerMu.Lock()
	defer s.writerMu.Unlock()
	return json.NewEncoder(writer).Encode(event)
}
