package auth

import (
	"context"

	authmanager "proton_go_api_bridge/native/auth"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/commands"
)

func submitTOTP(
	ctx context.Context,
	login *commands.Login_TOTP,
) (*bridge.Result, error) {
	if err := authmanager.Instance.SubmitTOTP(ctx, login.Code); err != nil {
		return nil, err
	}

	return authorizedResult, nil
}
