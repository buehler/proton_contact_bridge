//go:build !ios && !android && !darwin

package storage

import "errors"

var errSecureStorageUnsupported = errors.New("secure storage is only available on iOS")

type unsupportedSecureStorage struct{}

func NewSecureStorage() SecureStorage {
	return unsupportedSecureStorage{}
}

func (unsupportedSecureStorage) Exists(string) (bool, error) {
	return false, errSecureStorageUnsupported
}

func (unsupportedSecureStorage) Set(string, []byte) error {
	return errSecureStorageUnsupported
}

func (unsupportedSecureStorage) Get(string) ([]byte, error) {
	return nil, errSecureStorageUnsupported
}

func (unsupportedSecureStorage) Delete(string) error {
	return errSecureStorageUnsupported
}

func (unsupportedSecureStorage) DeleteAll() error {
	return errSecureStorageUnsupported
}
