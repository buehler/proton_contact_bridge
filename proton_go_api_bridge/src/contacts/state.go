package contacts

type ContactSyncState uint8

const (
	ContactSyncStateIdle ContactSyncState = iota
	ContactSyncStateRunning
	ContactSyncStateError
)
