package session

import (
	"errors"
	"sync"

	"github.com/ProtonMail/go-proton-api"
)

type Session struct {
	mu      sync.Mutex
	manager *proton.Manager
	client  *proton.Client
}

func newSession() *Session {
	return &Session{
		manager: proton.New(),
	}
}

func (s *Session) ExecOnManager(fn func(m *proton.Manager) error) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.manager == nil {
		return errors.New("session manager is nil")
	}

	return fn(s.manager)
}

func (s *Session) ExecOnClient(fn func(c *proton.Client, m *proton.Manager) error) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.client == nil {
		return errors.New("session client is nil")
	}

	return fn(s.client, s.manager)
}

func (s *Session) SetClient(c *proton.Client) {
	s.client = c
}

func (s *Session) close() {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.client != nil {
		s.client.Close()
		s.client = nil
	}
	if s.manager != nil {
		s.manager.Close()
		s.manager = nil
	}
}
