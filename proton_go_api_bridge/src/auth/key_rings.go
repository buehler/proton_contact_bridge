package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/ProtonMail/gluon/async"
	"github.com/ProtonMail/go-proton-api"
	"github.com/ProtonMail/gopenpgp/v2/crypto"

	"proton_go_api_bridge/native/storage"
)

func (a *AuthManager) restoreKeyRings() (
	*crypto.KeyRing,
	map[string]*crypto.KeyRing,
	error,
) {
	userData, err := a.store.Get(storage.KeyUserKeyRing)
	if err != nil {
		return nil, nil, fmt.Errorf("%w: user key ring: %v", ErrKeyRingsMissing, err)
	}

	userKR, err := crypto.NewKeyRingFromBinary(userData)
	if err != nil {
		return nil, nil, fmt.Errorf("decode stored user key ring: %w", err)
	}

	addressIDsData, err := a.store.Get(storage.KeyAddressIDs)
	if err != nil {
		return nil, nil, fmt.Errorf("%w: address IDs: %v", ErrKeyRingsMissing, err)
	}

	var addressIDs []string
	if err := json.Unmarshal(addressIDsData, &addressIDs); err != nil {
		return nil, nil, fmt.Errorf("decode stored address IDs: %w", err)
	}
	if len(addressIDs) == 0 {
		return nil, nil, fmt.Errorf("%w: no address IDs", ErrKeyRingsMissing)
	}

	addressKRs := make(map[string]*crypto.KeyRing, len(addressIDs))
	for _, id := range addressIDs {
		if id == "" {
			return nil, nil, fmt.Errorf("%w: empty address ID", ErrKeyRingsMissing)
		}
		if _, duplicate := addressKRs[id]; duplicate {
			return nil, nil, fmt.Errorf("%w: duplicate address ID %q", ErrKeyRingsMissing, id)
		}

		data, err := a.store.Get(storage.KeyAddressKeyRing + "_" + id)
		if err != nil {
			return nil, nil, fmt.Errorf(
				"%w: address key ring %q: %v",
				ErrKeyRingsMissing,
				id,
				err,
			)
		}

		addressKR, err := crypto.NewKeyRingFromBinary(data)
		if err != nil {
			return nil, nil, fmt.Errorf(
				"decode stored address key ring %q: %w",
				id,
				err,
			)
		}
		addressKRs[id] = addressKR
	}

	return userKR, addressKRs, nil
}

func (a *AuthManager) fetchKeyRings(
	ctx context.Context,
	client *proton.Client,
	password []byte,
) (
	*crypto.KeyRing,
	map[string]*crypto.KeyRing,
	error,
) {
	userKR, addressKRs, err := a.restoreKeyRings()
	if err == nil {
		slog.InfoContext(ctx, "successfully restored key rings")
		return userKR, addressKRs, nil
	}

	if len(password) == 0 {
		return nil, nil, fmt.Errorf(
			"restore key rings without account password: %w",
			err,
		)
	}

	slog.DebugContext(ctx, "fetch and unlock key rings")

	user, err := client.GetUser(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("get user for key rings: %w", err)
	}

	addresses, err := client.GetAddresses(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("get addresses for key rings: %w", err)
	}

	salts, err := client.GetSalts(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("get salts for key rings: %w", err)
	}

	primary := user.Keys.Primary()
	passwdSalt, err := salts.SaltForKey(password, primary.ID)
	if err != nil {
		return nil, nil, fmt.Errorf("derive key password salt: %w", err)
	}

	userKR, addressKRs, err = proton.Unlock(
		user,
		addresses,
		passwdSalt,
		async.NoopPanicHandler{},
	)
	if err != nil {
		return nil, nil, fmt.Errorf("unlock key rings: %w", err)
	}
	if userKR == nil || len(addressKRs) == 0 {
		return nil, nil, fmt.Errorf("%w: server returned incomplete key rings", ErrKeyRingsMissing)
	}

	if err := a.storeKeyRings(userKR, addressKRs); err != nil {
		return nil, nil, err
	}

	slog.InfoContext(ctx, "successfully fetched and stored key rings")
	return userKR, addressKRs, nil
}

func (a *AuthManager) storeKeyRings(
	userKR *crypto.KeyRing,
	addressKRs map[string]*crypto.KeyRing,
) error {
	userData, err := userKR.Serialize()
	if err != nil {
		return fmt.Errorf("serialize user key ring: %w", err)
	}
	if err := a.store.Set(storage.KeyUserKeyRing, userData); err != nil {
		return fmt.Errorf("store user key ring: %w", err)
	}

	addressIDs := make([]string, 0, len(addressKRs))
	for id, addressKR := range addressKRs {
		if id == "" || addressKR == nil {
			return fmt.Errorf("%w: invalid address key ring", ErrKeyRingsMissing)
		}

		data, err := addressKR.Serialize()
		if err != nil {
			return fmt.Errorf("serialize address key ring %q: %w", id, err)
		}
		if err := a.store.Set(storage.KeyAddressKeyRing+"_"+id, data); err != nil {
			return fmt.Errorf("store address key ring %q: %w", id, err)
		}
		addressIDs = append(addressIDs, id)
	}
	if len(addressIDs) == 0 {
		return fmt.Errorf("%w: no address key rings", ErrKeyRingsMissing)
	}

	addressIDsData, err := json.Marshal(addressIDs)
	if err != nil {
		return fmt.Errorf("encode address IDs: %w", err)
	}
	if err := a.store.Set(storage.KeyAddressIDs, addressIDsData); err != nil {
		return fmt.Errorf("store address IDs: %w", err)
	}

	return nil
}
