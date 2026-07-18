package contacts

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"maps"
	"proton_go_api_bridge/native/auth"
	"proton_go_api_bridge/native/database"
	"proton_go_api_bridge/native/database/models"
	"proton_go_api_bridge/native/utils"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/ProtonMail/go-proton-api"
	"github.com/ProtonMail/gopenpgp/v2/crypto"
	"github.com/emersion/go-vcard"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

var (
	ErrInitialSyncRequired = errors.New(
		"incremental sync requires a completed full sync",
	)
)

type ContactSyncCallback func(ContactSyncState)

type ContactSyncer struct {
	mu sync.RWMutex

	state     ContactSyncState
	syncError error
	activeRun *syncRun

	CallbackContainer *utils.CallbackContainer[ContactSyncCallback]
}

type syncRun struct {
	done chan struct{}
	err  error
}

var Instance = newContactSyncer()

func newContactSyncer() *ContactSyncer {
	return &ContactSyncer{
		CallbackContainer: utils.NewCallbackContainer[ContactSyncCallback](),
	}
}

func (s *ContactSyncer) State() ContactSyncState {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return s.state
}

func (s *ContactSyncer) SyncError() error {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return s.syncError
}

func (s *ContactSyncer) setResult(state ContactSyncState, err error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.state = state
	s.syncError = err

	snapshot := state
	go s.CallbackContainer.Callbacks()(func(callback ContactSyncCallback) bool {
		callback(snapshot)
		return true
	})
}

func (s *ContactSyncer) GetLocalEventsAvailable() (bool, error) {
	slog.Debug("check if any local events are available from contact sync")
	var count int64
	err := database.Instance.Model(&models.ContactEvent{}).Count(&count).Error
	return count > 0, err
}

// RunIncrementalSync is intended to be used by direct C calls from the native side.
// It starts an incremental sync only if a full sync has been done (otherwise error).
// It blocks all calls until the sync is finished.
func (s *ContactSyncer) RunIncrementalSync() error {
	s.mu.Lock()
	if run := s.activeRun; run != nil {
		s.mu.Unlock()
		slog.Debug("incremental sync already running, waiting for it to finish")

		<-run.done
		return run.err
	}
	run := &syncRun{
		done: make(chan struct{}),
	}
	s.activeRun = run
	defer func() {
		s.mu.Lock()
		defer s.mu.Unlock()
		if s.activeRun == run {
			s.activeRun = nil
		}
	}()
	s.mu.Unlock()

	if database.DatabaseError != nil {
		run.err = fmt.Errorf("database error: %w", database.DatabaseError)
		close(run.done)
		return run.err
	}

	slog.Info("run waiting incremental sync")
	ctx := context.Background()
	state, err := gorm.G[models.SyncState](database.Instance).Take(ctx)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		run.err = ErrInitialSyncRequired
		close(run.done)
		return run.err
	} else if err != nil {
		run.err = fmt.Errorf("failed to get sync state: %w", err)
		close(run.done)
		return run.err
	} else if !state.FullSyncDone || state.LastEventID == nil {
		run.err = ErrInitialSyncRequired
		close(run.done)
		return run.err
	}

	slog.Debug("start incremental sync")
	s.StartSync()

	// wait for the sync to finish
	<-run.done
	return run.err
}

func (s *ContactSyncer) StartSync() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.state == ContactSyncStateRunning {
		slog.Debug("Contact sync already running")
		return false
	}

	s.state = ContactSyncStateRunning
	s.syncError = nil
	go s.CallbackContainer.Callbacks()(func(callback ContactSyncCallback) bool {
		callback(ContactSyncStateRunning)
		return true
	})

	go s.syncContacts()
	return true
}

