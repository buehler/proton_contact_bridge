package main

/*
#include <stdlib.h>

typedef struct {
    unsigned char* data;
    int len;
} GoByteBuffer;
*/
import "C"
import (
	"fmt"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/results"
	"unsafe"

	"google.golang.org/protobuf/proto"
)

//export ExecuteCommand
func ExecuteCommand(rawCmd C.GoByteBuffer) C.GoByteBuffer {
	if rawCmd.data == nil || rawCmd.len <= 0 {
		return C.GoByteBuffer{data: nil, len: 0}
	}

	cmdData := unsafe.Slice((*byte)(unsafe.Pointer(rawCmd.data)), int(rawCmd.len))

	cmd := &bridge.Command{}
	err := proto.Unmarshal(cmdData, cmd)
	if err != nil {
		return wrapError(err)
	}

	result, err := executeCommand(cmd)
	if err != nil {
		return wrapError(err)
	}

	bytes, err := proto.Marshal(result)
	if err != nil {
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

func executeCommand(cmd *bridge.Command) (*bridge.Result, error) {
	switch command := cmd.Command.(type) {
	// Add cases for different command types here
	default:
		return nil, fmt.Errorf("command %s not implemented", command)
	}
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

func main() {}
