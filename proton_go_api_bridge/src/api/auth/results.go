package auth

import (
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/results"
)

var (
	successResult = &bridge.Result{
		Response: &bridge.Result_Success{
			Success: &results.Success{},
		},
	}
	unauthorizedResult = &bridge.Result{
		Response: &bridge.Result_Login{
			Login: &results.Login{
				Outcome: &results.Login_Unauthorized_{},
			},
		},
	}
	authorizedResult = &bridge.Result{
		Response: &bridge.Result_Login{
			Login: &results.Login{
				Outcome: &results.Login_Authorized_{
					Authorized: &results.Login_Authorized{},
				},
			},
		},
	}
	requireHumanVerificationResult = func(uri string) *bridge.Result {
		return &bridge.Result{
			Response: &bridge.Result_Login{
				Login: &results.Login{
					Outcome: &results.Login_HumanVerificationRequired_{
						HumanVerificationRequired: &results.Login_HumanVerificationRequired{
							Uri: uri,
						},
					},
				},
			},
		}
	}
	requireTotpResult = func(totpEnabled bool) *bridge.Result {
		return &bridge.Result{
			Response: &bridge.Result_Login{
				Login: &results.Login{
					Outcome: &results.Login_TwoFactorRequired_{
						TwoFactorRequired: &results.Login_TwoFactorRequired{
							TotpEnabled: totpEnabled,
						},
					},
				},
			},
		}
	}
)