// TODO: add cancel sync.
// TODO: when full sync is requested, directly restart the sync afterwards.
func (s *ContactSyncer) syncContacts() {
	slog.Info("Starting contact sync")

	/*
		sync works as follows:
		check if there has been a full sync in the database, if not, do a full sync

		full sync:
		1. get the current latest event id from the api
		2. download all contacts with all cards and store them
		3. perform a "normal sync" to update to the absolute latest event id

		normal sync:
		1. get the current latest event id from the api
		2. get all events since the last sync event id from the database
		3. for each event, update the contact(s) in the database accordingly
		4. store the new latest event id in the database
	*/
	var syncErr error
	var state models.SyncState

	defer func() {
		if syncErr != nil {
			slog.Error("Contact sync failed", slog.Any("error", syncErr))
			e := syncErr.Error()
			state.LastError = &e
			s.setResult(ContactSyncStateError, syncErr)
		} else {
			slog.Info("Contact sync finished")
			state.LastError = nil
			s.setResult(ContactSyncStateIdle, nil)
		}
		if database.Instance != nil && database.DatabaseError == nil {
			database.Instance.Save(&state)
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		if s.activeRun != nil {
			s.activeRun.err = syncErr
			close(s.activeRun.done)
		}
	}()

	if database.DatabaseError != nil {
		syncErr = fmt.Errorf("database error: %w", database.DatabaseError)
		return
	}

	ctx := context.Background()

	// get the sync state from the database
	state, err := gorm.G[models.SyncState](database.Instance).Take(ctx)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		// no sync state found, create one
		slog.InfoContext(ctx, "No sync state found, create state")
		state = models.SyncState{}
		err := gorm.G[models.SyncState](database.Instance).Create(ctx, &state)
		if err != nil {
			syncErr = fmt.Errorf("failed to create sync state: %w", err)
			return
		}
	} else if err != nil {
		syncErr = fmt.Errorf("failed to get sync state: %w", err)
		return
	}

	if !state.FullSyncDone || state.LastEventID == nil {
		slog.InfoContext(ctx, "No full sync done yet, doing full sync")
		err := s.fullSync(ctx, &state)
		if err != nil {
			syncErr = fmt.Errorf("failed to do full sync: %w", err)
			return
		}
	}

	slog.InfoContext(ctx, "Doing incremental sync")
	err = s.incrementalSync(ctx, &state)
	if err != nil {
		syncErr = fmt.Errorf("failed to do incremental sync: %w", err)
		return
	}
}

func (s *ContactSyncer) fullSync(ctx context.Context, state *models.SyncState) error {
	slog.DebugContext(ctx, "Starting full contact sync")

	var latestEventID string
	err := auth.Instance.WithClient(func(c *proton.Client) error {
		id, err := c.GetLatestEventID(ctx)
		if err != nil {
			return err
		}
		latestEventID = id
		return nil
	})
	if err != nil {
		return fmt.Errorf("failed to get latest event id: %w", err)
	}

	var protonContacts []proton.Contact
	var protonGroups []proton.Label
	if err = auth.Instance.WithClient(func(c *proton.Client) error {
		cs, err := c.GetAllContacts(ctx)
		if err != nil {
			return fmt.Errorf("failed to get all contacts: %w", err)
		}
		protonContacts = cs

		grps, err := c.GetLabels(ctx, proton.LabelTypeContactGroup)
		if err != nil {
			return fmt.Errorf("failed to get contact groups: %w", err)
		}
		protonGroups = grps

		return nil
	}); err != nil {
		return fmt.Errorf("failed to get contacts and groups: %w", err)
	}
	slog.DebugContext(ctx, "Fetched contacts and groups", slog.Int("contacts", len(protonContacts)), slog.Int("groups", len(protonGroups)))

	intermediates := make([]*intermediateContact, 0, len(protonContacts))
	// TODO: parallelize this, but be careful with the rate limit of the API
	for _, contact := range protonContacts {
		ic, err := fetchContact(ctx, contact.ID)
		if err != nil {
			return fmt.Errorf("failed to fetch contact %s: %w", contact.ID, err)
		}
		intermediates = append(intermediates, ic)
	}
	slog.DebugContext(ctx, "Decrypted contact details", slog.Int("contacts", len(intermediates)))

	if err = database.Instance.Transaction(func(tx *gorm.DB) error {
		var cIDs []string
		if err := tx.Model(&models.Contact{}).Pluck("id", &cIDs).Error; err != nil {
			return fmt.Errorf("failed to get existing contact ids: %w", err)
		}

		// clear db
		if _, err := gorm.G[models.Contact](tx).Where("1 = 1").Delete(ctx); err != nil {
			return fmt.Errorf("failed to delete contacts: %w", err)
		}

		// add all contacts and cards
		cs := utils.MapSlice(intermediates, func(i *intermediateContact) *models.Contact { return i.Contact })
		evs := utils.MapSlice(cs, func(c *models.Contact) models.ContactEvent {
			return models.ContactEvent{
				ContactID: c.ID,
				Action:    models.ContactActionUpsert,
			}
		})
		apiContactIDs := make(map[string]struct{}, len(intermediates))
		for _, i := range intermediates {
			apiContactIDs[i.Contact.ID] = struct{}{}
		}
		dEvs := utils.MapSlice(
			utils.WhereSlice(cIDs, func(id string) bool {
				_, present := apiContactIDs[id]
				return !present
			}),
			func(id string) models.ContactEvent {
				return models.ContactEvent{
					ContactID: id,
					Action:    models.ContactActionDelete,
				}
			})
		if err := tx.Model(&models.Contact{}).Save(&cs).Error; err != nil {
			return fmt.Errorf("failed to create contacts: %w", err)
		}
		if len(evs) > 0 {
			if err := tx.Create(&evs).Error; err != nil {
				return fmt.Errorf("failed to create contact events: %w", err)
			}
		}
		if len(dEvs) > 0 {
			if err := tx.Create(&dEvs).Error; err != nil {
				return fmt.Errorf("failed to create contact events for deleted contacts: %w", err)
			}
		}

		// update sync state
		state.FullSyncDone = true
		state.LastEventID = &latestEventID
		state.LastError = nil
		state.LastSyncAt = utils.Ptr(time.Now())
		if err := tx.Save(state).Error; err != nil {
			return fmt.Errorf("failed to save sync state: %w", err)
		}

		return nil
	}); err != nil {
		return fmt.Errorf("failed to update database: %w", err)
	}

	slog.InfoContext(ctx, "Full sync completed", slog.String("latest_event_id", latestEventID), slog.Int("contacts", len(protonContacts)), slog.Int("groups", len(protonGroups)))
	return nil
}

