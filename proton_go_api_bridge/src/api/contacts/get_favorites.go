package contacts

import (
	"context"
	"log/slog"

	contactsrepo "proton_go_api_bridge/native/contacts"
	"proton_go_api_bridge/native/database/models"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/results"
	"proton_go_api_bridge/native/utils"
)

var getFavoritesResult = func(contacts []models.Contact) *bridge.Result {
	return &bridge.Result{
		Response: &bridge.Result_Contacts{
			Contacts: &results.Contacts{
				Result: &results.Contacts_GetFavorites_{
					GetFavorites: &results.Contacts_GetFavorites{
						Contacts: utils.MapSlice(contacts, MapContactToProto),
					},
				},
			},
		},
	}
}

func getFavoriteContacts(ctx context.Context) (*bridge.Result, error) {
	slog.DebugContext(ctx, "fetch favorite contacts from database")
	contacts, err := contactsrepo.NewContactRepository().GetFavorites(ctx)
	if err != nil {
		slog.ErrorContext(ctx, "failed to fetch favorite contacts", slog.Any("error", err))
		return nil, err
	}

	return getFavoritesResult(contacts), nil
}
