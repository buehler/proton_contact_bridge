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

var searchResult = func(contacts []models.Contact) *bridge.Result {
	return &bridge.Result{
		Response: &bridge.Result_Contacts{
			Contacts: &results.Contacts{
				Result: &results.Contacts_Search_{
					Search: &results.Contacts_Search{
						Contacts: utils.MapSlice(contacts, MapContactToProto),
					},
				},
			},
		},
	}
}

func searchContacts(ctx context.Context, query string) (*bridge.Result, error) {
	slog.DebugContext(ctx, "search contacts in database", slog.String("query", query))
	repo := contacts.NewContactRepository()
	contacts, err := repo.Search(ctx, query)
	if err != nil {
		slog.ErrorContext(ctx, "failed to search contacts", slog.Any("error", err))
		return nil, err
	}

	return searchResult(contacts), nil
}
