package translation

import (
	"context"
	"errors"
	"strings"
	"unicode/utf8"
)

const MaxInputRunes = 12_000

var (
	ErrEmptyInput   = errors.New("text is empty")
	ErrInputTooLong = errors.New("text exceeds 12,000 characters")
)

type Backend interface {
	Translate(ctx context.Context, text string, onDelta func(string)) (string, error)
}

type Service struct {
	backend Backend
}

func New(backend Backend) *Service {
	return &Service{backend: backend}
}

func (s *Service) Translate(ctx context.Context, text string, onDelta func(string)) (string, error) {
	text = strings.TrimSpace(text)
	if text == "" {
		return "", ErrEmptyInput
	}
	if utf8.RuneCountInString(text) > MaxInputRunes {
		return "", ErrInputTooLong
	}
	return s.backend.Translate(ctx, text, onDelta)
}
