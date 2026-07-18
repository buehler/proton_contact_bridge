//go:build !ios && !android && !darwin

package logger

import (
	"log/slog"
)

func platformLog(level slog.Level, message string) {
	println(level.String() + ": " + message)
}
