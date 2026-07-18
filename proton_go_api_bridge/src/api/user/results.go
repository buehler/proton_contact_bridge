package user

import (
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/models"

	"github.com/ProtonMail/go-proton-api"
)

var successResult = func(user *proton.User) *bridge.Result {
	return &bridge.Result{
		Response: &bridge.Result_User{
			User: &models.User{
				Id:          user.ID,
				Email:       user.Email,
				Username:    user.Name,
				Displayname: user.DisplayName,
			},
		},
	}
}