func (s *ContactSyncer) incrementalSync(ctx context.Context, state *models.SyncState) error {
	slog.DebugContext(ctx, "Starting incremental contact sync")

	if !state.FullSyncDone || state.LastEventID == nil {
		return fmt.Errorf("cannot do incremental sync without a full sync done and a last event id")
	}

	latestEventID := *state.LastEventID
	moreEvents := true
	for moreEvents {
		// incrementally fetch events, update the contacts inside the database
		// and update the new last event id.
		// if more -> repeat, else -> done
		var events []proton.Event
		if err := auth.Instance.WithClient(func(c *proton.Client) error {
			evs, more, err := c.GetEvent(ctx, latestEventID)
			if err != nil {
				return fmt.Errorf("failed to get events: %w", err)
			}
			events = evs
			moreEvents = more
			return nil
		}); err != nil {
			return err
		}
		slog.DebugContext(ctx, "fetched events", slog.Int("count", len(events)), slog.Bool("more", moreEvents))

		if len(events) == 0 {
			slog.InfoContext(ctx, "no events to process")
			break
		}

		latestEventID = events[len(events)-1].EventID
		// models to process.
		// "nil" means we need to fetch the resource from the API since the event was partial.
		contactsUpsert := make(map[string]*intermediateContact)
		contactsDelete := make(map[string]struct{})

		for _, event := range events {
			slog.DebugContext(ctx, "processing event", slog.String("event", event.String()))

			if event.Refresh&proton.RefreshContacts != 0 || event.Refresh == proton.RefreshAll {
				slog.DebugContext(ctx, "refresh (all) event, fetching all contacts and groups")
				// abort and do a full sync next time.
				state.FullSyncDone = false
				state.LastEventID = nil
				state.LastError = nil
				if err := database.Instance.Save(&state).Error; err != nil {
					return fmt.Errorf("failed to save sync state: %w", err)
				}
				return nil
			}

			// first step: CRUD of contacts
			if event.Contacts != nil {
				for _, contactEv := range event.Contacts {
					switch contactEv.Action {
					case proton.EventDelete:
						contactsDelete[contactEv.EventItem.ID] = struct{}{}
						delete(contactsUpsert, contactEv.EventItem.ID)
					case proton.EventPartial:
						contactsUpsert[contactEv.EventItem.ID] = nil
						delete(contactsDelete, contactEv.EventItem.ID)
					default:
						ic, err := processContact(ctx, contactEv.Contact)
						if err != nil {
							return fmt.Errorf("failed to process contact %s: %w", contactEv.EventItem.ID, err)
						}
						contactsUpsert[contactEv.EventItem.ID] = ic
						delete(contactsDelete, contactEv.EventItem.ID)
					}
				}
			}

			// second step: "contact email events", if any is mentioned, fetch the whole new contact
			// if it is not already in the upsert map.
			// for delete: also fetch the whole contact.
			// Exception: if the contact is already in the delete map, we don't need to fetch it again.
			if event.ContactEmails != nil {
				for _, emailEv := range event.ContactEmails {
					var contactID string
					if emailEv.ContactEmail != nil {
						contactID = emailEv.ContactEmail.ContactID
					} else {
						upsertedContacts := slices.Collect(maps.Values(contactsUpsert))
						if idx := slices.IndexFunc(upsertedContacts, func(ic *intermediateContact) bool {
							return ic != nil && slices.Contains(ic.Contact.EmailIDs, emailEv.EventItem.ID)
						}); idx != -1 {
							contactID = upsertedContacts[idx].Contact.ID
						} else {
							emailContact, err := gorm.G[models.Contact](database.Instance).Where("EXISTS (SELECT 1 FROM json_each(contacts.email_ids) WHERE json_each.value = ?)", emailEv.EventItem.ID).Take(ctx)
							if err != nil {
								if errors.Is(err, gorm.ErrRecordNotFound) {
									slog.WarnContext(ctx, "contact not found for email", slog.String("email_id", emailEv.EventItem.ID))
									continue
								}
								return fmt.Errorf("failed to fetch contact for email %s: %w", emailEv.EventItem.ID, err)
							}
							contactID = emailContact.ID
						}
					}

					if _, ok := contactsDelete[contactID]; ok {
						continue
					}
					if _, ok := contactsUpsert[contactID]; !ok {
						contactsUpsert[contactID] = nil
					}
				}
			}
		}

		slog.DebugContext(
			ctx,
			"event calculation complete",
			slog.Int("event_count", len(events)),
			slog.Int("contacts_upsert", len(contactsUpsert)),
			slog.Int("contacts_delete", len(contactsDelete)))

		for k, ic := range contactsUpsert {
			if ic == nil {
				slog.DebugContext(ctx, "fetch contact for upsert from API")
				contact, err := fetchContact(ctx, k)
				if err != nil {
					return fmt.Errorf("failed to fetch contact %s for upsert: %w", k, err)
				}
				contactsUpsert[k] = contact
			}
		}

		nextState := *state
		if err := database.Instance.Transaction(func(tx *gorm.DB) error {
			// CRUD of contacts
			if len(contactsDelete) > 0 {
				if err := tx.Delete(&models.Contact{}, slices.Collect(maps.Keys(contactsDelete))).Error; err != nil {
					return fmt.Errorf("failed to delete contacts: %w", err)
				}
				evs := utils.MapSlice(slices.Collect(maps.Keys(contactsDelete)), func(id string) models.ContactEvent {
					return models.ContactEvent{
						ContactID: id,
						Action:    models.ContactActionDelete,
					}
				})
				if err := tx.Create(&evs).Error; err != nil {
					return fmt.Errorf("failed to create contact events: %w", err)
				}
			}
			if len(contactsUpsert) > 0 {
				for _, ic := range contactsUpsert {
					if err := tx.Where("contact_id = ?", ic.Contact.ID).Delete(&models.ContactCard{}).Error; err != nil {
						return fmt.Errorf("failed to replace cards for contact %s: %w", ic.Contact.ID, err)
					}
					if err := tx.Omit("Cards").Save(ic.Contact).Error; err != nil {
						return fmt.Errorf("failed to upsert contact %s: %w", ic.Contact.ID, err)
					}
					if err := tx.Create(&models.ContactEvent{
						ContactID: ic.Contact.ID,
						Action:    models.ContactActionUpsert,
					}).Error; err != nil {
						return fmt.Errorf("failed to create contact event for upsert: %w", err)
					}
					if len(ic.Contact.Cards) > 0 {
						if err := tx.Create(&ic.Contact.Cards).Error; err != nil {
							return fmt.Errorf("failed to create cards for contact %s: %w", ic.Contact.ID, err)
						}
					}
				}
			}

			nextState.LastEventID = &latestEventID
			nextState.LastSyncAt = utils.Ptr(time.Now())
			nextState.LastError = nil
			if err := tx.Save(&nextState).Error; err != nil {
				return fmt.Errorf("failed to save sync state: %w", err)
			}

			return nil
		}); err != nil {
			return fmt.Errorf("failed to commit transaction: %w", err)
		}
		*state = nextState
	}

	return nil
}

