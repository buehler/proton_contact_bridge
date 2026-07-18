# iPhone Settings

Status: proposed compact-width design direction.

## Screen behavior

- Settings is the third primary phone destination and retains the shared Contacts, Groups, and Settings bottom navigation.
- The screen does not show the contact synchronization indicator.
- Account identity appears first with Proton display name, email address, avatar, and an explicit Log out action.
- Contact preferences save immediately after selection. There is no page-level Save button.
- Logs appears as a secondary navigation row and pushes a separate `/logs` screen above Settings.
- The Logs screen is not added to bottom navigation.

## Account and logout

- Account identity is informative, not editable on this screen.
- Log out requires confirmation and explains that contact data remains in Proton.
- Settings logout and the app-shell avatar logout must call the same authentication-controller operation.
- Disable both logout entry points while logout is running so the operation cannot be duplicated.
- Successful logout clears authenticated navigation state and replaces the current route with `/login`.
- Failed logout keeps the session and Settings screen available with a recoverable error.

## Contact preferences

### Sort contacts by

- `First name` groups and orders the contact list by first name.
- `Last name` groups and orders the contact list by last name.

### Display names

- `First name first` displays names as `Maya Chen`.
- `Last name first` displays names as `Chen Maya`.

Use a two-option segmented control at default phone text sizes. Change to full-width radio rows when text scaling, localization, or available width makes segment labels cramped. Both presentations bind to the same setting model.

Show a short list preview below the controls. The preview updates from the combined sort-order and display-order selections before returning to Contacts.

Preference changes persist immediately. While saving, keep the selected value visible and prevent overlapping writes to the same preference. On failure, restore the prior persisted value and report `Could not save settings`.

## Logs navigation

- The Logs row uses a disclosure indicator and a short diagnostic description.
- Tapping it pushes `/logs` as a separate screen.
- Back returns to the same Settings position and selection state.

## New Flutter widget inventory

Previously identified widgets, including `KinCryptBottomNavigation`, are reused and omitted.

- `KinCryptSettingsScreen` — Composes account, preferences, diagnostics, and reused navigation. Variants: loading, loaded, saving, error.
- `KinCryptSettingsSection` — Groups related settings under a quiet label. Variants: rows, choice controls, error.
- `KinCryptAccountSettingsSection` — Shows current Proton identity and logout entry. Variants: loaded, loading, unavailable.
- `KinCryptAccountIdentityRow` — Displays avatar, display name, email, and provider. Variants: photo, initials, missing name.
- `KinCryptLogoutAction` — Starts the shared logout flow. Variants: ready, confirming, logging out, failed.
- `KinCryptLogoutDialog` — Confirms account exit and routing to login. Variants: standard, busy.
- `KinCryptChoiceSetting` — Edits one small exclusive preference. Variants: segmented, radio rows, saving, disabled.
- `KinCryptContactOrderPreview` — Demonstrates combined sort and display order. Variants: first-name sort, last-name sort, first-name display, last-name display.
- `KinCryptSettingsLinkRow` — Pushes a secondary Settings destination. Variants: standard, unavailable, attention required.
