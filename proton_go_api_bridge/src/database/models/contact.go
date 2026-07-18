package models

import (
	"time"

	"github.com/ProtonMail/go-proton-api"
	"gorm.io/datatypes"
)

type Contact struct {
	ID        string `gorm:"primarykey"`
	UpdatedAt time.Time
	SyncedAt  time.Time

	SearchFields   string
	DecryptedVCard string

	IsFavorite bool `gorm:"default:false"`

	EmailIDs datatypes.JSONSlice[string]
	Groups   datatypes.JSONSlice[string]
	Cards    []ContactCard `gorm:"constraint:OnDelete:CASCADE;"`
}

type ContactCard struct {
	ID        uint `gorm:"primarykey"`
	CreatedAt time.Time
	UpdatedAt time.Time

	ContactID string `gorm:"index:idx_contact_cards_contact_id"`

	CardType        proton.CardType
	ServerData      string
	DecryptedData   string
	ServerSignature string
	KeyRingID       *string
}
