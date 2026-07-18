package utils

import (
	"iter"
	"maps"
	"sync"
)

type CallbackContainer[T any] struct {
	rwMu      sync.RWMutex
	callbacks map[uint32]T
}

func NewCallbackContainer[T any]() *CallbackContainer[T] {
	return &CallbackContainer[T]{
		callbacks: make(map[uint32]T),
	}
}

func (c *CallbackContainer[T]) Register(registerID uint32, callback T) {
	c.rwMu.Lock()
	defer c.rwMu.Unlock()
	c.callbacks[registerID] = callback
}

func (c *CallbackContainer[T]) Unregister(registerID uint32) {
	c.rwMu.Lock()
	defer c.rwMu.Unlock()
	delete(c.callbacks, registerID)
}

func (c *CallbackContainer[T]) Callbacks() iter.Seq[T] {
	c.rwMu.RLock()
	snapshot := make(map[uint32]T, len(c.callbacks))
	maps.Copy(snapshot, c.callbacks)
	c.rwMu.RUnlock()
	return func(yield func(T) bool) {
		for _, callback := range snapshot {
			if !yield(callback) {
				return
			}
		}
	}
}