func getSearchFieldsFromVCard(card vcard.Card) string {
	var sb strings.Builder

	for _, n := range card.Names() {
		fmt.Fprintf(&sb, "%s %s %s ", n.FamilyName, n.GivenName, n.AdditionalName)
	}
	for _, n := range card.FormattedNames() {
		fmt.Fprintf(&sb, "%s ", n.Value)
	}
	for _, f := range card.Values(vcard.FieldNickname) {
		fmt.Fprintf(&sb, "%s ", f)
	}
	for _, f := range card.Values(vcard.FieldEmail) {
		e, _ := utils.NormalizeEmail(f)
		fmt.Fprintf(&sb, "%s ", e)
	}
	for _, f := range card.Values(vcard.FieldTelephone) {
		fmt.Fprintf(&sb, "%s ", f)
	}
	for _, adr := range card.Addresses() {
		fmt.Fprintf(&sb, "%s %s %s %s %s %s %s ", adr.PostOfficeBox, adr.ExtendedAddress, adr.StreetAddress, adr.Locality, adr.Region, adr.PostalCode, adr.Country)
	}

	output, err := utils.NormalizeString(sb.String())
	if err != nil {
		slog.Warn("failed to normalize search fields", slog.String("contact", card.Name().FamilyName), slog.Any("error", err))
	}
	return output
}

