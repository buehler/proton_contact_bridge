package storage

type SecureStorage interface {
	Exists(key string) (bool, error)
	Set(key string, value []byte) error
	Get(key string) ([]byte, error)
	Delete(key string) error
	DeleteAll() error
}
