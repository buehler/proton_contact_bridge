# iPhone Contact List

Status: approved design direction for the first compact-width screen.

## Screen behavior

- Favorites are ordered before other contacts without a separate Favorites section header.
- Non-favorite contacts are grouped under alphabetic section headers.
- Search filters by contact name, email address, phone data, and group membership.
- A compact optional chip strip filters by group when space permits.
- The header contains the title, filtered contact count, quiet synchronization state, and Add action.
- Contact selection opens the contact detail route and preserves list position when returning.
- Bottom navigation contains Contacts, Groups, and Settings. Logs are reached through Settings.
- Refresh must retain existing list content; do not replace the list with a full-screen spinner.

## Flutter widget inventory

- `KinCryptContactListScreen` — Composes header, search, filters, grouped list, and phone navigation. Variants: loading, loaded, empty, filtered empty, offline, error.
- `KinCryptContactHeader` — Shows the compact title, count, synchronization state, and add action. Variants: synced, syncing, pending, offline, failed.
- `KinCryptAddButton` — Starts contact creation without consuming list space. Variants: labeled, compact icon.
- `KinCryptSearchField` — Filters contacts by name and contact data. Variants: idle, focused, populated, no results.
- `KinCryptGroupFilterStrip` — Provides optional direct filtering for frequently used groups. Variants: hidden, all, selected group, horizontal overflow.
- `KinCryptContactList` — Renders favorites first and then alphabetic sections. Variants: comfortable, compact, refreshing.
- `KinCryptAlphabetHeader` — Marks a first-letter boundary in the list. Variants: inline, sticky.
- `KinCryptContactRow` — Opens one contact from the list. Variants: standard, favorite, photo, initials, pressed.
- `KinCryptContactAvatar` — Displays a contact photo or generated initials. Variants: photo, initials, favorite badge, unavailable.
- `KinCryptSyncIndicator` — Reports source-of-truth state without dominating the header. Variants: synced, syncing, pending, offline, failed.
- `KinCryptBottomNavigation` — Switches between the three phone destinations. Variants: contacts selected, groups selected, settings selected.

## Composition notes

The search field remains visible because retrieval is a primary contact-manager task. Group filtering is secondary and may be removed at narrow widths or when no meaningful groups exist. The header must remain compact enough that the list owns most of the vertical viewport.

## Sync Indicator behavior

The sync indicator is directly below “Contacts”: the green dot and “synced now” text beside the contact count.

In the current mockup it is static; search and group filtering change only the contact count.

Intended behavior:

- `Synced` — green dot, “synced now”; passive.
- `Syncing` — spinner, “syncing…”; triggered by refresh or background synchronization.
- `Pending` — amber dot, “changes pending”.
- `Offline` — offline icon, “offline”.
- `Failed` — red alert icon, “sync failed”; tapping opens sync details with the error and retry action.

Tapping non-error states opens a compact status sheet showing Proton as the source, last successful sync, pending changes, and current activity. It does not occupy navigation or interrupt contact browsing.
