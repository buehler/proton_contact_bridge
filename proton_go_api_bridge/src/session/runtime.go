package session

import "sync"

type Runtime struct {
	mu       sync.Mutex
	nextID   uint32
	sessions map[uint32]*Session
}

var runtime = &Runtime{
	sessions: make(map[uint32]*Session),
}

func SessionExists(id uint32) bool {
	runtime.mu.Lock()
	defer runtime.mu.Unlock()

	_, exists := runtime.sessions[id]
	return exists
}

func GetSession(id uint32) (*Session, bool) {
	runtime.mu.Lock()
	defer runtime.mu.Unlock()

	session, exists := runtime.sessions[id]
	return session, exists
}

func CreateSession() uint32 {
	runtime.mu.Lock()
	defer runtime.mu.Unlock()

	runtime.nextID++
	id := runtime.nextID
	runtime.sessions[id] = newSession()
	return id
}

func CloseSession(id uint32) {
	runtime.mu.Lock()
	defer runtime.mu.Unlock()

	session, exists := runtime.sessions[id]
	if !exists {
		return
	}

	session.close()
	delete(runtime.sessions, id)
}
