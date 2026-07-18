//go:build ios || darwin

package storage

import (
	"log/slog"

	"github.com/keybase/go-keychain"
)

func NewSecureStorage() SecureStorage {
	return &AppleSecureStorage{}
}

const (
	keyChainService       = "ch.cbue.protonContactBridge"
	keyChainAccountPrefix = "proton_contact_bridge_"
)

type AppleSecureStorage struct{}

func (i *AppleSecureStorage) Exists(key string) (bool, error) {
	slog.Debug("Checking if key exists in secure storage", slog.String("key", key))
	query := keychain.NewItem()
	query.SetSecClass(keychain.SecClassGenericPassword)
	query.SetService(keyChainService)
	query.SetAccount(keyChainAccountPrefix + key)
	if keyChainGroup != "" {
		query.SetAccessGroup(keyChainGroup)
	}
	query.SetAccessGroup(keyChainGroup)
	query.SetMatchLimit(keychain.MatchLimitOne)
	query.SetReturnData(false)
	query.SetReturnAttributes(true)

	results, err := keychain.QueryItem(query)
	if err != nil {
		slog.Error("Failed to check if key exists in secure storage", slog.Any("error", err))
		return false, err
	}

	return len(results) == 1, nil
}

func (i *AppleSecureStorage) DeleteAll() error {
	slog.Debug("Deleting all keys from secure storage")
	query := keychain.NewItem()
	query.SetSecClass(keychain.SecClassGenericPassword)
	query.SetService(keyChainService)
	if keyChainGroup != "" {
		query.SetAccessGroup(keyChainGroup)
	}

	err := keychain.DeleteItem(query)
	if err != nil {
		slog.Error("Failed to delete all keys from secure storage", slog.Any("error", err))
		return err
	}
	return nil
}

func (i *AppleSecureStorage) Delete(key string) error {
	slog.Debug("Deleting key from secure storage", slog.String("key", key))
	item := keychain.NewItem()
	item.SetSecClass(keychain.SecClassGenericPassword)
	item.SetService(keyChainService)
	item.SetAccount(keyChainAccountPrefix + key)
	if keyChainGroup != "" {
		item.SetAccessGroup(keyChainGroup)
	}
	err := keychain.DeleteItem(item)
	if err != nil {
		slog.Error("Failed to delete key from secure storage", slog.Any("error", err))
		return err
	}
	return nil
}

func (i *AppleSecureStorage) Get(key string) ([]byte, error) {
	slog.Debug("Retrieving key from secure storage", slog.String("key", key))
	query := keychain.NewItem()
	query.SetSecClass(keychain.SecClassGenericPassword)
	query.SetService(keyChainService)
	query.SetAccount(keyChainAccountPrefix + key)
	if keyChainGroup != "" {
		query.SetAccessGroup(keyChainGroup)
	}
	query.SetMatchLimit(keychain.MatchLimitOne)
	query.SetReturnData(true)
	results, err := keychain.QueryItem(query)
	if err != nil {
		slog.Error("Failed to retrieve key from secure storage", slog.Any("error", err))
		return nil, err
	} else if len(results) != 1 {
		slog.Warn("Key not found in secure storage", slog.String("key", key))
		return nil, ErrKeyNotFound // Not found
	} else {
		return results[0].Data, nil
	}
}

func (i *AppleSecureStorage) Set(key string, value []byte) error {
	if exists, err := i.Exists(key); exists {
		slog.Debug("Updating key in secure storage", slog.String("key", key))

		query := keychain.NewItem()
		query.SetSecClass(keychain.SecClassGenericPassword)
		query.SetService(keyChainService)
		query.SetAccount(keyChainAccountPrefix + key)
		if keyChainGroup != "" {
			query.SetAccessGroup(keyChainGroup)
		}

		updateItem := keychain.NewItem()
		updateItem.SetData(value)

		err = keychain.UpdateItem(query, updateItem)
		if err != nil {
			slog.Error("Failed to update key in secure storage", slog.Any("error", err))
			return err
		}
		return nil
	} else if err != nil {
		slog.Error("Failed to check if key exists in secure storage", slog.Any("error", err))
		return err
	}

	slog.Debug("Storing new key in secure storage", slog.String("key", key))
	item := keychain.NewItem()
	item.SetSecClass(keychain.SecClassGenericPassword)
	item.SetService(keyChainService)
	item.SetAccount(keyChainAccountPrefix + key)
	item.SetLabel(key)
	if keyChainGroup != "" {
		item.SetAccessGroup(keyChainGroup)
	}
	item.SetData(value)
	item.SetSynchronizable(keychain.SynchronizableNo)
	item.SetAccessible(keychain.AccessibleAfterFirstUnlockThisDeviceOnly)
	err := keychain.AddItem(item)
	if err != nil {
		slog.Error("Failed to store key in secure storage", slog.Any("error", err))
		return err
	}
	return nil
}
