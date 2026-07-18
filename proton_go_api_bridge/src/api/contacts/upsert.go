package contacts

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

	"proton_go_api_bridge/native/contacts"
	"proton_go_api_bridge/native/database/models"
	"proton_go_api_bridge/native/protobuf/bridge"
	pmodels "proton_go_api_bridge/native/protobuf/models"
	"proton_go_api_bridge/native/protobuf/results"
)

var upsertResult = func(contact *models.Contact) *bridge.Result {
	result := &results.Contacts_UpsertContact{}
	if contact != nil {
		result.Contact = MapContactToProto(*contact)
	}

	return &bridge.Result{
		Response: &bridge.Result_Contacts{
			Contacts: &results.Contacts{
				Result: &results.Contacts_UpsertContact_{UpsertContact: result},
			},
		},
	}
}

func upsertContact(ctx context.Context, contact *pmodels.Contact) (*bridge.Result, error) {
	if contact == nil {
		return nil, fmt.Errorf("contact is nil")
	}

	repo := contacts.NewContactRepository()
	cCard := MapProtoToVCard(contact)
	if strings.Trim(contact.Id, " ") == "" {
		slog.DebugContext(ctx, "inserting new contact")
		if c, err := repo.Insert(ctx, cCard); err != nil {
			slog.ErrorContext(ctx, "failed to insert contact", slog.Any("error", err))
			return nil, fmt.Errorf("failed to insert contact: %w", err)
		} else {
			return upsertResult(&c), nil
		}
	} else {
		slog.DebugContext(ctx, "updating existing contact", slog.String("contact_id", contact.Id))
		if c, err := repo.Update(ctx, contact.Id, cCard); err != nil {
			slog.ErrorContext(ctx, "failed to update contact", slog.String("contact_id", contact.Id), slog.Any("error", err))
			return nil, fmt.Errorf("failed to update contact: %w", err)
		} else {
			return upsertResult(&c), nil
		}
	}
}
