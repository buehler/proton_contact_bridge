package auth

import (
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"proton_go_api_bridge/native/storage"

	"github.com/ProtonMail/go-proton-api"
)

type RefreshInfo struct {
	UID          string
	AccessToken  string
	RefreshToken string
	Generation   uint64
}

func (a *AuthManager) persistInitialAuth(nextAuth proton.Auth) error {
	return a.persistAuth(nextAuth)
}

func (a *AuthManager) persistAuth(nextAuth proton.Auth) error {
	a.credentialMu.Lock()
	defer a.credentialMu.Unlock()

	next := RefreshInfo{
		UID:          nextAuth.UID,
		AccessToken:  nextAuth.AccessToken,
		RefreshToken: nextAuth.RefreshToken,
		Generation:   a.latestCredential.Generation + 1,
	}
	if next.UID == "" {
		next.UID = a.latestCredential.UID
	}

	a.latestCredential = next
	a.credentialDirty = true
	a.credentialDeletePending = false
	return a.flushCredentialPersistenceLocked()
}

func (a *AuthManager) flushCredentialPersistence() error {
	a.credentialMu.Lock()
	defer a.credentialMu.Unlock()

	return a.flushCredentialPersistenceLocked()
}

func (a *AuthManager) flushCredentialPersistenceLocked() error {
	if a.credentialDeletePending {
		err := a.store.Delete(storage.KeyRefreshInfo)
		if err != nil && !errors.Is(err, storage.ErrKeyNotFound) {
			wrapped := fmt.Errorf("%w: delete credential: %v", ErrCredentialPersistence, err)
			a.setPersistenceError(wrapped)
			return wrapped
		}

		a.latestCredential = RefreshInfo{}
		a.credentialDeletePending = false
		a.clearPersistenceError()
		return nil
	}

	if !a.credentialDirty {
		return a.persistenceError()
	}

	if err := a.storeRefreshInfo(a.latestCredential); err != nil {
		wrapped := fmt.Errorf("%w: %v", ErrCredentialPersistence, err)
		a.setPersistenceError(wrapped)
		slog.Error(
			"failed to persist authentication",
			slog.Uint64("generation", a.latestCredential.Generation),
			slog.String("uid", a.latestCredential.UID),
			slog.String("access_token", tokenFingerprint(a.latestCredential.AccessToken)),
			slog.String("refresh_token", tokenFingerprint(a.latestCredential.RefreshToken)),
			slog.Any("error", wrapped),
		)
		return wrapped
	}

	a.credentialDirty = false
	a.clearPersistenceError()
	slog.Debug(
		"persisted authentication",
		slog.Uint64("generation", a.latestCredential.Generation),
		slog.String("uid", a.latestCredential.UID),
		slog.String("access_token", tokenFingerprint(a.latestCredential.AccessToken)),
		slog.String("refresh_token", tokenFingerprint(a.latestCredential.RefreshToken)),
	)
	return nil
}

func (a *AuthManager) loadRefreshInfo() (RefreshInfo, error) {
	data, err := a.store.Get(storage.KeyRefreshInfo)
	if err != nil {
		return RefreshInfo{}, err
	}

	var info RefreshInfo
	if err := json.Unmarshal(data, &info); err != nil {
		return RefreshInfo{}, fmt.Errorf(
			"decode refresh information: %w",
			err,
		)
	}

	return info, nil
}

func (a *AuthManager) storeRefreshInfo(info RefreshInfo) error {
	data, err := json.Marshal(info)
	if err != nil {
		return fmt.Errorf("encode refresh information: %w", err)
	}

	if err := a.store.Set(storage.KeyRefreshInfo, data); err != nil {
		return fmt.Errorf("store refresh information: %w", err)
	}

	return nil
}

func tokenFingerprint(token string) string {
	if token == "" {
		return "empty"
	}

	sum := sha256.Sum256([]byte(token))
	return fmt.Sprintf("%x", sum[:6])
}
