#include <jni.h>
#include <pthread.h>
#include <stdint.h>

static pthread_mutex_t bootstrap_mutex = PTHREAD_MUTEX_INITIALIZER;
static JavaVM *process_vm;
static jobject process_helper;

JNIEXPORT jlongArray JNICALL
Java_ch_cbue_proton_1go_1api_1bridge_ProtonGoApiBridgePlugin_nativeHandles(
    JNIEnv *env, jclass plugin_class, jobject helper) {
    (void)plugin_class;
    pthread_mutex_lock(&bootstrap_mutex);
    if (!process_helper) {
        if ((*env)->GetJavaVM(env, &process_vm) != JNI_OK) {
            pthread_mutex_unlock(&bootstrap_mutex);
            return NULL;
        }
        // Exactly one reference, owned for the process lifetime. Repeated
        // initialization never allocates another global reference, even if
        // a Dart isolate exits before receiving its MethodChannel response.
        process_helper = (*env)->NewGlobalRef(env, helper);
    }
    if (!process_helper) {
        pthread_mutex_unlock(&bootstrap_mutex);
        return NULL;
    }
    jlong handles[] = {
        (jlong)(uintptr_t)process_vm,
        (jlong)(uintptr_t)process_helper
    };
    pthread_mutex_unlock(&bootstrap_mutex);

    jlongArray result = (*env)->NewLongArray(env, 2);
    if (result) (*env)->SetLongArrayRegion(env, result, 0, 2, handles);
    return result;
}
