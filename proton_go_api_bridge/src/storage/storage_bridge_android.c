//go:build android

#include "android_storage.h"
#include <jni.h>
#include <pthread.h>

static pthread_mutex_t storage_mutex = PTHREAD_MUTEX_INITIALIZER;
static JavaVM *storage_vm;
static jobject storage_helper;
static jmethodID execute_method;

static int get_env(JavaVM *vm, JNIEnv **env, int *attached) {
    *attached = 0;
    jint result = (*vm)->GetEnv(vm, (void **)env, JNI_VERSION_1_6);
    if (result == JNI_EDETACHED) {
        if ((*vm)->AttachCurrentThread(vm, env, NULL) != JNI_OK) {
            return PCB_STORAGE_JNI;
        }
        *attached = 1;
        return PCB_STORAGE_OK;
    }
    return result == JNI_OK ? PCB_STORAGE_OK : PCB_STORAGE_JNI;
}

// Do not print Java exceptions: their messages may contain sensitive data.
static int clear_exception(JNIEnv *env) {
    if (!(*env)->ExceptionCheck(env)) return 0;
    (*env)->ExceptionClear(env);
    return 1;
}

int pcb_storage_initialize(uintptr_t vm_handle, uintptr_t helper_handle) {
    if (!vm_handle || !helper_handle) return PCB_STORAGE_JNI;
    pthread_mutex_lock(&storage_mutex);
    JavaVM *vm = (JavaVM *)vm_handle;
    jobject helper = (jobject)helper_handle;
    int status = PCB_STORAGE_OK;
    if (storage_vm) {
        // All engines obtain the same global reference from the bootstrap.
        status = storage_vm == vm && storage_helper == helper
            ? PCB_STORAGE_OK : PCB_STORAGE_JNI;
        goto unlock;
    }

    JNIEnv *env = NULL;
    int attached = 0;
    status = get_env(vm, &env, &attached);
    if (status != PCB_STORAGE_OK) goto unlock;

    jclass helper_class = (*env)->GetObjectClass(env, helper);
    if (clear_exception(env) || !helper_class) {
        status = PCB_STORAGE_JNI;
    } else {
        // Resolving from the object avoids FindClass on a Go-created thread.
        jmethodID method = (*env)->GetMethodID(env, helper_class, "execute", "(I[B[B)[B");
        if (clear_exception(env) || !method) {
            status = PCB_STORAGE_JNI;
        } else {
            storage_vm = vm;
            storage_helper = helper;
            execute_method = method;
        }
    }
    if (helper_class) (*env)->DeleteLocalRef(env, helper_class);
    if (attached) (*vm)->DetachCurrentThread(vm);
unlock:
    pthread_mutex_unlock(&storage_mutex);
    return status;
}

int pcb_storage_execute(int operation, const void *key, int key_len,
                        const void *value, int value_len,
                        void **data, int *data_len) {
    *data = NULL;
    *data_len = 0;
    pthread_mutex_lock(&storage_mutex);
    int status = PCB_STORAGE_NOT_INITIALIZED;
    if (!storage_vm) goto unlock;

    JNIEnv *env = NULL;
    int attached = 0;
    status = get_env(storage_vm, &env, &attached);
    if (status != PCB_STORAGE_OK) goto unlock;

    jbyteArray java_key = NULL;
    jbyteArray java_value = NULL;
    jbyteArray result = NULL;
    status = PCB_STORAGE_JNI;
    java_key = (*env)->NewByteArray(env, key_len);
    if (clear_exception(env) || !java_key) goto cleanup;
    if (key_len) (*env)->SetByteArrayRegion(env, java_key, 0, key_len, key);
    if (clear_exception(env)) goto cleanup;

    java_value = (*env)->NewByteArray(env, value_len);
    if (clear_exception(env) || !java_value) goto cleanup;
    if (value_len) (*env)->SetByteArrayRegion(env, java_value, 0, value_len, value);
    if (clear_exception(env)) goto cleanup;

    result = (jbyteArray)(*env)->CallObjectMethod(
        env, storage_helper, execute_method, (jint)operation, java_key, java_value);
    if (clear_exception(env) || !result) goto cleanup;
    jsize length = (*env)->GetArrayLength(env, result);
    if (clear_exception(env) || length < 1) goto cleanup;
    jbyte result_status;
    (*env)->GetByteArrayRegion(env, result, 0, 1, &result_status);
    if (clear_exception(env)) goto cleanup;
    status = result_status;
    if (status != PCB_STORAGE_OK || length == 1) goto cleanup;

    *data = malloc((size_t)(length - 1));
    if (!*data) {
        status = PCB_STORAGE_MEMORY;
        goto cleanup;
    }
    (*env)->GetByteArrayRegion(env, result, 1, length - 1, *data);
    if (clear_exception(env)) {
        free(*data);
        *data = NULL;
        status = PCB_STORAGE_JNI;
        goto cleanup;
    }
    *data_len = length - 1;
cleanup:
    if (result) (*env)->DeleteLocalRef(env, result);
    if (java_value) (*env)->DeleteLocalRef(env, java_value);
    if (java_key) (*env)->DeleteLocalRef(env, java_key);
    if (attached) (*storage_vm)->DetachCurrentThread(storage_vm);
unlock:
    pthread_mutex_unlock(&storage_mutex);
    return status;
}
