package groups

import (
	"context"
	"log/slog"

	"proton_go_api_bridge/native/database/models"
	"proton_go_api_bridge/native/groups"
	"proton_go_api_bridge/native/protobuf/bridge"
	pmodels "proton_go_api_bridge/native/protobuf/models"
	"proton_go_api_bridge/native/protobuf/results"
	"proton_go_api_bridge/native/utils"
)

func mapGroupToProto(g models.Group) *pmodels.Group {
	return &pmodels.Group{
		Name: g.Name,
	}
}

var getAllResult = func(gs []models.Group) *bridge.Result {
	return &bridge.Result{
		Response: &bridge.Result_Groups{
			Groups: &results.Groups{
				Result: &results.Groups_GetAll_{
					GetAll: &results.Groups_GetAll{
						Groups: utils.MapSlice(gs, mapGroupToProto),
					},
				},
			},
		},
	}
}

func getAllGroups(ctx context.Context) (*bridge.Result, error) {
	slog.DebugContext(ctx, "fetch all groups from database")
	repo := groups.NewGroupRepository()
	gs, err := repo.GetAll(ctx)
	if err != nil {
		slog.ErrorContext(ctx, "failed to fetch groups", slog.Any("error", err))
		return nil, err
	}
	return getAllResult(gs), nil
}
