package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"strings"
	"unsafe"
)

//export Add
func Add(a, b int) int {
	return a + b
}

//export Sub
func Sub(a, b int) int {
	return a - b
}

//export Upper
func Upper(s *C.char) *C.char {
	var str = C.GoString(s)
	str = strings.ToUpper(str)
	return C.CString(str)
}

//export FreeString
func FreeString(ptr *C.char) {
	C.free(unsafe.Pointer(ptr))
}

func main() {}
