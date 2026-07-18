//go:build android

package storage

/*
#include "android_storage.h"
*/
import "C"

import (
	"fmt"
	"unsafe"
)

type androidSecureStorage struct{}

func NewSecureStorage() SecureStorage { return androidSecureStorage{} }

// InitializeAndroidStorage borrows the bootstrap's process-lifetime JNI handles.
func InitializeAndroidStorage(vm, helper uintptr) int {
	return int(C.pcb_storage_initialize(C.uintptr_t(vm), C.uintptr_t(helper)))
}

func (androidSecureStorage) Exists(key string) (bool, error) {
	data, err := androidStorageCall(0, key, nil)
	return len(data) == 1 && data[0] == 1, err
}

func (androidSecureStorage) Set(key string, value []byte) error {
	_, err := androidStorageCall(1, key, value)
	return err
}

func (androidSecureStorage) Get(key string) ([]byte, error) {
	return androidStorageCall(2, key, nil)
}

func (androidSecureStorage) Delete(key string) error {
	_, err := androidStorageCall(3, key, nil)
	return err
}

func (androidSecureStorage) DeleteAll() error {
	_, err := androidStorageCall(4, "", nil)
	return err
}

func androidStorageCall(operation int, key string, value []byte) ([]byte, error) {
	// JNI array lengths are signed 32-bit integers, even on 64-bit Android.
	const maxLength = 1<<31 - 2
	const maxValueSize = 16 * 1024 * 1024 // Matches AndroidSecureStorage.java.
	if len(key) > maxLength || len(value) > maxValueSize {
		return nil, androidStorageError(C.PCB_STORAGE_TOO_LARGE)
	}
	keyBytes := []byte(key)
	var data unsafe.Pointer
	var size C.int
	status := C.pcb_storage_execute(
		C.int(operation), unsafe.Pointer(unsafe.SliceData(keyBytes)), C.int(len(keyBytes)),
		unsafe.Pointer(unsafe.SliceData(value)), C.int(len(value)), &data, &size,
	)
	defer C.free(data)
	if status != C.PCB_STORAGE_OK {
		return nil, androidStorageError(int(status))
	}
	return C.GoBytes(data, size), nil
}

func androidStorageError(status int) error {
	if status == C.PCB_STORAGE_NOT_FOUND {
		return ErrKeyNotFound
	}
	messages := map[int]string{
		C.PCB_STORAGE_NOT_INITIALIZED: "platform not initialized",
		C.PCB_STORAGE_CORRUPT:         "corrupt record",
		C.PCB_STORAGE_KEY_UNAVAILABLE: "encryption key unavailable; clear stored secrets to recover",
		C.PCB_STORAGE_KEYSTORE:        "Keystore operation failed",
		C.PCB_STORAGE_IO:              "file operation failed",
		C.PCB_STORAGE_JNI:             "JNI operation failed",
		C.PCB_STORAGE_MEMORY:          "allocation failed",
		C.PCB_STORAGE_VERSION:         "unsupported record version",
		C.PCB_STORAGE_AUTHENTICATION:  "record authentication failed",
		C.PCB_STORAGE_ACCESS:          "access denied",
		C.PCB_STORAGE_TOO_LARGE:       "entry too large",
	}
	message, ok := messages[status]
	if !ok {
		message = "unexpected storage failure"
	}
	return fmt.Errorf("android secure storage: %s", message)
}
