# iPhone Group View

Status: proposed compact-width design direction.

## Screen behavior

- The group list is grouped under alphabetic section headers.
- The screen has no search, group filter, or add action.
- The compact header shows the group count and shared synchronization indicator.
- Tapping a group pushes a group-detail route.
- The detail header contains the back action, group name, contact count, and shared synchronization indicator.
- Group detail reuses the existing contact-list primitives without search, group filters, or add action.
- Favorites remain first in the group detail without a Favorites section header. Remaining contacts are grouped alphabetically.
- Bottom navigation remains visible with Groups selected.
- Tapping the synchronization indicator opens the shared synchronization status sheet.

## New Flutter widget inventory

Previously identified contact-list widgets are reused and omitted from this list.

- `KinCryptGroupListScreen` — Composes the grouped list route and reused phone shell. Variants: loading, loaded, empty, offline, error.
- `KinCryptGroupDetailScreen` — Shows one group as a contact-list route with group identity. Variants: loading, loaded, empty, offline, error.
- `KinCryptGroupList` — Renders group rows under alphabetic section headers. Variants: comfortable, compact, refreshing.
- `KinCryptGroupRow` — Displays a group name, contact count, and disclosure action. Variants: standard, pressed, unavailable.
- `KinCryptGroupHeader` — Provides list or detail identity while reusing sync state. Variants: list, detail with back, empty group.
- `KinCryptEmptyGroupState` — Explains that the selected group contains no contacts. Variants: empty, unavailable.
- `KinCryptSyncStatusSheet` — Expands the shared sync indicator into source and recovery details. Variants: synced, syncing, pending, offline, failed.
