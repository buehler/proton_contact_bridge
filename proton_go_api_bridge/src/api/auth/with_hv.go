package auth

import (
	"context"
	"errors"

	authmanager "proton_go_api_bridge/native/auth"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/commands"
)

func submitHumanVerification(
	ctx context.Context,
	login *commands.Login_SubmitHumanVerification,
) (*bridge.Result, error) {
	err := authmanager.Instance.SubmitHumanVerification(
		ctx,
		login.Token,
		login.Type,
	)

	switch {
	case err == nil:
		return authorizedResult, nil
	case errors.Is(err, authmanager.ErrTOTPRequired):
		return requireTotpResult(true), nil
	default:
		return nil, err
	}
}
