package main

/*
#include "common_types.h"
*/
import "C"
import (
	"proton_go_api_bridge/native/database"

	_ "proton_go_api_bridge/native/logger"
)

//export InitializeDatabase
func InitializeDatabase(basePath *C.cchar_t) {
	p := C.GoString(basePath)
	database.SetupDB(p)
}
