#ifndef PROTON_ANDROID_STORAGE_H
#define PROTON_ANDROID_STORAGE_H

#include <stdint.h>
#include <stdlib.h>

// Status values are shared with AndroidSecureStorage.java.
enum {
    PCB_STORAGE_OK = 0,
    PCB_STORAGE_NOT_FOUND = 1,
    PCB_STORAGE_NOT_INITIALIZED = 2,
    PCB_STORAGE_CORRUPT = 3,
    PCB_STORAGE_KEY_UNAVAILABLE = 4,
    PCB_STORAGE_KEYSTORE = 5,
    PCB_STORAGE_IO = 6,
    PCB_STORAGE_JNI = 7,
    PCB_STORAGE_MEMORY = 8,
    PCB_STORAGE_VERSION = 9,
    PCB_STORAGE_AUTHENTICATION = 10,
    PCB_STORAGE_ACCESS = 11,
    PCB_STORAGE_TOO_LARGE = 12
};

// The bootstrap library owns vm/helper for the lifetime of the process.
int pcb_storage_initialize(uintptr_t vm, uintptr_t helper);
int pcb_storage_execute(int operation, const void *key, int key_len,
                        const void *value, int value_len,
                        void **data, int *data_len);

#endif
