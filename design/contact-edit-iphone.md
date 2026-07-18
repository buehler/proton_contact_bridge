# iPhone Contact Editor

Status: proposed compact-width design direction.

## Screen behavior

- Contact creation and editing use the same full-screen, pushed form route.
- The top bar keeps Cancel, route title, and Save visible while the form scrolls and the software keyboard is open.
- New-contact mode changes the title and omits deletion. Edit mode loads all stored values and retains deletion at the end of the form.
- Cancel and platform back navigation require confirmation when the draft contains changes.
- Save validates identity, prevents repeated submission, persists the contact, and returns to the contact detail route.
- The editor shows the shared Proton synchronization indicator for the last persisted version and reports local draft state separately. After persistence, the detail route continues synchronization feedback.

## Form structure

The vertical section order is:

1. Contact photos and local draft state.
2. Identity: display name, first name, last name, organization, and job title.
3. Multiple typed email addresses.
4. Multiple typed phone numbers.
5. Multiple structured addresses.
6. Birthday and anniversary using platform date pickers.
7. Ordered group selection with search and custom-group creation.
8. Additional fields: website, gender, role, and logo.
9. Multiple multiline notes.
10. Reused contact deletion action in edit mode only.

Empty repeatable sections retain a visible Add action without reserving empty entry chrome.

## Repeatable values and custom types

- Email, phone, address, note, role, website, photo, and logo entries support add, remove, and reorder.
- A compound repeatable entry uses a quiet boundary so its type, value, reorder handle, and remove action remain associated.
- Type inputs are editable text with suggestions. Suggestions accelerate common values but never constrain the result.
- Email suggestions: Home, Work, Main, Other.
- Phone suggestions: Mobile, Home, Work, Main, Other.
- Address suggestions: Home, Work, Other.
- Custom values such as Studio, Assistant, Emergency, Vacation home, or any other non-empty label remain valid and are preserved verbatim after trimming.
- On compact widths, the type occupies the entry header and the value uses the full remaining width. Do not compress type and value into narrow side-by-side text fields.

## Dates

- Birthday and anniversary are independent fields.
- Tapping either field opens the platform date picker.
- A selected date exposes a separate Clear action.
- Preserve incomplete or yearless contact dates supported by the data model. Do not silently invent a year.

## Validation and persistence

- A contact requires at least a display name, first name, last name, or organization.
- Keep field validation adjacent to the failing field and summarize identity failure near Save.
- Draft states: clean, unsaved, saving, and failed.
- The sync indicator explicitly describes the last saved version while local changes remain unsaved. It must not imply that the draft itself has synchronized.
- On successful persistence, route to detail and let the shared synchronization indicator communicate pending or completed Proton synchronization.

## New Flutter widget inventory

Previously identified widgets, including contact avatar, group chips, synchronization UI, and contact deletion components, are reused and omitted.

- `KinCryptContactEditScreen` — Composes create and edit forms. Variants: new, edit, loading, not found, save failure.
- `KinCryptEditorTopBar` — Keeps Cancel, route title, and Save visible. Variants: clean, dirty, saving, disabled.
- `KinCryptDraftStatus` — Separates local form state from Proton synchronization. Variants: clean, unsaved, saving, failed.
- `KinCryptContactPhotoEditor` — Manages ordered contact photos. Variants: empty, initials, photo, multiple, busy.
- `KinCryptFormSection` — Labels one form region with an optional Add action. Variants: static, repeatable, empty.
- `KinCryptLabeledField` — Provides a persistent-label input. Variants: text, email, phone, URL, multiline, invalid.
- `KinCryptRepeatableFieldList` — Adds, removes, and reorders compound entries. Variants: empty, single, multiple, busy.
- `KinCryptCustomTypeField` — Suggests common types while accepting arbitrary text. Variants: preset, custom, empty, suggestions open.
- `KinCryptTypedValueEditor` — Pairs custom type and value for email or phone. Variants: email, phone, invalid.
- `KinCryptAddressEditor` — Edits type, street, ZIP, city, region, and country. Variants: preset type, custom type, incomplete.
- `KinCryptDateField` — Opens a platform picker and clears a contact date. Variants: birthday, anniversary, empty, selected.
- `KinCryptGroupSelectorSheet` — Searches, creates, selects, and reorders groups. Variants: loading, loaded, custom, error.
- `KinCryptAdditionalFieldMenu` — Adds website, gender, role, or logo fields. Variants: full, gender already present.
- `KinCryptNoteEditor` — Edits one reorderable multiline note. Variants: empty, populated, long.
- `KinCryptReorderHandle` — Starts touch drag reordering. Variants: enabled, disabled, dragging.
- `KinCryptDiscardChangesDialog` — Protects dirty drafts on Cancel or back. Variants: edit contact, new contact.
