package auth

import "errors"

var (
	ErrNotReady              = errors.New("auth manager not ready")
	ErrUnauthenticated       = errors.New("authentication required")
	ErrHVRequired            = errors.New("human verification required")
	ErrTOTPRequired          = errors.New("TOTP required")
	ErrKeyRingsMissing       = errors.New("stored key rings are missing or incomplete")
	ErrCredentialPersistence = errors.New("credential persistence failed")
	ErrCredentialSuperseded  = errors.New("credential was superseded; retry request")
)

type HumanVerificationRequiredError struct {
	URI string
}

func (*HumanVerificationRequiredError) Error() string {
	return ErrHVRequired.Error()
}

func (*HumanVerificationRequiredError) Unwrap() error {
	return ErrHVRequired
}
