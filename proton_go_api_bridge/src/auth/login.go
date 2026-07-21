package auth

import (
	"context"
	"errors"
	"fmt"
	"proton_go_api_bridge/native/protobuf/bridge"
	"proton_go_api_bridge/native/protobuf/commands"
	"proton_go_api_bridge/native/protobuf/results"
	"proton_go_api_bridge/native/session"
	"strings"

	"github.com/ProtonMail/go-proton-api"
)

func Login(cmd *bridge.Command) (*bridge.Result, error) {
	s, _ := session.GetSession(cmd.SessionId)
	login := cmd.GetLogin()

	switch login.Method.(type) {
	case *commands.Login_InitWithRefresh_:
		return initWithRefresh(s, login.GetInitWithRefresh())
	case *commands.Login_UsernamePassword_:
		return loginWithUsernamePassword(s, login.GetUsernamePassword())
	case *commands.Login_WithHumanVerification_:
		return submitHumanVerification(s, login.GetWithHumanVerification())
	case *commands.Login_Totp:
		return submitTOTP(s, login.GetTotp())
	default:
		return nil, fmt.Errorf("login method %T not implemented", login.Method)
	}
}

func initWithRefresh(s *session.Session, login *commands.Login_InitWithRefresh) (*bridge.Result, error) {
	var result *bridge.Result
	err := s.ExecOnManager(func(m *proton.Manager) error {
		client, auth, err := m.NewClientWithRefresh(context.Background(), login.Uid, login.RefreshToken)
		if err != nil {
			return err
		}

		s.SetClient(client)

		result = &bridge.Result{
			Response: &bridge.Result_Login{
				Login: &results.Login{
					Outcome: &results.Login_Success_{
						Success: &results.Login_Success{
							Session: &results.Login_Session{
								Uid:          auth.UID,
								UserId:       auth.UserID,
								AccessToken:  auth.AccessToken,
								RefreshToken: auth.RefreshToken,
							},
						},
					},
				},
			},
		}

		return nil
	})

	if err != nil {
		return nil, err
	}
	return result, nil
}

func loginWithUsernamePassword(s *session.Session, login *commands.Login_UsernamePassword) (*bridge.Result, error) {
	var result *bridge.Result

	err := s.ExecOnManager(func(m *proton.Manager) error {
		client, auth, err := m.NewClientWithLogin(context.Background(), login.Username, []byte(login.Password))
		if err != nil {
			var apiErr *proton.APIError
			if errors.As(err, &apiErr) && apiErr.IsHVError() {
				details, detailsErr := apiErr.GetHVDetails()
				if detailsErr != nil {
					return fmt.Errorf("get human verification details: %w", detailsErr)
				}

				result = &bridge.Result{
					Response: &bridge.Result_Login{
						Login: &results.Login{
							Outcome: &results.Login_HumanVerificationRequired_{
								HumanVerificationRequired: &results.Login_HumanVerificationRequired{
									Uri: "https://verify.proton.me/?methods=" + strings.Join(details.Methods, ",") + "&token=" + details.Token,
								},
							},
						},
					},
				}
				return nil
			}
			return err
		}

		s.SetClient(client)

		if auth.TwoFA.Enabled&proton.HasTOTP != 0 {
			// TODO: fido as well.
			result = &bridge.Result{
				Response: &bridge.Result_Login{
					Login: &results.Login{
						Outcome: &results.Login_TwoFactorRequired_{
							TwoFactorRequired: &results.Login_TwoFactorRequired{
								TotpEnabled: true,
								Session: &results.Login_Session{
									Uid:          auth.UID,
									UserId:       auth.UserID,
									AccessToken:  auth.AccessToken,
									RefreshToken: auth.RefreshToken,
								},
							},
						},
					},
				},
			}
			return nil
		}
		result = &bridge.Result{
			Response: &bridge.Result_Login{
				Login: &results.Login{
					Outcome: &results.Login_Success_{
						Success: &results.Login_Success{
							Session: &results.Login_Session{
								Uid:          auth.UID,
								UserId:       auth.UserID,
								AccessToken:  auth.AccessToken,
								RefreshToken: auth.RefreshToken,
							},
						},
					},
				},
			},
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	return result, nil
}

func submitHumanVerification(s *session.Session, login *commands.Login_WithHumanVerification) (*bridge.Result, error) {
	hv := proton.APIHVDetails{
		Token:   login.Token,
		Methods: []string{login.Type},
	}
	var result *bridge.Result
	err := s.ExecOnManager(func(m *proton.Manager) error {
		client, auth, err := m.NewClientWithLoginWithHVToken(context.Background(), login.Username, []byte(login.Password), &hv)
		if err != nil {
			return err
		}

		s.SetClient(client)

		if auth.TwoFA.Enabled&proton.HasTOTP != 0 {
			// TODO: fido as well.
			result = &bridge.Result{
				Response: &bridge.Result_Login{
					Login: &results.Login{
						Outcome: &results.Login_TwoFactorRequired_{
							TwoFactorRequired: &results.Login_TwoFactorRequired{
								TotpEnabled: true,
								Session: &results.Login_Session{
									Uid:          auth.UID,
									UserId:       auth.UserID,
									AccessToken:  auth.AccessToken,
									RefreshToken: auth.RefreshToken,
								},
							},
						},
					},
				},
			}
			return nil
		}
		result = &bridge.Result{
			Response: &bridge.Result_Login{
				Login: &results.Login{
					Outcome: &results.Login_Success_{
						Success: &results.Login_Success{
							Session: &results.Login_Session{
								Uid:          auth.UID,
								UserId:       auth.UserID,
								AccessToken:  auth.AccessToken,
								RefreshToken: auth.RefreshToken,
							},
						},
					},
				},
			},
		}

		return nil
	})

	if err != nil {
		return nil, err
	}
	return result, nil
}

func submitTOTP(s *session.Session, login *commands.Login_TOTP) (*bridge.Result, error) {
	var result *bridge.Result
	err := s.ExecOnClient(func(c *proton.Client, m *proton.Manager) error {
		err := c.Auth2FA(context.Background(), proton.Auth2FAReq{
			TwoFactorCode: login.Code,
		})
		if err != nil {
			return err
		}

		result = &bridge.Result{
			Response: &bridge.Result_Login{
				Login: &results.Login{
					Outcome: &results.Login_TwoFactorSuccess_{
						TwoFactorSuccess: &results.Login_TwoFactorSuccess{},
					},
				},
			},
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}
