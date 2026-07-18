package auth

import (
	"context"
	"errors"

	authmanager "proton_go_api_bridge/native/auth"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/commands"
)

func loginWithUsernamePassword(
	ctx context.Context,
	login *commands.Login_UsernamePassword,
) (*bridge.Result, error) {
	err := authmanager.Instance.LoginWithCredentials(
		ctx,
		login.Username,
		[]byte(login.Password),
	)

	switch {
	case err == nil:
		return authorizedResult, nil
	case errors.Is(err, authmanager.ErrTOTPRequired):
		return requireTotpResult(true), nil
	}

	var hvErr *authmanager.HumanVerificationRequiredError
	if errors.As(err, &hvErr) {
		return requireHumanVerificationResult(hvErr.URI), nil
	}

	return nil, err
}
