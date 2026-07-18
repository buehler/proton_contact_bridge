package contacts

import (
	"context"
	"log/slog"
	"maps"
	"proton_go_api_bridge/native/auth"
	"proton_go_api_bridge/native/database"
	"proton_go_api_bridge/native/database/models"
	"proton_go_api_bridge/native/utils"

	"github.com/ProtonMail/go-proton-api"
	"github.com/emersion/go-vcard"
	"gorm.io/gorm"
)

type ContactRepository struct {
	db *gorm.DB
}

func NewContactRepository() *ContactRepository {
	return &ContactRepository{
		db: database.Instance,
	}
}

func (r *ContactRepository) GetAll(ctx context.Context) ([]models.Contact, error) {
	slog.DebugContext(ctx, "fetch all contacts")
	var contacts []models.Contact
	if err := r.db.WithContext(ctx).Preload("Cards").Find(&contacts).Error; err != nil {
		return nil, err
	}
	return contacts, nil
}

func (r *ContactRepository) GetFavorites(ctx context.Context) ([]models.Contact, error) {
	slog.DebugContext(ctx, "fetch favorite contacts")
	var contacts []models.Contact
	if err := r.db.WithContext(ctx).
		Preload("Cards").
		Where("is_favorite = ?", true).
		Find(&contacts).Error; err != nil {
		return nil, err
	}
	return contacts, nil
}

func (r *ContactRepository) GetById(ctx context.Context, ID string) (*models.Contact, error) {
	slog.DebugContext(ctx, "fetch contact by id", slog.String("contact_id", ID))
	var contact models.Contact
	err := r.db.WithContext(ctx).Preload("Cards").First(&contact, "id = ?", ID).Error
	if err == gorm.ErrRecordNotFound {
		slog.WarnContext(ctx, "contact not found", slog.String("contact_id", ID))
		return nil, nil
	} else if err != nil {
		slog.ErrorContext(ctx, "failed to fetch contact", slog.String("contact_id", ID), slog.Any("error", err))
		return nil, err
	}

	return &contact, nil
}

func (r *ContactRepository) Search(ctx context.Context, query string) ([]models.Contact, error) {
	slog.DebugContext(ctx, "searching contacts")
	normalizedQuery, err := utils.NormalizeString(query)
	if err != nil {
		return nil, err
	}
	var contacts []models.Contact
	if err := r.db.WithContext(ctx).
		Preload("Cards").
		Where("search_fields LIKE ?", "%"+normalizedQuery+"%").
		Find(&contacts).Error; err != nil {
		return nil, err
	}
	return contacts, nil
}

func (r *ContactRepository) ToggleFavorite(ctx context.Context, ID string) error {
	slog.DebugContext(ctx, "toggling favorite", slog.String("contact_id", ID))
	_, err := updateContact(ctx, ID, func(card vcard.Card) error {
		if !isFavorite(card) {
			card.SetValue("X-PCB-FAVORITE", "true")
		} else {
			delete(card, "X-PCB-FAVORITE")
		}

		return nil
	})
	return err
}

func (r *ContactRepository) Insert(ctx context.Context, contact vcard.Card) (models.Contact, error) {
	slog.DebugContext(ctx, "inserting contact")
	if c, err := createContact(ctx, contact); err != nil {
		slog.ErrorContext(ctx, "failed to create contact", slog.Any("error", err))
		return models.Contact{}, err
	} else {
		return *c, nil
	}
}

func (r *ContactRepository) Update(ctx context.Context, ID string, contact vcard.Card) (models.Contact, error) {
	slog.DebugContext(ctx, "updating contact", slog.String("contact_id", ID))
	if c, err := updateContact(ctx, ID, func(card vcard.Card) error {
		clear(card)
		maps.Copy(card, contact)
		return nil
	}); err != nil {
		slog.ErrorContext(ctx, "failed to update contact", slog.String("contact_id", ID), slog.Any("error", err))
		return models.Contact{}, err
	} else {
		return *c, nil
	}
}

func (r *ContactRepository) Delete(ctx context.Context, ID string) error {
	slog.DebugContext(ctx, "deleting contact", slog.String("contact_id", ID))
	if err := auth.Instance.WithClient(func(c *proton.Client) error {
		return c.DeleteContacts(ctx, proton.DeleteContactsReq{
			IDs: []string{ID},
		})
	}); err != nil {
		slog.ErrorContext(ctx, "failed to delete contact on API", slog.String("contact_id", ID), slog.Any("error", err))
		return err
	}
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Delete(&models.Contact{}, "id = ?", ID).Error; err != nil {
			return err
		}
		return tx.Create(&models.ContactEvent{
			ContactID: ID,
			Action:    models.ContactActionDelete,
		}).Error
	})
}

func isFavorite(card vcard.Card) bool {
	favorite := card.Get("X-PCB-FAVORITE")
	return favorite != nil && favorite.Value == "true"
}
