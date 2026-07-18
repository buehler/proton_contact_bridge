package contacts

import (
	"context"
	"fmt"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/commands"
)

func Contacts(ctx context.Context, cmd *bridge.Command) (*bridge.Result, error) {
	contacts := cmd.GetContacts()

	switch contacts.Action.(type) {
	case *commands.Contacts_GetAll_:
		return getAllContacts(ctx)
	case *commands.Contacts_GetById_:
		return getContactByID(ctx, contacts.GetGetById().GetId())
	case *commands.Contacts_Search_:
		return searchContacts(ctx, contacts.GetSearch().GetQuery())
	case *commands.Contacts_ToggleFavorite_:
		return toggleFavorite(ctx, contacts.GetToggleFavorite().GetId())
	case *commands.Contacts_GetFavorites_:
		return getFavoriteContacts(ctx)
	case *commands.Contacts_UpsertContact_:
		return upsertContact(ctx, contacts.GetUpsertContact().GetContact())
	case *commands.Contacts_DeleteContact_:
		return deleteContact(ctx, contacts.GetDeleteContact().GetId())
	default:
		return nil, fmt.Errorf("contact action %T not implemented", contacts.Action)
	}
}
