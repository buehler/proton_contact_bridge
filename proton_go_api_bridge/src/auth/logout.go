package auth

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"proton_go_api_bridge/native/database"
	"proton_go_api_bridge/native/storage"
)

func (a *AuthManager) Logout(ctx context.Context) error {
	a.authMu.Lock()
	defer a.authMu.Unlock()

	a.clientMu.Lock()
	defer a.clientMu.Unlock()

	slog.DebugContext(ctx, "logout")

	// All WithClient readers have now finished and new readers are blocked.
	client := a.client

	if client != nil {
		if err := client.AuthDelete(ctx); err != nil {
			slog.WarnContext(
				ctx,
				"failed to revoke remote authentication",
				slog.Any("error", err),
			)
		}

		client.Close()
	}

	a.credentialMu.Lock()
	err := a.store.DeleteAll()
	a.latestCredential = RefreshInfo{}
	a.credentialDirty = false
	a.credentialDeletePending = false
	a.credentialRejected = false
	a.credentialSuperseded = false
	a.credentialMu.Unlock()

	defer func() {
		slog.DebugContext(ctx, "Reset database")
		database.Reset()
	}()

	if err != nil && !errors.Is(err, storage.ErrKeyNotFound) {
		slog.ErrorContext(ctx, "delete stored secrets", slog.Any("error", err))
		return fmt.Errorf("delete stored secrets: %w", err)
	}

	a.clearPendingCredentials()
	a.clearPersistenceError()

	a.client = nil
	a.userKR = nil
	a.addressKRs = nil
	a.state = AuthStateUnauthenticated
	a.authErr = nil

	slog.InfoContext(ctx, "logout success")

	return nil
}
