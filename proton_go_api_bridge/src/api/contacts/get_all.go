package contacts

import (
	"context"
	"log/slog"

	"proton_go_api_bridge/native/contacts"
	"proton_go_api_bridge/native/database/models"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/results"
	"proton_go_api_bridge/native/utils"
)

var getAllResult = func(cs []models.Contact) *bridge.Result {
	return &bridge.Result{
		Response: &bridge.Result_Contacts{
			Contacts: &results.Contacts{
				Result: &results.Contacts_GetAll_{
					GetAll: &results.Contacts_GetAll{
						Contacts: utils.MapSlice(cs, MapContactToProto),
					},
				},
			},
		},
	}
}

func getAllContacts(ctx context.Context) (*bridge.Result, error) {
	slog.DebugContext(ctx, "fetch all contacts from database")
	repo := contacts.NewContactRepository()
	cs, err := repo.GetAll(ctx)
	if err != nil {
		slog.ErrorContext(ctx, "failed to fetch contacts", slog.Any("error", err))
		return nil, err
	}
	return getAllResult(cs), nil
}
