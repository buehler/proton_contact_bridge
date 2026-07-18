package contacts

import (
	"context"
	"log/slog"

	"proton_go_api_bridge/native/contacts"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/results"
)

var successResult = &bridge.Result{
	Response: &bridge.Result_Success{
		Success: &results.Success{},
	},
}

func deleteContact(ctx context.Context, ID string) (*bridge.Result, error) {
	slog.DebugContext(ctx, "delete contact form database", slog.String("id", ID))
	repo := contacts.NewContactRepository()
	err := repo.Delete(ctx, ID)
	if err != nil {
		slog.ErrorContext(ctx, "failed to delete contact", slog.Any("error", err))
		return nil, err
	}

	return successResult, nil
}
