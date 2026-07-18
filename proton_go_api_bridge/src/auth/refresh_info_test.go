package auth

import (
	"context"
	"errors"
	"sync"
	"testing"

	"github.com/ProtonMail/go-proton-api"

	"proton_go_api_bridge/native/storage"
)

type testSecureStorage struct {
	mu     sync.Mutex
	values map[string][]byte
	setErr error
}

func newTestSecureStorage() *testSecureStorage {
	return &testSecureStorage{values: make(map[string][]byte)}
}

func (s *testSecureStorage) Exists(key string) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, exists := s.values[key]
	return exists, nil
}

func (s *testSecureStorage) Set(key string, value []byte) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.setErr != nil {
		return s.setErr
	}
	s.values[key] = append([]byte(nil), value...)
	return nil
}

func (s *testSecureStorage) Get(key string) ([]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	value, exists := s.values[key]
	if !exists {
		return nil, storage.ErrKeyNotFound
	}
	return append([]byte(nil), value...), nil
}

func (s *testSecureStorage) Delete(key string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.values, key)
	return nil
}

func (s *testSecureStorage) DeleteAll() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	clear(s.values)
	return nil
}

func TestPersistAuthStoresCompleteCredential(t *testing.T) {
	store := newTestSecureStorage()
	manager := NewAuthManager(store)

	err := manager.persistAuth(proton.Auth{
		UID:          "uid",
		AccessToken:  "access",
		RefreshToken: "refresh",
	})
	if err != nil {
		t.Fatalf("persist auth: %v", err)
	}

	stored, err := manager.loadRefreshInfo()
	if err != nil {
		t.Fatalf("load auth: %v", err)
	}
	if stored.UID != "uid" ||
		stored.AccessToken != "access" ||
		stored.RefreshToken != "refresh" ||
		stored.Generation != 1 {
		t.Fatalf("unexpected stored auth: %+v", stored)
	}
}

func TestMissingAccessTokenDecodesAsEmpty(t *testing.T) {
	store := newTestSecureStorage()
	store.values[storage.KeyRefreshInfo] = []byte(
		`{"UID":"uid","RefreshToken":"refresh","Generation":4}`,
	)
	manager := NewAuthManager(store)

	stored, err := manager.loadRefreshInfo()
	if err != nil {
		t.Fatalf("load auth: %v", err)
	}
	if stored.AccessToken != "" {
		t.Fatalf("expected empty access token, got %q", stored.AccessToken)
	}
}

func TestCreateClientFromStoreDoesNotRefresh(t *testing.T) {
	store := newTestSecureStorage()
	manager := NewAuthManager(store)
	if err := manager.storeRefreshInfo(RefreshInfo{
		UID:          "uid",
		AccessToken:  "access",
		RefreshToken: "refresh",
		Generation:   3,
	}); err != nil {
		t.Fatalf("seed auth: %v", err)
	}

	client, err := manager.createClientFromStore(context.Background())
	if err != nil {
		t.Fatalf("create client: %v", err)
	}
	client.Close()
}

func TestFailedPersistenceRetainsCredentialForRetry(t *testing.T) {
	store := newTestSecureStorage()
	store.setErr = errors.New("temporary storage failure")
	manager := NewAuthManager(store)

	err := manager.persistAuth(proton.Auth{
		UID:          "uid",
		AccessToken:  "access",
		RefreshToken: "refresh",
	})
	if !errors.Is(err, ErrCredentialPersistence) {
		t.Fatalf("expected persistence error, got %v", err)
	}
	if !manager.credentialDirty {
		t.Fatal("expected credential to remain dirty")
	}

	store.setErr = nil
	if err := manager.flushCredentialPersistence(); err != nil {
		t.Fatalf("retry persistence: %v", err)
	}
	if manager.credentialDirty {
		t.Fatal("expected credential to be clean after retry")
	}

	stored, err := manager.loadRefreshInfo()
	if err != nil {
		t.Fatalf("load auth: %v", err)
	}
	if stored.RefreshToken != "refresh" || stored.Generation != 1 {
		t.Fatalf("unexpected stored auth after retry: %+v", stored)
	}
}

func TestConcurrentPersistenceCannotOverwriteGeneration(t *testing.T) {
	const count = 32

	store := newTestSecureStorage()
	manager := NewAuthManager(store)
	var waitGroup sync.WaitGroup

	for index := 0; index < count; index++ {
		waitGroup.Add(1)
		go func() {
			defer waitGroup.Done()
			if err := manager.persistAuth(proton.Auth{
				UID:          "uid",
				AccessToken:  "access",
				RefreshToken: "refresh",
			}); err != nil {
				t.Errorf("persist auth: %v", err)
			}
		}()
	}
	waitGroup.Wait()

	stored, err := manager.loadRefreshInfo()
	if err != nil {
		t.Fatalf("load auth: %v", err)
	}
	if stored.Generation != count {
		t.Fatalf("expected generation %d, got %d", count, stored.Generation)
	}
}

func TestDeauthUsesNewerStoredGeneration(t *testing.T) {
	store := newTestSecureStorage()
	manager := NewAuthManager(store)
	manager.latestCredential = RefreshInfo{
		UID:          "uid",
		AccessToken:  "old-access",
		RefreshToken: "old-refresh",
		Generation:   1,
	}
	if err := manager.storeRefreshInfo(RefreshInfo{
		UID:          "uid",
		AccessToken:  "new-access",
		RefreshToken: "new-refresh",
		Generation:   2,
	}); err != nil {
		t.Fatalf("seed auth: %v", err)
	}

	manager.handleDeauth()

	if manager.credentialRejected {
		t.Fatal("newer stored credential must not be rejected")
	}
	if !manager.credentialSuperseded {
		t.Fatal("expected current client credential to be superseded")
	}
	if manager.latestCredential.Generation != 2 {
		t.Fatalf(
			"expected generation 2, got %d",
			manager.latestCredential.Generation,
		)
	}
}

func TestDeauthRejectsNewestGeneration(t *testing.T) {
	store := newTestSecureStorage()
	manager := NewAuthManager(store)
	manager.latestCredential = RefreshInfo{
		UID:          "uid",
		AccessToken:  "access",
		RefreshToken: "refresh",
		Generation:   2,
	}
	if err := manager.storeRefreshInfo(manager.latestCredential); err != nil {
		t.Fatalf("seed auth: %v", err)
	}

	manager.handleDeauth()

	if !manager.credentialRejected {
		t.Fatal("expected newest credential to be rejected")
	}
	if manager.credentialSuperseded {
		t.Fatal("newest credential cannot be superseded")
	}
}
