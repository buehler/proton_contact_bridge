package contacts

import (
	"context"
	"fmt"
	"log/slog"
	"maps"
	"proton_go_api_bridge/native/auth"
	"proton_go_api_bridge/native/database"
	"proton_go_api_bridge/native/database/models"
	"proton_go_api_bridge/native/utils"
	"slices"
	"strings"

	"github.com/ProtonMail/go-proton-api"
	"github.com/ProtonMail/gopenpgp/v2/crypto"
	"github.com/emersion/go-vcard"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

const (
	VCardFieldIsFavorite = "X-PCB-FAVORITE"
)

func createContact(ctx context.Context, contactCard vcard.Card) (*models.Contact, error) {
	slog.InfoContext(ctx, "Create contact in database and on API")

	signedAndEncrypted := proton.CardTypeSigned | proton.CardTypeEncrypted
	publicCard, privateCard := splitContactCard(contactCard)

	var protonContactID string
	if err := auth.Instance.WithAuthenticatedResources(func(c *proton.Client, userKR *crypto.KeyRing, _ map[string]*crypto.KeyRing) error {
		pub, err := encodeCard(publicCard, proton.CardTypeSigned, userKR)
		if err != nil {
			return err
		}
		prv, err := encodeCard(privateCard, signedAndEncrypted, userKR)
		if err != nil {
			return err
		}

		res, err := c.CreateContacts(ctx, proton.CreateContactsReq{
			Contacts: []proton.ContactCards{
				{Cards: []*proton.Card{&pub, &prv}},
			},
		})
		if err != nil {
			return err
		} else if len(res) != 1 {
			return fmt.Errorf("unexpected number of contacts created: %d", len(res))
		} else if res[0].Response.APIError.Status > 299 {
			return fmt.Errorf("API error creating contact: %d - %s", res[0].Response.APIError.Status, res[0].Response.APIError.Message)
		} else if res[0].Response.Contact.ID == "" {
			return fmt.Errorf("API did not return a contact ID")
		}

		protonContactID = res[0].Response.Contact.ID
		slog.InfoContext(ctx, "created new contact on API", slog.String("contact_id", protonContactID))

		return err
	}); err != nil {
		slog.ErrorContext(ctx, "Failed to create the contact on the API", slog.Any("error", err))
		return nil, err
	}

	ic, err := fetchContact(ctx, protonContactID)
	if err != nil {
		slog.ErrorContext(ctx, "Failed to fetch the new contact", slog.Any("error", err))
		return nil, err
	}

	if err := database.Instance.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&models.ContactEvent{
			ContactID: ic.Contact.ID,
			Action:    models.ContactActionUpsert,
		}).Error; err != nil {
			return err
		}
		return tx.Create(ic.Contact).Error
	}); err != nil {
		slog.ErrorContext(ctx, "Failed to save contact in database", slog.Any("error", err))
		return nil, err
	}

	return ic.Contact, nil
}

type ContactUpdateFunc func(card vcard.Card) error

