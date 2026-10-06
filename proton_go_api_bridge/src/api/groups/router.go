package groups

import (
	"context"
	"fmt"
	groupstore "proton_go_api_bridge/native/groups"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/commands"
	"proton_go_api_bridge/native/protobuf/results"
)

func Groups(ctx context.Context, cmd *bridge.Command) (*bridge.Result, error) {
	groups := cmd.GetGroups()

	switch groups.Action.(type) {
	case *commands.Groups_GetAll_:
		return getAllGroups(ctx)
	case *commands.Groups_GetGroupContacts_:
		return getGroupContacts(ctx, groups.GetGetGroupContacts().GetGroupName())
	case *commands.Groups_RenameGroup_:
		request := groups.GetRenameGroup()
		result, err := groupstore.NewGroupRepository().Rename(ctx, request.GetSourceName(), request.GetTargetName())
		if err != nil {
			return nil, err
		}
		return mutationResult(result), nil
	case *commands.Groups_DeleteGroup_:
		result, err := groupstore.NewGroupRepository().Delete(ctx, groups.GetDeleteGroup().GetName())
		if err != nil {
			return nil, err
		}
		return mutationResult(result), nil
	case *commands.Groups_ApplyContactGroupChanges_:
		request := groups.GetApplyContactGroupChanges()
		patches := make([]groupstore.ContactGroupPatch, 0, len(request.GetPatches()))
		for _, patch := range request.GetPatches() {
			patches = append(patches, groupstore.ContactGroupPatch{
				ContactID:    patch.GetContactId(),
				AddGroups:    patch.GetAddGroups(),
				RemoveGroups: patch.GetRemoveGroups(),
			})
		}
		result, err := groupstore.NewGroupRepository().ApplyContactGroupChanges(ctx, patches)
		if err != nil {
			return nil, err
		}
		return mutationResult(result), nil
	default:
		return nil, fmt.Errorf("group action %T not implemented", groups.Action)
	}
}

func mutationResult(result *groupstore.MutationResult) *bridge.Result {
	failures := make([]*results.Groups_Mutation_ContactFailure, 0, len(result.FailedContacts))
	for _, failure := range result.FailedContacts {
		failures = append(failures, &results.Groups_Mutation_ContactFailure{
			ContactId: failure.ContactID,
			Message:   failure.Message,
		})
	}
	return &bridge.Result{
		Response: &bridge.Result_Groups{
			Groups: &results.Groups{
				Result: &results.Groups_Mutation_{
					Mutation: &results.Groups_Mutation{
						ChangedContactIds:   result.ChangedContactIDs,
						UnchangedContactIds: result.UnchangedContactIDs,
						FailedContacts:      failures,
						RequestedCount:      uint32(result.RequestedCount),
						CompletedCount:      uint32(result.CompletedCount),
						SourceName:          result.SourceName,
						TargetName:          result.TargetName,
					},
				},
			},
		},
	}
}
