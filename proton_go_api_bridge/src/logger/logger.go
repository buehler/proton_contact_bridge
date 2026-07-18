package logger

import (
	"context"
	"fmt"
	"log/slog"
	"proton_go_api_bridge/native/utils"
	"strings"
)

var contextKeys = []string{
	"trace_id",
	"command",
	"auth_method",
}

type LogCallback func(slog.Level, string)

type handler struct {
	attrs []slog.Attr

	callbacks *utils.CallbackContainer[LogCallback]
}

func (h *handler) Enabled(_ context.Context, _ slog.Level) bool {
	return true
}

func (h *handler) Handle(ctx context.Context, record slog.Record) error {
	attrs := make([]slog.Attr, 0, len(h.attrs)+record.NumAttrs())
	attrs = append(attrs, h.attrs...)
	record.Attrs(func(attr slog.Attr) bool {
		attrs = append(attrs, attr)
		return true
	})
	for _, key := range contextKeys {
		if value := ctx.Value(key); value != nil {
			attrs = append(attrs, slog.Any(key, value))
		}
	}

	var builder strings.Builder
	builder.WriteString(record.Message)
	for _, attr := range attrs {
		if attr.Equal(slog.Attr{}) {
			continue
		}
		builder.WriteByte(' ')
		builder.WriteString(attr.Key)
		builder.WriteByte('=')
		builder.WriteString(fmt.Sprint(attr.Value.Any()))
	}

	platformLog(record.Level, builder.String())
	if h.callbacks != nil {
		for callback := range h.callbacks.Callbacks() {
			callback(record.Level, builder.String())
		}
	}
	return nil
}

func (h *handler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return &handler{
		attrs:     append(append([]slog.Attr(nil), h.attrs...), attrs...),
		callbacks: h.callbacks,
	}
}

func (h *handler) WithGroup(_ string) slog.Handler {
	return h
}

var logHandler *handler

func init() {
	logHandler = &handler{
		callbacks: utils.NewCallbackContainer[LogCallback](),
	}
	slog.SetDefault(slog.New(logHandler))
}

func RegisterLogCallback(ID uint32, callback LogCallback) {
	logHandler.callbacks.Register(ID, callback)
}

func UnregisterLogCallback(ID uint32) {
	logHandler.callbacks.Unregister(ID)
}
