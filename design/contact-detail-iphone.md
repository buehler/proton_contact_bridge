# iPhone Contact Detail

Status: proposed compact-width design direction.

## Screen behavior

- The contact detail is pushed above the contact or group list as a full-screen route.
- Bottom navigation is absent. The leading back action returns to the previous list and preserves its selection, filter, and scroll position.
- Edit and favorite actions remain visible in the top bar.
- The shared Proton synchronization indicator appears below the contact identity and opens the existing synchronization status sheet.
- Contact identity contains the reused avatar, formatted name, job title, organization, and linked group chips.
- Details follow in flat, scrollable sections: emails, phones, addresses, dates, websites, notes, then deletion.
- Empty fields and empty sections are omitted.
- Delete is separated from everyday actions at the end of the page and requires explicit confirmation.

## Actionable contact values

Email, phone, address, and website rows have two separate touch actions:

1. Tapping the main row launches the platform destination: Mail, native phone handling, Maps, or browser.
2. Tapping the trailing Copy action copies the exact value without opening the destination.

The actions must use independent semantic labels and non-overlapping touch targets. A short non-blocking confirmation follows copy. Launch failures preserve the page and report that no suitable application is available.

At large text sizes, values wrap before actions are removed. Multiline addresses remain readable and open as one address. Do not make long-press the only copy mechanism because it is undiscoverable and inaccessible to some users.

## Destructive action

- `Delete contact` uses `dangerSurface` and `danger` at the end of the scroll content.
- Confirmation names the contact and states that the Proton-backed deletion cannot be undone.
- During deletion, disable repeated confirmation and show progress in the destructive action.
- On success, replace the detail route with the previous list state.
- On failure, keep the contact page available and display a recoverable error.

## New Flutter widget inventory

Previously identified widgets, including `KinCryptContactAvatar`, `KinCryptSyncIndicator`, group chips, and `KinCryptSyncStatusSheet`, are reused and omitted.

- `KinCryptContactDetailScreen` — Composes the pushed contact route. Variants: loading, loaded, not found, offline, error.
- `KinCryptDetailTopBar` — Provides back navigation with favorite and edit actions. Variants: ready, favorite updating, action disabled.
- `KinCryptContactIdentityHeader` — Shows avatar, name, role, organization, groups, and reused sync state. Variants: full, minimal, long identity.
- `KinCryptContactDetailSection` — Groups related values in a flat section. Variants: single row, multiple rows, multiline.
- `KinCryptContactValueRow` — Opens the field's native destination. Variants: email, phone, address, website, passive date.
- `KinCryptCopyAction` — Copies one exact field value with confirmation. Variants: icon, labeled, copied.
- `KinCryptFavoriteButton` — Toggles favorite state. Variants: favorite, not favorite, updating, failed.
- `KinCryptContactNotes` — Renders multiple readable note blocks. Variants: single, multiple, long.
- `KinCryptDeleteContactAction` — Separates destructive deletion from edit. Variants: ready, confirming, deleting, failed.
- `KinCryptDeleteContactDialog` — Confirms permanent Proton deletion. Variants: standard, synchronization pending.