func updateContact(ctx context.Context, contactID string, update ContactUpdateFunc) (*models.Contact, error) {
	slog.InfoContext(ctx, "Update contact in database and on API", slog.String("contact_id", contactID))
	if update == nil {
		slog.WarnContext(ctx, "No update function provided, skipping update", slog.String("contact_id", contactID))
		return nil, nil
	}

	c, err := gorm.G[models.Contact](database.Instance).
		Preload("Cards", nil).
		Where("id = ?", contactID).
		Take(ctx)
	if err != nil {
		slog.ErrorContext(ctx, "Failed to fetch contact", slog.String("contact_id", contactID), slog.Any("error", err))
		return nil, err
	}

	contactCard, err := vcard.NewDecoder(strings.NewReader(c.DecryptedVCard)).Decode()
	if err != nil {
		slog.ErrorContext(ctx, "Failed to decode contact vcard", slog.String("contact_id", contactID), slog.Any("error", err))
		return nil, err
	}
	if err := update(contactCard); err != nil {
		slog.ErrorContext(ctx, "Failed to update contact", slog.String("contact_id", contactID), slog.Any("error", err))
		return nil, err
	}

	// Local edits normalize the contact to one signed public card and one
	// encrypted-and-signed private card. Build both from the merged projection so
	// fields cannot remain in the wrong card from an older card layout.
	type newContactCard struct {
		vc    vcard.Card
		t     proton.CardType
		keyID string
		pc    proton.Card
	}

	signedAndEncrypted := proton.CardTypeSigned | proton.CardTypeEncrypted
	publicCard, privateCard := splitContactCard(contactCard)

	newCards := []newContactCard{
		{
			vc:    publicCard,
			t:     proton.CardTypeSigned,
			keyID: keyIDForCardType(c.Cards, proton.CardTypeSigned),
		},
		{
			vc:    privateCard,
			t:     signedAndEncrypted,
			keyID: keyIDForCardType(c.Cards, signedAndEncrypted),
		},
	}

	// now, re-encode the cards to "protoncards" and update them on the API.
	// if success, update the stuff in the db.
	if err := auth.Instance.WithAuthenticatedResources(func(c *proton.Client, userKR *crypto.KeyRing, addressKRs map[string]*crypto.KeyRing) error {
		for i, newCard := range newCards {
			var err error
			var kr *crypto.KeyRing
			if newCard.keyID == "user" {
				kr = userKR
			} else {
				kr = addressKRs[newCard.keyID]
			}
			if kr == nil {
				slog.ErrorContext(ctx, "No keyring found for card", slog.String("contact_id", contactID), slog.String("keyring_id", newCard.keyID))
				return fmt.Errorf("no keyring found for card with keyring id %s", newCard.keyID)
			}
			newCards[i].pc, err = encodeCard(newCard.vc, newCard.t, kr)
			if err != nil {
				return err
			}
		}

		_, err = c.UpdateContact(ctx, contactID, proton.UpdateContactReq{
			Cards: utils.MapSlice(newCards, func(nc newContactCard) *proton.Card {
				return &nc.pc
			}),
		})

		return err
	}); err != nil {
		slog.ErrorContext(ctx, "Failed to update the contact on the API", slog.String("contact_id", contactID), slog.Any("error", err))
		return nil, err
	}

	mergedCard := mergeVCards(newCards[0].vc, newCards[1].vc)
	c.DecryptedVCard, _ = vcardToString(mergedCard)
	c.IsFavorite = isFavorite(mergedCard)
	c.SearchFields = getSearchFieldsFromVCard(mergedCard)
	c.Groups = slices.DeleteFunc(mergedCard.Categories(), func(group string) bool {
		return strings.TrimSpace(group) == ""
	})

	err = database.Instance.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Omit("Cards").Save(&c).Error; err != nil {
			slog.ErrorContext(ctx, "Failed to save contact in database", slog.String("contact_id", contactID), slog.Any("error", err))
			return err
		}

		if err := tx.Where("contact_id = ?", c.ID).Delete(&models.ContactCard{}).Error; err != nil {
			slog.ErrorContext(ctx, "Failed to delete previous contact cards", slog.String("contact_id", contactID), slog.Any("error", err))
			return err
		}

		cards := utils.MapSlice(newCards, func(nc newContactCard) models.ContactCard {
			vcdata, _ := vcardToString(nc.vc)
			return models.ContactCard{
				ContactID:       c.ID,
				CardType:        nc.t,
				KeyRingID:       &nc.keyID,
				DecryptedData:   vcdata,
				ServerData:      nc.pc.Data,
				ServerSignature: nc.pc.Signature,
			}
		})
		if err := tx.Create(&cards).Error; err != nil {
			slog.ErrorContext(ctx, "Failed to create contact cards in database", slog.String("contact_id", contactID), slog.Any("error", err))
			return err
		}
		if err := tx.Create(&models.ContactEvent{
			ContactID: c.ID,
			Action:    models.ContactActionUpsert,
		}).Error; err != nil {
			return err
		}
		c.Cards = cards

		return nil
	})
	if err != nil {
		slog.ErrorContext(ctx, "Failed to save contact and cards in database", slog.String("contact_id", contactID), slog.Any("error", err))
		return nil, err
	}
	return &c, nil
}

func splitContactCard(contactCard vcard.Card) (vcard.Card, vcard.Card) {
	publicCard := make(vcard.Card)
	publicCard.SetValue(vcard.FieldVersion, "4.0")
	copyKeyWithDefault(contactCard, publicCard, vcard.FieldProductID, "cbue.dev/proton-contact-bridge//EN")
	copyKeyWithDefault(contactCard, publicCard, vcard.FieldUID, fmt.Sprintf("contact-bridge-%s", uuid.New()))
	copyKey(contactCard, publicCard, vcard.FieldFormattedName)
	copyKey(contactCard, publicCard, vcard.FieldEmail)

	privateCard := make(vcard.Card)
	maps.Copy(privateCard, contactCard)
	// Proton validates every individual card as a vCard, including the private
	// encrypted card. Keep the card-local VERSION while removing metadata that
	// belongs exclusively to the public card.
	privateCard.SetValue(vcard.FieldVersion, "4.0")
	delete(privateCard, vcard.FieldProductID)
	delete(privateCard, vcard.FieldUID)
	delete(privateCard, vcard.FieldFormattedName)
	delete(privateCard, vcard.FieldEmail)

	return publicCard, privateCard
}

func keyIDForCardType(cards []models.ContactCard, cardType proton.CardType) string {
	for _, card := range cards {
		if card.CardType == cardType && card.KeyRingID != nil && *card.KeyRingID != "" {
			return *card.KeyRingID
		}
	}
	return "user"
}

func vcardToString(card vcard.Card) (string, error) {
	var sb strings.Builder
	if err := vcard.NewEncoder(&sb).Encode(card); err != nil {
		return "", err
	}
	return sb.String(), nil
}

func vcardsToString(cards ...vcard.Card) (string, error) {
	resultCard := mergeVCards(cards...)
	return vcardToString(resultCard)
}

func mergeVCards(cards ...vcard.Card) vcard.Card {
	resultCard := make(vcard.Card)
	for _, card := range cards {
		maps.Copy(resultCard, card)
	}
	return resultCard
}

func copyKey(src, dst vcard.Card, key string) {
	if val, ok := src[key]; ok {
		dst[key] = val
	}
}

func copyKeyWithDefault(src, dst vcard.Card, key string, defaultValue string) {
	if val := src.Get(key); val != nil {
		dst.Set(key, val)
	} else {
		dst.SetValue(key, defaultValue)
	}
}
