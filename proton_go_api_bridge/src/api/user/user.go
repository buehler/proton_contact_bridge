package user

import (
	"context"
	"log/slog"
	"proton_go_api_bridge/native/auth"
	"proton_go_api_bridge/native/protobuf/bridge"

	"github.com/ProtonMail/go-proton-api"
)

func GetUser(ctx context.Context, cmd *bridge.Command) (*bridge.Result, error) {
	ctx = context.WithValue(ctx, "command", "get_user")

	var user proton.User
	err := auth.Instance.WithClient(func(c *proton.Client) error {
		u, err := c.GetUser(ctx)
		user = u
		return err
	})
	if err != nil {
		slog.ErrorContext(ctx, "failed to get user", slog.Any("error", err))
		return nil, err
	}

	return successResult(&user), nil
}
