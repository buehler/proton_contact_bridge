package auth

import (
	"context"
	"log/slog"
	"net/url"
	"strings"
	"sync"

	"github.com/ProtonMail/go-proton-api"
	"github.com/ProtonMail/gopenpgp/v2/crypto"

	"proton_go_api_bridge/native/storage"
)

type AuthManager struct {
	// sync protobuf auth commands
	authMu sync.Mutex

	// protect state and client
	clientMu sync.RWMutex
	state    AuthState
	client   *proton.Client
	authErr  error

	userKR     *crypto.KeyRing
	addressKRs map[string]*crypto.KeyRing

	// Sync for secure storage refresh info update
	credentialMu            sync.Mutex
	persistErrMu            sync.RWMutex
	persistErr              error
	latestCredential        RefreshInfo
	credentialDirty         bool
	credentialDeletePending bool
	credentialRejected      bool
	credentialSuperseded    bool

	manager *proton.Manager
	store   storage.SecureStorage

	pendingUsername string
	pendingPassword []byte
}

var Instance = NewAuthManager(storage.NewSecureStorage())

func NewAuthManager(store storage.SecureStorage) *AuthManager {
	return &AuthManager{
		state: AuthStateUninitialized,
		manager: proton.New(
			proton.WithAppVersion("Other"),
		),
		store: store,
	}
}

func (a *AuthManager) WithClient(
	fn func(*proton.Client) error,
) error {
	if err := a.flushCredentialPersistence(); err != nil {
		return err
	}

	a.clientMu.RLock()
	if a.state != AuthStateReady || a.client == nil {
		a.clientMu.RUnlock()
		return ErrNotReady
	}

	var err error
	func() {
		defer a.clientMu.RUnlock()
		err = fn(a.client)
	}()
	return a.finishAuthenticatedCall(err)
}

func (a *AuthManager) WithAuthenticatedResources(
	fn func(
		*proton.Client,
		*crypto.KeyRing,
		map[string]*crypto.KeyRing,
	) error,
) error {
	if err := a.flushCredentialPersistence(); err != nil {
		return err
	}

	a.clientMu.RLock()
	if a.state != AuthStateReady ||
		a.client == nil ||
		a.userKR == nil ||
		a.addressKRs == nil {
		a.clientMu.RUnlock()
		return ErrNotReady
	}

	var err error
	func() {
		defer a.clientMu.RUnlock()
		err = fn(a.client, a.userKR, a.addressKRs)
	}()
	return a.finishAuthenticatedCall(err)
}

func (a *AuthManager) createClientFromStore(
	ctx context.Context,
) (*proton.Client, error) {
	a.credentialMu.Lock()
	defer a.credentialMu.Unlock()

	current, err := a.loadRefreshInfo()
	if err != nil {
		return nil, err
	}

	a.latestCredential = current
	a.credentialDirty = false
	a.clearPersistenceError()
	slog.DebugContext(
		ctx,
		"loaded authentication",
		slog.Uint64("generation", current.Generation),
		slog.String("uid", current.UID),
		slog.String("access_token", tokenFingerprint(current.AccessToken)),
		slog.String("refresh_token", tokenFingerprint(current.RefreshToken)),
	)

	client := a.manager.NewClient(
		current.UID,
		current.AccessToken,
		current.RefreshToken,
	)
	client.AddAuthHandler(a.handleAuthRefresh)
	client.AddDeauthHandler(a.handleDeauth)

	return client, nil
}

func (a *AuthManager) handleAuthRefresh(nextAuth proton.Auth) {
	if err := a.persistAuth(nextAuth); err != nil {
		slog.Error(
			"persist automatically refreshed authentication",
			slog.Any("error", err),
		)
	}
}

func (a *AuthManager) handleDeauth() {
	a.credentialMu.Lock()
	defer a.credentialMu.Unlock()

	stored, err := a.loadRefreshInfo()
	if err == nil && stored.Generation > a.latestCredential.Generation {
		a.latestCredential = stored
		a.credentialDirty = false
		a.credentialSuperseded = true
		a.clearPersistenceError()
		return
	}

	a.credentialRejected = true
}

func (a *AuthManager) finishAuthenticatedCall(callErr error) error {
	if err := a.flushCredentialPersistence(); err != nil {
		return err
	}

	a.credentialMu.Lock()
	rejected := a.credentialRejected
	superseded := a.credentialSuperseded
	latest := a.latestCredential
	a.credentialRejected = false
	a.credentialSuperseded = false
	a.credentialMu.Unlock()

	if superseded {
		a.replaceClient(latest)
		return ErrCredentialSuperseded
	}
	if rejected {
		if err := a.invalidateRejectedCredential(); err != nil {
			return err
		}
		return ErrUnauthenticated
	}

	return callErr
}

