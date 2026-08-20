package translation

import (
	"context"
	"errors"
	"strings"
	"testing"
)

type fakeBackend struct {
	received string
}

func (backend *fakeBackend) Translate(_ context.Context, text string, onDelta func(string)) (string, error) {
	backend.received = text
	onDelta("你")
	onDelta("好")
	return "你好", nil
}

func TestTranslateValidatesAndTrimsInput(t *testing.T) {
	backend := &fakeBackend{}
	service := New(backend)
	var streamed strings.Builder
	result, err := service.Translate(context.Background(), "  hello  ", func(delta string) {
		streamed.WriteString(delta)
	})
	if err != nil {
		t.Fatal(err)
	}
	if backend.received != "hello" || result != "你好" || streamed.String() != "你好" {
		t.Fatalf("received=%q result=%q streamed=%q", backend.received, result, streamed.String())
	}
}

func TestTranslateRejectsEmptyAndOversizedInput(t *testing.T) {
	service := New(&fakeBackend{})
	if _, err := service.Translate(context.Background(), " \n ", nil); !errors.Is(err, ErrEmptyInput) {
		t.Fatalf("got %v, want ErrEmptyInput", err)
	}
	if _, err := service.Translate(context.Background(), strings.Repeat("界", MaxInputRunes+1), nil); !errors.Is(err, ErrInputTooLong) {
		t.Fatalf("got %v, want ErrInputTooLong", err)
	}
}
