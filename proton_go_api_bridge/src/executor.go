package main

import (
	"fmt"
	"proton_go_api_bridge/native/auth"
	"proton_go_api_bridge/native/protobuf/bridge"
)

func executeCommand(cmd *bridge.Command) (*bridge.Result, error) {
	switch command := cmd.Command.(type) {
	case *bridge.Command_Login:
		return auth.Login(cmd)
	default:
		return nil, fmt.Errorf("command %s not implemented", command)
	}
}
