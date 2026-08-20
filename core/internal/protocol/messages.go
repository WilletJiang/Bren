package protocol

import "encoding/json"

const Version = 1

type Request struct {
	Version int             `json:"v"`
	ID      string          `json:"id"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type TranslateParams struct {
	Text string `json:"text"`
}

type CancelParams struct {
	RequestID string `json:"requestId"`
}

type Event struct {
	Version int        `json:"v"`
	ID      string     `json:"id,omitempty"`
	Event   string     `json:"event"`
	Data    any        `json:"data,omitempty"`
	Error   *ErrorData `json:"error,omitempty"`
}

type ErrorData struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	Retryable bool   `json:"retryable"`
}

func NewEvent(id, name string, data any) Event {
	return Event{Version: Version, ID: id, Event: name, Data: data}
}

func NewError(id, code, message string, retryable bool) Event {
	return Event{
		Version: Version,
		ID:      id,
		Event:   "error",
		Error:   &ErrorData{Code: code, Message: message, Retryable: retryable},
	}
}
