package models

import "time"

type SyncState struct {
	ID        uint `gorm:"primarykey"`
	CreatedAt time.Time
	UpdatedAt time.Time

	FullSyncDone bool
	LastEventID  *string
	LastSyncAt   *time.Time
	LastError    *string
}
