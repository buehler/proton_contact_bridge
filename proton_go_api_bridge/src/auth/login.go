package auth

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"proton_go_api_bridge/native/storage"

	"github.com/ProtonMail/go-proton-api"
)

func (a *AuthManager) InitFromStore(ctx context.Context) error {
	slog.DebugContext(ctx, "init auth manager from store")
	a.authMu.Lock()
	defer a.authMu.Unlock()

	if err := a.flushCredentialPersistence(); err != nil {
		return err
	}

	state, err := a.State()

	switch state {
	case AuthStateReady:
		slog.DebugContext(ctx, "auth manager already ready")
		if err != nil {
			return err
		}
		return nil

	case AuthStateUnauthenticated:
		slog.DebugContext(ctx, "auth manager unauthenticated")
		return ErrUnauthenticated

	case AuthStateAwaitingHV:
		slog.DebugContext(ctx, "auth manager awaiting human verification")
		if err != nil {
			return err
		}
		return ErrHVRequired

	case AuthStateAwaitingTOTP:
		slog.DebugContext(ctx, "auth manager awaiting TOTP")
		return ErrTOTPRequired

	case AuthStateFailed:
		if errors.Is(err, ErrCredentialPersistence) {
			break
		}
		slog.ErrorContext(ctx, "auth manager failed", slog.Any("error", err))
		return err
	}

	slog.InfoContext(ctx, "initialize the auth manager")
	a.setState(AuthStateInitializing, nil)

	client, err := a.createClientFromStore(ctx)
	if errors.Is(err, storage.ErrKeyNotFound) {
		a.setState(AuthStateUnauthenticated, nil)
		return ErrUnauthenticated
	}
	if err != nil {
		a.setState(AuthStateFailed, err)
		return err
	}

	userKR, addressKRs, err := a.restoreKeyRings()
	if err != nil {
		client.Close()
		a.setState(AuthStateFailed, err)
		return err
	}

	a.installAuthenticatedResources(client, userKR, addressKRs)

	return nil
}

func (a *AuthManager) LoginWithCredentials(
	ctx context.Context,
	username string,
	password []byte,
) error {
	slog.DebugContext(ctx, "login with credentials")
	a.authMu.Lock()
	defer a.authMu.Unlock()

	if err := a.flushCredentialPersistence(); err != nil {
		return err
	}

	state, stateErr := a.State()
	if state == AuthStateReady {
		if stateErr != nil {
			return stateErr
		}
		return nil
	}

	a.setPendingCredentials(username, password)
	a.setState(AuthStateInitializing, nil)

	client, nextAuth, err := a.manager.NewClientWithLogin(
		ctx,
		username,
		password,
	)
	if err != nil {
		var apiErr *proton.APIError

		if errors.As(err, &apiErr) && apiErr.IsHVError() {
			details, detailsErr := apiErr.GetHVDetails()
			if detailsErr != nil {
				a.clearPendingCredentials()
				a.setState(AuthStateFailed, detailsErr)
				return fmt.Errorf(
					"get human verification details: %w",
					detailsErr,
				)
			}

			hvErr := &HumanVerificationRequiredError{
				URI: humanVerificationURI(
					details.Methods,
					details.Token,
				),
			}
			slog.InfoContext(ctx, "human verification required")
			a.setState(AuthStateAwaitingHV, hvErr)
			return hvErr
		}

		slog.ErrorContext(ctx, "login with credentials", slog.Any("error", err))
		a.clearPendingCredentials()
		a.setState(AuthStateFailed, err)
		return err
	}

	slog.InfoContext(ctx, "login with credentials success")
	return a.finishNewAuthentication(ctx, client, nextAuth)
}

func (a *AuthManager) SubmitHumanVerification(
	ctx context.Context,
	token string,
	method string,
) error {
	a.authMu.Lock()
	defer a.authMu.Unlock()

	state, _ := a.State()
	slog.DebugContext(ctx, "submit human verification")

	switch state {
	case AuthStateReady:
		// Duplicate HV submission after successful authentication.
		return nil

	case AuthStateAwaitingTOTP:
		// HV already succeeded.
		return ErrTOTPRequired

	case AuthStateAwaitingHV:
		// Continue below.
		break

	default:
		return ErrHVRequired
	}

	if a.pendingUsername == "" || len(a.pendingPassword) == 0 {
		err := errors.New("pending HV credentials missing")
		a.setState(AuthStateFailed, err)
		slog.ErrorContext(ctx, "submit human verification", slog.Any("error", err))
		return err
	}

	// Copy the password so pending credentials remain available if HV fails
	// and another token must be submitted.
	password := append([]byte(nil), a.pendingPassword...)
	defer clear(password)

	hv := proton.APIHVDetails{
		Token:   token,
		Methods: []string{method},
	}

	client, nextAuth, err :=
		a.manager.NewClientWithLoginWithHVToken(
			ctx,
			a.pendingUsername,
			password,
			&hv,
		)
	if err != nil {
		// Remain in StateAwaitingHV. The caller can submit another token.
		slog.ErrorContext(ctx, "submit human verification", slog.Any("error", err))
		return fmt.Errorf("submit human verification: %w", err)
	}

	slog.InfoContext(ctx, "submit human verification success")
	return a.finishNewAuthentication(ctx, client, nextAuth)
}

func (a *AuthManager) SubmitTOTP(
	ctx context.Context,
	code string,
) error {
	a.authMu.Lock()
	defer a.authMu.Unlock()

	state, _ := a.State()
	slog.DebugContext(ctx, "submit TOTP")

	if state == AuthStateReady {
		return nil
	}
	if state != AuthStateAwaitingTOTP {
		return ErrTOTPRequired
	}

	// Regular readers cannot run because state is not Ready.
	a.clientMu.RLock()
	client := a.client
	a.clientMu.RUnlock()

	if client == nil {
		err := errors.New("pending authentication client missing")
		slog.ErrorContext(ctx, "submit TOTP", slog.Any("error", err))
		a.setState(AuthStateFailed, err)
		return err
	}

	if err := client.Auth2FA(ctx, proton.Auth2FAReq{
		TwoFactorCode: code,
	}); err != nil {
		slog.ErrorContext(ctx, "submit TOTP", slog.Any("error", err))
		return err
	}

	userKR, addressKRs, err := a.fetchKeyRings(
		ctx,
		client,
		a.pendingPassword,
	)
	if err != nil {
		slog.ErrorContext(ctx, "submit TOTP", slog.Any("error", err))
		a.discardClient(client)
		a.clearPendingCredentials()
		a.setState(AuthStateFailed, err)
		return err
	}
	if err := a.flushCredentialPersistence(); err != nil {
		a.discardClient(client)
		a.clearPendingCredentials()
		a.setState(AuthStateFailed, err)
		return err
	}

	a.clearPendingCredentials()
	a.installAuthenticatedResources(client, userKR, addressKRs)
	slog.InfoContext(ctx, "submit TOTP success")
	return nil
}
