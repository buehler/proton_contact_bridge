//go:build android

package logger

/*
#cgo LDFLAGS: -llog
#include <android/log.h>
#include <stdlib.h>
*/
import "C"

import (
	"log/slog"
	"strings"
	"unicode/utf8"
	"unsafe"
)

func platformLog(level slog.Level, message string) {
	priority := C.ANDROID_LOG_WARN
	switch {
	case level <= slog.LevelDebug:
		priority = C.ANDROID_LOG_DEBUG
	case level < slog.LevelWarn:
		priority = C.ANDROID_LOG_INFO
	case level >= slog.LevelError:
		priority = C.ANDROID_LOG_ERROR
	}

	// Leave room for Logcat's tag and metadata; C strings cannot contain NUL.
	const chunkSize = 3800
	message = strings.ReplaceAll(strings.ToValidUTF8(message, "\uFFFD"), "\x00", "\\0")
	tag := C.CString("ProtonContactBridge")
	defer C.free(unsafe.Pointer(tag))
	for {
		end := min(len(message), chunkSize)
		for end < len(message) && !utf8.RuneStart(message[end]) {
			end--
		}
		msg := C.CString(message[:end])
		C.__android_log_write(C.int(priority), tag, msg)
		C.free(unsafe.Pointer(msg))
		message = message[end:]
		if len(message) == 0 {
			return
		}
	}
}
