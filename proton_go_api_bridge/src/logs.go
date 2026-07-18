package main

/*
#include <stdlib.h>
#include <stdint.h>

typedef void (*LogCallback)(int level, const char* message);

static inline void callLogCallback(
    LogCallback callback,
    int level,
    const char* message
) {
    if (callback != NULL) {
        callback(level, message);
    }
}
*/
import "C"
import (
	"log/slog"
	"unsafe"

	"proton_go_api_bridge/native/logger"

	_ "proton_go_api_bridge/native/logger"
)

//export RegisterLogCallback
func RegisterLogCallback(registerID C.uint32_t, callback C.LogCallback) {
	logger.RegisterLogCallback(uint32(registerID), func(level slog.Level, message string) {
		cmsg := C.CString(message)
		C.callLogCallback(callback, C.int(level), cmsg)
	})
	// Flutter hot restart resets Dart's registration IDs without restarting the
	// Go runtime. Replace the stale callback before emitting any log message.
	slog.Debug("register log callback", slog.Uint64("register_id", uint64(registerID)))
}

//export UnregisterLogCallback
func UnregisterLogCallback(registerID C.uint32_t) {
	slog.Debug("unregister log callback", slog.Uint64("register_id", uint64(registerID)))
	logger.UnregisterLogCallback(uint32(registerID))
}

//export FreeLogMessage
func FreeLogMessage(message *C.char) {
	C.free(unsafe.Pointer(message))
}
