package contacts

import (
	"context"

	contactsrepo "proton_go_api_bridge/native/contacts"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/results"
)

func toggleFavorite(ctx context.Context, id string) (*bridge.Result, error) {
	if err := contactsrepo.NewContactRepository().ToggleFavorite(ctx, id); err != nil {
		return nil, err
	}

	return &bridge.Result{
		Response: &bridge.Result_Success{Success: &results.Success{}},
	}, nil
}
