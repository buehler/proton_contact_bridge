package models

import (
	"github.com/oklog/ulid/v2"
	"gorm.io/gorm"
)

type ContactAction int

const (
	ContactActionUpsert ContactAction = iota + 1
	ContactActionDelete
)

type ContactEvent struct {
	ID string `gorm:"primarykey;type:varchar(26)"`

	ContactID string        `gorm:"not null"`
	Action    ContactAction `gorm:"not null;check:action IN (1, 2)"`
}

func (ce *ContactEvent) BeforeCreate(tx *gorm.DB) (err error) {
	if ce.ID == "" {
		ce.ID = ulid.Make().String()
	}
	return nil
}
