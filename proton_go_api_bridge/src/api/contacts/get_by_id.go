package contacts

import (
	"context"
	"log/slog"

	"proton_go_api_bridge/native/contacts"
	"proton_go_api_bridge/native/database/models"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/results"
)

var getByIDResult = func(contact *models.Contact) *bridge.Result {
	result := &results.Contacts_GetById{}
	if contact != nil {
		result.Contact = MapContactToProto(*contact)
	}

	return &bridge.Result{
		Response: &bridge.Result_Contacts{
			Contacts: &results.Contacts{
				Result: &results.Contacts_GetById_{GetById: result},
			},
		},
	}
}

func getContactByID(ctx context.Context, id string) (*bridge.Result, error) {
	slog.DebugContext(ctx, "fetch contact by ID from database", slog.String("id", id))
	repo := contacts.NewContactRepository()
	contact, err := repo.GetById(ctx, id)
	if err != nil {
		slog.ErrorContext(ctx, "failed to fetch contact", slog.Any("error", err))
		return nil, err
	}

	return getByIDResult(contact), nil
}
