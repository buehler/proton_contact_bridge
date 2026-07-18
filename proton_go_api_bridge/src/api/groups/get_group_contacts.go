package groups

import (
	"context"
	"log/slog"

	apiContacts "proton_go_api_bridge/native/api/contacts"
	"proton_go_api_bridge/native/database/models"
	"proton_go_api_bridge/native/groups"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/results"
	"proton_go_api_bridge/native/utils"
)

var groupContactsResult = func(contacts []models.Contact) *bridge.Result {
	return &bridge.Result{
		Response: &bridge.Result_Groups{
			Groups: &results.Groups{
				Result: &results.Groups_GroupContacts_{
					GroupContacts: &results.Groups_GroupContacts{
						Contacts: utils.MapSlice(contacts, apiContacts.MapContactToProto),
					},
				},
			},
		},
	}
}

func getGroupContacts(ctx context.Context, groupName string) (*bridge.Result, error) {
	slog.DebugContext(ctx, "fetch group contacts from database", slog.String("group_name", groupName))
	repo := groups.NewGroupRepository()
	contacts, err := repo.GetGroupContacts(ctx, groupName)
	if err != nil {
		slog.ErrorContext(ctx, "failed to fetch group contacts", slog.Any("error", err))
		return nil, err
	}

	return groupContactsResult(contacts), nil
}
