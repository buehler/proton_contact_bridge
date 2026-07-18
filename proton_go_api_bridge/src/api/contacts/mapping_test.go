package contacts

import (
	"testing"

	pmodels "proton_go_api_bridge/native/protobuf/models"

	"github.com/emersion/go-vcard"
)

func TestMapProtoToVCardAssignsUniqueEmailGroups(t *testing.T) {
	card := MapProtoToVCard(&pmodels.Contact{
		Emails: []*pmodels.Contact_Email{
			{Address: "ada@example.com"},
			{Address: "lovelace@example.com"},
		},
	})

	emails := card[vcard.FieldEmail]
	if len(emails) != 2 {
		t.Fatalf("got %d email fields; want 2", len(emails))
	}

	wantGroups := []string{"item1", "item2"}
	for index, email := range emails {
		want := wantGroups[index]
		if email.Group != want {
			t.Errorf("email %d has group %q; want %q", index, email.Group, want)
		}
	}
}