func (a *AuthManager) replaceClient(info RefreshInfo) {
	client := a.manager.NewClient(info.UID, info.AccessToken, info.RefreshToken)
	client.AddAuthHandler(a.handleAuthRefresh)
	client.AddDeauthHandler(a.handleDeauth)

	a.clientMu.Lock()
	previous := a.client
	a.client = client
	a.clientMu.Unlock()

	if previous != nil && previous != client {
		previous.Close()
	}
}

func (a *AuthManager) invalidateRejectedCredential() error {
	a.clientMu.Lock()
	previous := a.client
	a.client = nil
	a.userKR = nil
	a.addressKRs = nil
	a.state = AuthStateUnauthenticated
	a.authErr = ErrUnauthenticated
	a.clientMu.Unlock()

	if previous != nil {
		previous.Close()
	}

	a.credentialMu.Lock()
	a.credentialDirty = false
	a.credentialDeletePending = true
	err := a.flushCredentialPersistenceLocked()
	a.credentialMu.Unlock()
	if err != nil {
		slog.Error("delete rejected authentication", slog.Any("error", err))
	}
	return err
}

func (a *AuthManager) installClient(client *proton.Client) {
	a.clientMu.Lock()
	defer a.clientMu.Unlock()

	previous := a.client
	a.client = client

	if previous != nil && previous != client {
		previous.Close()
	}
}

func (a *AuthManager) clearPendingCredentials() {
	clear(a.pendingPassword)

	a.pendingUsername = ""
	a.pendingPassword = nil
}

func (a *AuthManager) setPendingCredentials(
	username string,
	password []byte,
) {
	a.clearPendingCredentials()
	a.pendingUsername = username
	a.pendingPassword = append([]byte(nil), password...)
}

func (a *AuthManager) finishNewAuthentication(
	ctx context.Context,
	client *proton.Client,
	nextAuth proton.Auth,
) error {
	if err := a.persistInitialAuth(nextAuth); err != nil {
		client.Close()
		a.clearPendingCredentials()
		a.setState(AuthStateFailed, err)
		return err
	}

	client.AddAuthHandler(a.handleAuthRefresh)
	client.AddDeauthHandler(a.handleDeauth)

	if nextAuth.TwoFA.Enabled&proton.HasTOTP != 0 {
		// TOTP must operate on this pending client. It is installed but remains
		// unavailable to regular readers until all resources are ready.
		a.installClient(client)
		a.setState(AuthStateAwaitingTOTP, nil)
		return ErrTOTPRequired
	}

	userKR, addressKRs, err := a.fetchKeyRings(
		ctx,
		client,
		a.pendingPassword,
	)
	if err != nil {
		client.Close()
		a.clearPendingCredentials()
		a.setState(AuthStateFailed, err)
		return err
	}
	if err := a.flushCredentialPersistence(); err != nil {
		client.Close()
		a.clearPendingCredentials()
		a.setState(AuthStateFailed, err)
		return err
	}

	a.clearPendingCredentials()
	a.installAuthenticatedResources(client, userKR, addressKRs)
	return nil
}

func (a *AuthManager) installAuthenticatedResources(
	client *proton.Client,
	userKR *crypto.KeyRing,
	addressKRs map[string]*crypto.KeyRing,
) {
	a.clientMu.Lock()
	defer a.clientMu.Unlock()

	previous := a.client
	a.client = client
	a.userKR = userKR
	a.addressKRs = addressKRs
	a.state = AuthStateReady
	a.authErr = nil

	if previous != nil && previous != client {
		previous.Close()
	}
}

func (a *AuthManager) discardClient(client *proton.Client) {
	a.clientMu.Lock()
	defer a.clientMu.Unlock()

	if a.client == client {
		a.client = nil
		a.userKR = nil
		a.addressKRs = nil
		client.Close()
	}
}

func (a *AuthManager) persistenceError() error {
	a.persistErrMu.RLock()
	defer a.persistErrMu.RUnlock()

	return a.persistErr
}

func (a *AuthManager) setPersistenceError(err error) {
	a.persistErrMu.Lock()
	defer a.persistErrMu.Unlock()

	a.persistErr = err
}

func (a *AuthManager) clearPersistenceError() {
	a.setPersistenceError(nil)
}

func humanVerificationURI(methods []string, token string) string {
	uri := url.URL{
		Scheme: "https",
		Host:   "verify.proton.me",
		Path:   "/",
	}

	query := uri.Query()
	query.Set("methods", strings.Join(methods, ","))
	query.Set("token", token)
	uri.RawQuery = query.Encode()

	return uri.String()
}
