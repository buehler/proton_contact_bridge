package auth

import "log/slog"

type AuthState uint8

const (
	AuthStateUninitialized AuthState = iota
	AuthStateInitializing
	AuthStateUnauthenticated
	AuthStateAwaitingHV
	AuthStateAwaitingTOTP
	AuthStateReady
	AuthStateFailed
)

func (a *AuthManager) State() (AuthState, error) {
	a.clientMu.RLock()
	state := a.state
	authErr := a.authErr
	a.clientMu.RUnlock()

	if persistErr := a.persistenceError(); persistErr != nil {
		authErr = persistErr
	}

	slog.Debug("get auth state", "state", state, "error", authErr)
	return state, authErr
}

func (a *AuthManager) setState(state AuthState, err error) {
	a.clientMu.Lock()
	defer a.clientMu.Unlock()

	slog.Debug("set auth state", "state", state, "error", err)
	a.state = state
	a.authErr = err
}
