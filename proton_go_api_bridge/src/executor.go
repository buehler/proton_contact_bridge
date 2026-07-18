package main

import (
	"context"
	"fmt"
	"log/slog"

	"proton_go_api_bridge/native/api/auth"
	"proton_go_api_bridge/native/api/contacts"
	"proton_go_api_bridge/native/api/groups"
	"proton_go_api_bridge/native/api/sync"
	"proton_go_api_bridge/native/api/user"
	"proton_go_api_bridge/native/protobuf/bridge"
)

func executeCommand(ctx context.Context, cmd *bridge.Command) (*bridge.Result, error) {
	switch cmd.Command.(type) {
	case *bridge.Command_Login:
		ctx = context.WithValue(ctx, "command", "login")
		result, err := auth.Login(ctx, cmd)
		if err != nil {
			slog.ErrorContext(ctx, "execute command", slog.Any("error", err))
		}
		return result, err
	case *bridge.Command_Logout:
		return auth.Logout(ctx, cmd)
	case *bridge.Command_GetUser:
		ctx = context.WithValue(ctx, "command", "get_user")
		result, err := user.GetUser(ctx, cmd)
		if err != nil {
			slog.ErrorContext(ctx, "execute command", slog.Any("error", err))
		}
		return result, err
	case *bridge.Command_ContactSync:
		ctx = context.WithValue(ctx, "command", "contact-sync")
		result, err := sync.ContactSync(ctx, cmd)
		if err != nil {
			slog.ErrorContext(ctx, "execute command", slog.Any("error", err))
		}
		return result, err
	case *bridge.Command_Contacts:
		ctx = context.WithValue(ctx, "command", "contacts")
		result, err := contacts.Contacts(ctx, cmd)
		if err != nil {
			slog.ErrorContext(ctx, "execute command", slog.Any("error", err))
		}
		return result, err
	case *bridge.Command_Groups:
		ctx = context.WithValue(ctx, "command", "groups")
		result, err := groups.Groups(ctx, cmd)
		if err != nil {
			slog.ErrorContext(ctx, "execute command", slog.Any("error", err))
		}
		return result, err
	default:
		ctx = context.WithValue(ctx, "command", "unknown")
		err := fmt.Errorf(
			"command %T not implemented",
			cmd.Command,
		)
		slog.ErrorContext(ctx, "execute command", slog.Any("error", err))
		return nil, err
	}
}
