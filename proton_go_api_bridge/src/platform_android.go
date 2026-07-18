//go:build android

package main

/*
#include <stdint.h>
*/
import "C"

import "proton_go_api_bridge/native/storage"

// InitializeAndroidPlatform accepts borrowed, process-lifetime JNI handles.
// It performs no disk access or cryptography.
//
//export InitializeAndroidPlatform
func InitializeAndroidPlatform(vm C.uintptr_t, helper C.uintptr_t) C.int {
	return C.int(storage.InitializeAndroidStorage(uintptr(vm), uintptr(helper)))
}
