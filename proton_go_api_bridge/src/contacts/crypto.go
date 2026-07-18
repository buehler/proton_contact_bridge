package contacts

import (
	"bytes"

	"github.com/ProtonMail/go-proton-api"
	"github.com/ProtonMail/gopenpgp/v2/crypto"
	"github.com/emersion/go-vcard"
)

func decodeCardToString(c *proton.Card, kr *crypto.KeyRing) (string, error) {
	result := c.Data

	if c.Type&proton.CardTypeEncrypted != 0 {
		enc, err := crypto.NewPGPMessageFromArmored(c.Data)
		if err != nil {
			return "", err
		}

		dec, err := kr.Decrypt(enc, nil, crypto.GetUnixTime())
		if err != nil {
			return "", err
		}

		result = dec.GetString()
	}

	if c.Type&proton.CardTypeSigned != 0 {
		sig, err := crypto.NewPGPSignatureFromArmored(c.Signature)
		if err != nil {
			return "", err
		}

		if err := kr.VerifyDetached(crypto.NewPlainMessageFromString(result), sig, crypto.GetUnixTime()); err != nil {
			return "", err
		}
	}

	return result, nil
}

func encodeCard(c vcard.Card, cardType proton.CardType, kr *crypto.KeyRing) (proton.Card, error) {
	buf := new(bytes.Buffer)

	result := proton.Card{
		Type: cardType,
	}

	if err := vcard.NewEncoder(buf).Encode(c); err != nil {
		return proton.Card{}, err
	}

	if cardType&proton.CardTypeSigned != 0 {
		sig, err := kr.SignDetached(crypto.NewPlainMessageFromString(buf.String()))
		if err != nil {
			return proton.Card{}, err
		}

		if result.Signature, err = sig.GetArmored(); err != nil {
			return proton.Card{}, err
		}
	}

	if cardType&proton.CardTypeEncrypted != 0 {
		enc, err := kr.Encrypt(crypto.NewPlainMessageFromString(buf.String()), nil)
		if err != nil {
			return proton.Card{}, err
		}

		if result.Data, err = enc.GetArmored(); err != nil {
			return proton.Card{}, err
		}
	} else {
		result.Data = buf.String()
	}

	return result, nil
}
