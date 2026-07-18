package contacts

import (
	"testing"

	"github.com/emersion/go-vcard"
)

func TestSplitContactCard(t *testing.T) {
	contactCard := make(vcard.Card)
	contactCard.SetValue(vcard.FieldVersion, "4.0")
	contactCard.AddValue(vcard.FieldProductID, "test-product")
	contactCard.AddValue(vcard.FieldProductID, "test-product")
	contactCard.AddValue(vcard.FieldUID, "test-uid")
	contactCard.AddValue(vcard.FieldUID, "duplicate-test-uid")
	contactCard.SetValue(vcard.FieldFormattedName, "Ada Lovelace")
	contactCard.AddValue(vcard.FieldEmail, "ada@example.com")
	contactCard.AddValue(vcard.FieldEmail, "lovelace@example.com")
	contactCard.SetValue(vcard.FieldNote, "private note")
	contactCard.SetValue(VCardFieldIsFavorite, "true")

	publicCard, privateCard := splitContactCard(contactCard)

	for _, field := range []string{
		vcard.FieldProductID,
		vcard.FieldUID,
		vcard.FieldFormattedName,
		vcard.FieldEmail,
	} {
		if publicCard.Get(field) == nil {
			t.Errorf("public card missing %s", field)
		}
		if privateCard.Get(field) != nil {
			t.Errorf("private card contains public field %s", field)
		}
	}
	for field, expectedValue := range map[string]string{
		vcard.FieldProductID: "test-product",
		vcard.FieldUID:       "test-uid",
	} {
		values := publicCard[field]
		if len(values) != 1 {
			t.Errorf("public card has %d %s fields; want 1", len(values), field)
		} else if values[0].Value != expectedValue {
			t.Errorf("public card %s is %q; want %q", field, values[0].Value, expectedValue)
		}
	}
	if emails := publicCard[vcard.FieldEmail]; len(emails) != 2 {
		t.Errorf("public card has %d EMAIL fields; want 2", len(emails))
	}

	for cardName, card := range map[string]vcard.Card{
		"public":  publicCard,
		"private": privateCard,
	} {
		versions := card[vcard.FieldVersion]
		if len(versions) != 1 || versions[0].Value != "4.0" {
			t.Errorf("%s card has invalid VERSION fields: %#v", cardName, versions)
		}
		if _, err := vcardToString(card); err != nil {
			t.Errorf("%s card must be encodable: %v", cardName, err)
		}
	}

	for _, field := range []string{vcard.FieldNote, VCardFieldIsFavorite} {
		if privateCard.Get(field) == nil {
			t.Errorf("private card missing %s", field)
		}
		if publicCard.Get(field) != nil {
			t.Errorf("public card contains private field %s", field)
		}
	}
}
