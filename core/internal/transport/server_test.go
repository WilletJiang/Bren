package transport

import (
	"bytes"
	"context"
	"encoding/json"
	"strings"
	"testing"

	"bren/internal/protocol"
)

type fakeTranslator struct{}

func (fakeTranslator) Translate(_ context.Context, text string, onDelta func(string)) (string, error) {
	if text != "hello" {
		panic("unexpected input: " + text)
	}
	onDelta("你")
	onDelta("好")
	return "你好", nil
}

func TestServerStreamsStableJSONLEvents(t *testing.T) {
	input := strings.NewReader(`{"v":1,"id":"translation-1","method":"translate","params":{"text":"hello"}}` + "\n")
	var output bytes.Buffer
	server := New(fakeTranslator{}, "gpt-test")
	if err := server.Serve(context.Background(), input, &output); err != nil {
		t.Fatal(err)
	}

	var events []protocol.Event
	decoder := json.NewDecoder(&output)
	for decoder.More() {
		var event protocol.Event
		if err := decoder.Decode(&event); err != nil {
			t.Fatal(err)
		}
		events = append(events, event)
	}
	if len(events) != 5 {
		t.Fatalf("got %d events: %#v", len(events), events)
	}
	want := []string{"ready", "started", "delta", "delta", "completed"}
	for index, name := range want {
		if events[index].Event != name {
			t.Fatalf("event %d is %q, want %q", index, events[index].Event, name)
		}
	}
}

func TestServerRejectsUnsupportedVersion(t *testing.T) {
	input := strings.NewReader(`{"v":2,"id":"request-1","method":"health"}` + "\n")
	var output bytes.Buffer
	if err := New(fakeTranslator{}, "gpt-test").Serve(context.Background(), input, &output); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(output.String(), `"code":"unsupported_version"`) {
		t.Fatalf("unexpected output: %s", output.String())
	}
}
