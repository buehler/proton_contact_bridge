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
	"proton_go_api_bridge/native/protobuf/proton"
	"unsafe"

	"google.golang.org/protobuf/proto"
)

//export ExecThingy
func ExecThingy() C.GoByteBuffer {
	lol := proton.Foobar{
		Foo: true,
		Bar: "Hello",
	}

	bytes, err := proto.Marshal(&lol)
	if err != nil {
		panic(err)
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

func main() {}
