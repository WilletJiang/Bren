package protocol

import (
	"encoding/json"
	"testing"
)

func TestRequestRoundTrip(t *testing.T) {
	raw := []byte(`{"v":1,"id":"request-1","method":"translate","params":{"text":"hello"}}`)
	var request Request
	if err := json.Unmarshal(raw, &request); err != nil {
		t.Fatal(err)
	}
	if request.Version != Version || request.ID != "request-1" || request.Method != "translate" {
		t.Fatalf("unexpected request: %#v", request)
	}

	var params TranslateParams
	if err := json.Unmarshal(request.Params, &params); err != nil {
		t.Fatal(err)
	}
	if params.Text != "hello" {
		t.Fatalf("unexpected text: %q", params.Text)
	}
}

func TestNewErrorUsesStableEnvelope(t *testing.T) {
	event := NewError("request-1", "invalid_request", "text is empty", false)
	encoded, err := json.Marshal(event)
	if err != nil {
		t.Fatal(err)
	}
	want := `{"v":1,"id":"request-1","event":"error","error":{"code":"invalid_request","message":"text is empty","retryable":false}}`
	if string(encoded) != want {
		t.Fatalf("got %s, want %s", encoded, want)
	}
}
