package storage

const (
	ErrKeyNotFound = storageError("key not found")
)

type storageError string

func (e storageError) Error() string {
	return string(e)
}
