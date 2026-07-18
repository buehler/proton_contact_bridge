package auth

import (
	"context"
	"errors"

	authmanager "proton_go_api_bridge/native/auth"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/commands"
)

func initFromStore(
	ctx context.Context,
	_ *commands.Login_Init,
) (*bridge.Result, error) {
	err := authmanager.Instance.InitFromStore(ctx)

	switch {
	case err == nil:
		return authorizedResult, nil
	case errors.Is(err, authmanager.ErrUnauthenticated):
		return unauthorizedResult, nil
	case errors.Is(err, authmanager.ErrTOTPRequired):
		return requireTotpResult(true), nil
	default:
		return nil, err
	}
}
