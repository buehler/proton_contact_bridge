package main

/*
#include <stdint.h>
#include <stdlib.h>

typedef struct {
    unsigned char* data;
    int len;
} GoByteBuffer;
*/
import "C"
import (
	"context"
	"log/slog"
	"time"
	"unsafe"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	"proton_go_api_bridge/native/database"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/results"

	_ "proton_go_api_bridge/native/logger"
)

//export ExecuteCommand
func ExecuteCommand(rawCmd C.GoByteBuffer) C.GoByteBuffer {
	if rawCmd.data == nil || rawCmd.len <= 0 {
		return C.GoByteBuffer{data: nil, len: 0}
	}

	if database.DatabaseError != nil {
		return wrapError(database.DatabaseError)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ctx = context.WithValue(ctx, "trace_id", uuid.New().String())
	slog.DebugContext(ctx, "execute command started")
	started := time.Now()
	defer func() {
		slog.DebugContext(
			ctx,
			"execute command finished",
			slog.Duration("duration", time.Since(started)),
		)
	}()

	cmdData := unsafe.Slice((*byte)(unsafe.Pointer(rawCmd.data)), int(rawCmd.len))

	cmd := &bridge.Command{}
	err := proto.Unmarshal(cmdData, cmd)
	if err != nil {
		slog.ErrorContext(ctx, "unmarshal command", slog.Any("error", err))
		return wrapError(err)
	}

	result, err := executeCommand(ctx, cmd)
	if err != nil {
		return wrapError(err)
	}

	bytes, err := proto.Marshal(result)
	if err != nil {
		slog.ErrorContext(ctx, "marshal command result", slog.Any("error", err))
		return wrapError(err)
	}

	cData := C.CBytes(bytes)
	var buffer C.GoByteBuffer
	buffer.data = (*C.uchar)(cData)
	buffer.len = C.int(len(bytes))

	return buffer
}

//export FreeByteBuffer
func FreeByteBuffer(buffer C.GoByteBuffer) {
	C.free(unsafe.Pointer(buffer.data))
}

func wrapError(err error) C.GoByteBuffer {
	if err == nil {
		return C.GoByteBuffer{data: nil, len: 0}
	}

	errMsg := &bridge.Result{
		Response: &bridge.Result_Error{
			Error: &results.Error{
				Message: err.Error(),
			},
		},
	}
	bytes, _ := proto.Marshal(errMsg)
	cData := C.CBytes(bytes)
	var buffer C.GoByteBuffer
	buffer.data = (*C.uchar)(cData)
	buffer.len = C.int(len(bytes))
	return buffer
}
