package utils

import (
	"net/mail"
	"regexp"
	"strings"
	"unicode"

	"golang.org/x/text/runes"
	"golang.org/x/text/transform"
	"golang.org/x/text/unicode/norm"
)

var spaceRegex = regexp.MustCompile(`\s+`)

// NormalizeText normalizes the input text by removing diacritics,
// remove repeated whitespace, apply unicode normalization,
// and converting it to lowercase.
func NormalizeString(input string) (string, error) {
	transformer := transform.Chain(norm.NFD, runes.Remove(runes.In(unicode.Mn)), norm.NFC)
	output, _, err := transform.String(transformer, strings.ToLower(input))
	if err != nil {
		return "", err
	}

	output = spaceRegex.ReplaceAllString(output, " ")
	return strings.TrimSpace(output), nil
}

func NormalizeEmail(email string) (string, error) {
	addr, err := mail.ParseAddress(email)
	if err != nil {
		return "", err
	}

	return strings.ToLower(addr.Address), nil
}
