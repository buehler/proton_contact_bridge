# iPhone Boot Screen

Status: proposed compact-width design direction.

Route: `/boot`.

## Purpose

The boot screen is the first Flutter-rendered state after native launch. It remains visible only while the native application layer determines whether a usable authenticated session exists.

- Authenticated session: replace `/boot` with `/contacts`.
- No authenticated session: replace `/boot` with `/login`.
- Recoverable startup failure: remain on `/boot` and expose a retry action.
- Blocking startup failure: remain on `/boot` and expose a concise failure reason without claiming that contact data is available.

Use route replacement so `/boot` never remains in the user's back stack.

## Screen design

- Use a quiet full-screen `surface` background with no application navigation.
- Center the compact KinCrypt mark, wordmark, and the line "Your contacts stay yours."
- Place a restrained indeterminate activity indicator and session-state copy near the lower safe area.
- Default copy: "Checking secure session…"
- Optional later copy for a materially slow operation: "Unlocking secure storage…"
- Do not add a cancel action. The resolution has no useful partial destination.
- Show retry only after a recoverable failure. Do not reserve button chrome in the normal state.
- Preserve the native launch screen until Flutter can render this state without a blank frame.
- Do not impose an artificial minimum display duration. Suppress detailed progress copy for approximately the first `300 ms` if that avoids a visible flash during immediate routing.
- Honor reduced-motion settings. Replace looping movement with a static progress treatment when reduced motion is enabled.

## Sync-state exception

The shared synchronization indicator is intentionally absent on `/boot`.

Session resolution occurs before KinCrypt can establish the Proton contact synchronization state. Showing the normal sync indicator here would conflate authentication and data synchronization. The boot screen reports startup state only. Once routing completes, `/contacts` displays the standard synchronization indicator.

## Accessibility

- Announce the current startup state with a polite live region.
- Announce a startup failure once as an alert.
- Do not announce every progress animation cycle.
- Keep the retry target at least `44 × 44` logical pixels.
- Allow the error message to wrap under text scaling without moving the action below the safe area.

## New Flutter widget inventory

Previously identified contact-list and group-view widgets are reused and omitted from this list.

- `KinCryptBootScreen` — Composes startup identity and session-resolution states. Variants: checking, delayed status, recoverable error, blocking error.
- `KinCryptSessionGate` — Observes the native session result and replaces the route. Variants: checking, authenticated, unauthenticated, recoverable failure, blocking failure.
- `KinCryptAppMark` — Renders scalable KinCrypt identity. Variants: mark only, mark with wordmark, compact navigation mark.
- `KinCryptActivityIndicator` — Shows branded indeterminate activity without implying measurable progress. Variants: orbit, inline pulse, reduced motion.
- `KinCryptStartupError` — Presents startup failure and recovery action. Variants: recoverable with retry, blocking without retry.

`KinCryptSyncIndicator`, `KinCryptBottomNavigation`, and data-list components are not used on `/boot`.
