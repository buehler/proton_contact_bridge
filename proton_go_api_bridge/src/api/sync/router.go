package sync

import (
	"context"
	"fmt"
	"proton_go_api_bridge/native/contacts"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/commands"
	"proton_go_api_bridge/native/protobuf/results"
)

var successResult = &bridge.Result{
	Response: &bridge.Result_Success{
		Success: &results.Success{},
	},
}

var localEventsAvailableResult = func(r bool) *bridge.Result {
	return &bridge.Result{
		Response: &bridge.Result_ContactSync{
			ContactSync: &results.ContactSync{
				Result: &results.ContactSync_LocalEventsAvailable_{
					LocalEventsAvailable: &results.ContactSync_LocalEventsAvailable{
						HasEvents: r,
					},
				},
			},
		},
	}
}

func ContactSync(ctx context.Context, cmd *bridge.Command) (*bridge.Result, error) {
	sync := cmd.GetContactSync()

	switch sync.Action.(type) {
	case *commands.ContactSync_Start_:
		contacts.Instance.StartSync()
		return successResult, nil
	case *commands.ContactSync_LocalEventsAvailable_:
		h, err := contacts.Instance.GetLocalEventsAvailable()
		if err != nil {
			return nil, err
		}
		return localEventsAvailableResult(h), nil
	default:
		return nil, fmt.Errorf("contact sync action %T not implemented", sync.Action)
	}
}