type intermediateContact struct {
	Contact *models.Contact
}

func processContact(ctx context.Context, protonContact *proton.Contact) (*intermediateContact, error) {
	result := &intermediateContact{}
	type ringMapping struct {
		keyID string
		ring  *crypto.KeyRing
	}
	// decode vcard
	var resultVCard vcard.Card
	var cardKeyID string
	var cardKeyRing *crypto.KeyRing
	if err := auth.Instance.WithAuthenticatedResources(func(_ *proton.Client, userKR *crypto.KeyRing, addressKRs map[string]*crypto.KeyRing) error {
		keys := make([]ringMapping, 0, len(addressKRs)+1)
		keys = append(keys, ringMapping{keyID: "user", ring: userKR})
		for keyID, kr := range addressKRs {
			keys = append(keys, ringMapping{keyID: keyID, ring: kr})
		}

		done := false
		for _, kr := range keys {
			slog.DebugContext(ctx, "merging contact card with key", slog.String("keyid", kr.keyID))
			cc, err := protonContact.Cards.Merge(kr.ring)
			if err != nil {
				slog.ErrorContext(ctx, "failed to merge contact card with key", slog.String("keyid", cardKeyID), slog.Any("error", err))
				continue
			}
			resultVCard = cc
			cardKeyID = kr.keyID
			cardKeyRing = kr.ring
			done = true
			break
		}

		if !done {
			return fmt.Errorf("failed to decrypt contact card for contact %s with any key", protonContact.ID)
		}
		return nil
	}); err != nil {
		return nil, fmt.Errorf("failed to decrypt contact details: %w", err)
	}

	// map to database model (intermediate state)
	// group ids are stored separately since we need to fetch them from the database later
	sb := strings.Builder{}
	encoder := vcard.NewEncoder(&sb)
	encoder.Encode(resultVCard)

	emailIDs := make([]string, 0, len(protonContact.ContactEmails))
	emailGroupIDs := make([]string, 0)
	for _, email := range protonContact.ContactEmails {
		emailIDs = append(emailIDs, email.ID)
		emailGroupIDs = append(emailGroupIDs, email.LabelIDs...)
	}

	groups := slices.DeleteFunc(resultVCard.Categories(), func(group string) bool {
		return strings.TrimSpace(group) == ""
	})

	contactModel := models.Contact{
		ID:             protonContact.ID,
		SyncedAt:       time.Now(),
		SearchFields:   getSearchFieldsFromVCard(resultVCard),
		DecryptedVCard: sb.String(),
		IsFavorite:     isFavorite(resultVCard),
		EmailIDs:       datatypes.NewJSONSlice(emailIDs),
		Groups:         datatypes.NewJSONSlice(groups),
		Cards:          []models.ContactCard{},
	}
	for _, card := range protonContact.Cards {
		// the cards have successfully been decrypted. as such, we can ignore the error.
		cardData, _ := decodeCardToString(card, cardKeyRing)
		contactModel.Cards = append(contactModel.Cards, models.ContactCard{
			ContactID:       protonContact.ID,
			CardType:        card.Type,
			ServerData:      card.Data,
			DecryptedData:   cardData,
			ServerSignature: card.Signature,
			KeyRingID:       &cardKeyID,
		})
	}

	result.Contact = &contactModel

	return result, nil
}

func fetchContact(ctx context.Context, contactID string) (*intermediateContact, error) {
	var protonContact proton.Contact

	// fetch full contact from api
	if err := auth.Instance.WithClient(func(c *proton.Client) error {
		if c, err := c.GetContact(ctx, contactID); err != nil {
			return err
		} else {
			slog.DebugContext(ctx, "downloaded contact", slog.String("name", c.Name))
			protonContact = c
		}
		return nil
	}); err != nil {
		return nil, fmt.Errorf("failed to get contact %s: %w", contactID, err)
	}

	return processContact(ctx, &protonContact)
}
