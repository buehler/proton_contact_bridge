//go:build ios || darwin

package logger

/*
#include <os/log.h>
#include <stdlib.h>

static os_log_t proton_app_log(void) {
    static os_log_t log;
    static dispatch_once_t once_token;

    dispatch_once(&once_token, ^{
        log = os_log_create("ch.cbue.protonContactBridge", "NativeLibrary");
    });

    return log;
}

static inline void apple_log_print(os_log_type_t type, const char* msg) {
    os_log_with_type(proton_app_log(), type, "%{public}s", msg);
}
*/
import "C"
import (
	"log/slog"
	"unsafe"
)

func platformLog(level slog.Level, message string) {
	msg := C.CString(message)
	defer C.free(unsafe.Pointer(msg))

	logType := C.OS_LOG_TYPE_DEFAULT
	switch {
	case level <= slog.LevelDebug:
		logType = C.OS_LOG_TYPE_DEBUG
	case level < slog.LevelWarn:
		logType = C.OS_LOG_TYPE_INFO
	case level >= slog.LevelError:
		logType = C.OS_LOG_TYPE_ERROR
	}

	C.apple_log_print(C.os_log_type_t(logType), msg)
}
