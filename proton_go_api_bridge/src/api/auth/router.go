package auth

import (
	"context"
	"fmt"
	"log/slog"

	"proton_go_api_bridge/native/auth"
	"proton_go_api_bridge/native/database"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/commands"
)

func Login(ctx context.Context, cmd *bridge.Command) (*bridge.Result, error) {
	login := cmd.GetLogin()

	switch login.Method.(type) {
	case *commands.Login_Init_:
		ctx = context.WithValue(ctx, "auth_method", "from_store")
		result, err := initFromStore(ctx, login.GetInit())
		if err != nil {
			slog.ErrorContext(ctx, "initialize authentication from store", slog.Any("error", err))
		}
		return result, err
	case *commands.Login_UsernamePassword_:
		ctx = context.WithValue(ctx, "auth_method", "credentials")
		result, err := loginWithUsernamePassword(
			ctx,
			login.GetUsernamePassword(),
		)
		if err != nil {
			slog.ErrorContext(ctx, "authenticate with credentials", slog.Any("error", err))
		}
		return result, err
	case *commands.Login_SubmitHumanVerification_:
		ctx = context.WithValue(ctx, "auth_method", "human_verification")
		result, err := submitHumanVerification(
			ctx,
			login.GetSubmitHumanVerification(),
		)
		if err != nil {
			slog.ErrorContext(ctx, "submit human verification", slog.Any("error", err))
		}
		return result, err
	case *commands.Login_Totp:
		ctx = context.WithValue(ctx, "auth_method", "totp")
		result, err := submitTOTP(ctx, login.GetTotp())
		if err != nil {
			slog.ErrorContext(ctx, "submit TOTP", slog.Any("error", err))
		}
		return result, err
	default:
		err := fmt.Errorf(
			"login method %T not implemented",
			login.Method,
		)
		slog.ErrorContext(ctx, "route authentication command", slog.Any("error", err))
		return nil, err
	}
}

func Logout(ctx context.Context, _ *bridge.Command) (*bridge.Result, error) {
	if err := auth.Instance.Logout(ctx); err != nil {
		slog.ErrorContext(ctx, "logout", slog.Any("error", err))
		return nil, err
	}
	database.Reset()
	return successResult, nil
}
