package contacts

import (
	"log/slog"
	"strconv"
	"strings"

	"proton_go_api_bridge/native/database/models"
	pmodels "proton_go_api_bridge/native/protobuf/models"
	"proton_go_api_bridge/native/utils"

	"github.com/emersion/go-vcard"
)

func mapOpt(f *vcard.Field) *string {
	if f == nil {
		return nil
	}

	return &f.Value
}

func mapReq(f *vcard.Field) string {
	if f == nil {
		return ""
	}

	return f.Value
}

func mapType(f *vcard.Field) *string {
	if f == nil {
		return nil
	}

	types := f.Params.Types()
	if len(types) == 0 {
		return nil
	}
	return &types[0]
}

func mapName(name *vcard.Name) *pmodels.Contact_Name {
	if name == nil {
		return nil
	}

	return &pmodels.Contact_Name{
		FirstName: name.GivenName,
		LastName:  name.FamilyName,
	}
}

func mapImage(f *vcard.Field) *pmodels.Contact_Image {
	return &pmodels.Contact_Image{Uri: mapReq(f)}
}

func mapEmail(f *vcard.Field) *pmodels.Contact_Email {
	return &pmodels.Contact_Email{
		Address: mapReq(f),
		Type:    mapType(f),
	}
}

func mapPhone(f *vcard.Field) *pmodels.Contact_Phone {
	return &pmodels.Contact_Phone{
		Number: mapReq(f),
		Type:   mapType(f),
	}
}

func mapAddress(address *vcard.Address) *pmodels.Contact_Address {
	if address == nil {
		return nil
	}

	return &pmodels.Contact_Address{
		Street:  address.StreetAddress,
		Zip:     address.PostalCode,
		City:    address.Locality,
		Region:  address.Region,
		Country: address.Country,
		Type:    mapType(address.Field),
	}
}

func mapDate(f *vcard.Field) *pmodels.Contact_Date {
	if f == nil || len(f.Value) != 8 {
		return nil
	}

	return &pmodels.Contact_Date{
		Year:  f.Value[:4],
		Month: f.Value[4:6],
		Day:   f.Value[6:8],
	}
}

func MapContactToProto(contact models.Contact) *pmodels.Contact {
	card, err := vcard.NewDecoder(strings.NewReader(contact.DecryptedVCard)).Decode()
	if err != nil {
		slog.Error("failed to decode vcard", slog.Any("error", err))
		return nil
	}

	return &pmodels.Contact{
		Id:            contact.ID,
		FormattedName: card.PreferredValue(vcard.FieldFormattedName),
		Name:          mapName(card.Name()),
		IsFavorite:    contact.IsFavorite,
		Gender:        mapOpt(card.Get(vcard.FieldGender)),
		Logos:         utils.MapSlice(card[vcard.FieldLogo], mapImage),
		Title:         mapOpt(card.Get(vcard.FieldTitle)),
		Organization:  mapOpt(card.Get(vcard.FieldOrganization)),
		Photos:        utils.MapSlice(card[vcard.FieldPhoto], mapImage),
		Emails:        utils.MapSlice(card[vcard.FieldEmail], mapEmail),
		Phones:        utils.MapSlice(card[vcard.FieldTelephone], mapPhone),
		Addresses:     utils.MapSlice(card.Addresses(), mapAddress),
		Birthday:      mapDate(card.Get(vcard.FieldBirthday)),
		Anniversary:   mapDate(card.Get(vcard.FieldAnniversary)),
		Notes:         card.Values(vcard.FieldNote),
		Urls:          card.Values(vcard.FieldURL),
		Roles:         card.Values(vcard.FieldRole),
		Groups:        card.Categories(),
	}
}

func MapProtoToVCard(contact *pmodels.Contact) vcard.Card {
	card := make(vcard.Card)
	if contact == nil {
		return card
	}

	if contact.Name != nil {
		card.SetName(&vcard.Name{
			GivenName:  contact.Name.FirstName,
			FamilyName: contact.Name.LastName,
		})
	}

	card.SetValue(vcard.FieldFormattedName, contact.FormattedName)
	if contact.IsFavorite {
		card.SetValue("X-PCB-FAVORITE", "true")
	}
	setOptionalValue(card, vcard.FieldGender, contact.Gender)
	setOptionalValue(card, vcard.FieldTitle, contact.Title)
	setOptionalValue(card, vcard.FieldOrganization, contact.Organization)

	for _, image := range contact.Logos {
		if image != nil {
			card.AddValue(vcard.FieldLogo, image.Uri)
		}
	}
	for _, image := range contact.Photos {
		if image != nil {
			card.AddValue(vcard.FieldPhoto, image.Uri)
		}
	}
	for index, email := range contact.Emails {
		if email != nil {
			field := fieldWithType(email.Address, email.Type)
			field.Group = "item" + strconv.Itoa(index+1)
			card.Add(vcard.FieldEmail, field)
		}
	}
	for _, phone := range contact.Phones {
		if phone != nil {
			card.Add(vcard.FieldTelephone, fieldWithType(phone.Number, phone.Type))
		}
	}
	for _, address := range contact.Addresses {
		if address != nil {
			card.AddAddress(&vcard.Address{
				Field:         fieldWithType("", address.Type),
				StreetAddress: address.Street,
				PostalCode:    address.Zip,
				Locality:      address.City,
				Region:        address.Region,
				Country:       address.Country,
			})
		}
	}
	setDate(card, vcard.FieldBirthday, contact.Birthday)
	setDate(card, vcard.FieldAnniversary, contact.Anniversary)

	for _, note := range contact.Notes {
		card.AddValue(vcard.FieldNote, note)
	}
	for _, url := range contact.Urls {
		card.AddValue(vcard.FieldURL, url)
	}
	for _, role := range contact.Roles {
		card.AddValue(vcard.FieldRole, role)
	}
	if len(contact.Groups) > 0 {
		card.SetCategories(contact.Groups)
	}

	return card
}

func setOptionalValue(card vcard.Card, key string, value *string) {
	if value != nil {
		card.SetValue(key, *value)
	}
}

func fieldWithType(value string, fieldType *string) *vcard.Field {
	field := &vcard.Field{Value: value}
	if fieldType != nil {
		field.Params = vcard.Params{vcard.ParamType: {*fieldType}}
	}
	return field
}

func setDate(card vcard.Card, key string, date *pmodels.Contact_Date) {
	if date != nil {
		month := date.Month
		if len(month) == 1 {
			month = "0" + month
		}
		day := date.Day
		if len(day) == 1 {
			day = "0" + day
		}
		card.SetValue(key, date.Year+month+day)
	}
}
