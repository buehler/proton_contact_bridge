package groups

import (
	"context"
	"fmt"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/commands"
)

func Groups(ctx context.Context, cmd *bridge.Command) (*bridge.Result, error) {
	groups := cmd.GetGroups()

	switch groups.Action.(type) {
	case *commands.Groups_GetAll_:
		return getAllGroups(ctx)
	case *commands.Groups_GetGroupContacts_:
		return getGroupContacts(ctx, groups.GetGetGroupContacts().GetGroupName())
	default:
		return nil, fmt.Errorf("group action %T not implemented", groups.Action)
	}
}
