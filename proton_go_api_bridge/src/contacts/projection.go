package contacts

import (
	"proton_go_api_bridge/native/database/models"
	"proton_go_api_bridge/native/utils"

	"github.com/ProtonMail/go-proton-api"
)

func getProtonCardsFromContact(contact *models.Contact) proton.Cards {
	return utils.MapSlice(contact.Cards, contactCardToProtonCard)
}

func contactCardToProtonCard(c models.ContactCard) *proton.Card {
	return &proton.Card{
		Type:      c.CardType,
		Data:      c.ServerData,
		Signature: c.ServerSignature,
	}
}
