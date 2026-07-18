package main

/*
#include <stdint.h>
#include <stdlib.h>

typedef unsigned char InitializeAuthFromStoreResult;
#define INIT_AUTH_FROM_STORE_SUCCESS 0x00
#define INIT_AUTH_FROM_STORE_ERROR 0x01
*/
import "C"
import (
	"context"
	"log/slog"

	"proton_go_api_bridge/native/auth"
	_ "proton_go_api_bridge/native/logger"
)

//export InitializeAuthFromStore
func InitializeAuthFromStore() C.InitializeAuthFromStoreResult {
	l := slog.With("context", "InitializeAuthFromStore")
	l.Debug("initializing auth from store")
	if err := auth.Instance.InitFromStore(context.Background()); err != nil {
		l.Error("failed to initialize auth from store", slog.Any("error", err))
		return C.INIT_AUTH_FROM_STORE_ERROR
	}
	l.Debug("successfully initialized auth from store")
	return C.INIT_AUTH_FROM_STORE_SUCCESS
}
