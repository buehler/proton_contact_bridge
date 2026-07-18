package main

/*
#include <stdint.h>
#include <stdlib.h>

#define CONTACT_SYNC_STATE_IDLE 0x00
#define CONTACT_SYNC_STATE_RUNNING 0x01
#define CONTACT_SYNC_STATE_ERROR 0x02

typedef unsigned char IncrementalSyncResult;
#define INCREMENTAL_CONTACT_SYNC_SUCCESS 0x00
#define INCREMENTAL_CONTACT_SYNC_ERROR 0x01
#define INCREMENTAL_CONTACT_SYNC_DB_ERROR 0x02
#define INCREMENTAL_CONTACT_SYNC_UNAUTHED 0x03

typedef void (*ContactSyncStateCallback)(unsigned char state);

static inline void callContactSyncStateCallback(
    ContactSyncStateCallback callback,
    unsigned char state
) {
    if (callback != NULL) {
        callback(state);
    }
}
*/
import "C"
import (
	"log/slog"

	"proton_go_api_bridge/native/auth"
	"proton_go_api_bridge/native/contacts"
	"proton_go_api_bridge/native/database"

	_ "proton_go_api_bridge/native/logger"
)

// ExecuteIncrementalSync starts a blocking incremental sync. It is intended to be
// called by background tasks from native code. It may abort early if the database
// is not initialized or if the user is not properly authenticated (and the auth
// manager is not initialized). It returns a result code indicating success or failure.
//
//export ExecuteIncrementalSync
func ExecuteIncrementalSync() C.IncrementalSyncResult {
	l := slog.With("context", "ExecuteIncrementalSync")
	l.Debug("directly start incremental sync")
	// check if db ready
	if database.DatabaseError != nil {
		l.Error("database error", slog.Any("error", database.DatabaseError))
		return C.INCREMENTAL_CONTACT_SYNC_DB_ERROR
	}

	// check if auth ready
	if as, err := auth.Instance.State(); err != nil {
		l.Error("auth error", slog.Any("error", err))
		return C.INCREMENTAL_CONTACT_SYNC_ERROR
	} else if as != auth.AuthStateReady {
		l.Error("user not authenticated / auth manager not properly initialized", slog.Any("auth_state", as))
		return C.INCREMENTAL_CONTACT_SYNC_UNAUTHED
	}

	// execute sync
	err := contacts.Instance.RunIncrementalSync()
	if err != nil {
		l.Error("incremental sync error", slog.Any("error", err))
		return C.INCREMENTAL_CONTACT_SYNC_ERROR
	}
	return C.INCREMENTAL_CONTACT_SYNC_SUCCESS
}

//export RegisterContactSyncStateCallback
func RegisterContactSyncStateCallback(
	registerID C.uint32_t,
	callback C.ContactSyncStateCallback,
) {
	l := slog.With("context", "RegisterContactSyncStateCallback")
	l.Debug("register contact sync state callback", slog.Uint64("register_id", uint64(registerID)))
	contacts.Instance.CallbackContainer.Register(uint32(registerID), func(css contacts.ContactSyncState) {
		switch css {
		case contacts.ContactSyncStateRunning:
			C.callContactSyncStateCallback(callback, C.CONTACT_SYNC_STATE_RUNNING)
		case contacts.ContactSyncStateError:
			C.callContactSyncStateCallback(callback, C.CONTACT_SYNC_STATE_ERROR)
		default:
			C.callContactSyncStateCallback(callback, C.CONTACT_SYNC_STATE_IDLE)
		}
	})
}

//export UnregisterContactSyncStateCallback
func UnregisterContactSyncStateCallback(registerID C.uint32_t) {
	l := slog.With("context", "UnregisterContactSyncStateCallback")
	l.Debug("unregister contact sync state callback", slog.Uint64("register_id", uint64(registerID)))
	contacts.Instance.CallbackContainer.Unregister(uint32(registerID))
}
