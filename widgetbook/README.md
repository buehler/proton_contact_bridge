# Widgetbook page previews

The catalog uses the application page compositions and shells. Logs and standalone components are excluded.

## Setup

From this directory:

```sh
flutter pub get
dart run build_runner build
flutter analyze
flutter run -d macos
```

Regenerate the application providers from the repository root after changing their declarations:

```sh
dart run build_runner build
```

Generated Dart files follow the repository's existing ignore policy. The registry must be generated before running Widgetbook from a fresh checkout.

## Preview data

Each use case has its own disposable in-memory contacts, groups, preferences, and authentication state. Queries and notifier actions use Riverpod overrides. API construction and native database-path access are blocked; contact-provider sync/reset are no-ops. Pull-to-refresh refreshes the local fixture queries.

Changing a use case or its data knobs resets its local session. Changing the global theme or viewport preserves the current edits and navigation. Loading scenarios stay loading; error scenarios remain failed, including after Retry. Automatic provider retries are disabled for deterministic previews.

Human verification includes Verification required (press Start verification), Preview website (opens automatically), and Unavailable URL (disabled). Both active previews load Google in the real WebView through a Widgetbook-only URL override; production still accepts only HTTPS verify.proton.me addresses. The website requires network access, while authentication, API, and database isolation remain in place. Successful authentication submissions navigate to the local contacts page; rejected submissions display the real page's error UI.

Global addons select Light/Dark and phone/tablet viewports. None uses the available workbench size. Viewports simulate dimensions, safe areas, and layout breakpoints; they do not emulate native device capabilities or change `dart:io Platform`.

Camera, gallery, clipboard, and external links retain the application's platform behavior. Phone formatting uses the application's fallback when its native formatter has not been initialized. Fixture photos use embedded data and require no network access.

## Manual verification

- Open each page and its populated, empty, loading, error, minimal, or unsupported variants. Confirm Logs has no catalog entry; the Settings Logs row displays an informational message.
- Switch Light/Dark and every viewport, including None. Check phone bottom navigation, tablet side navigation, safe areas, scrolling, and dialogs. Confirm unsaved editor text and saved local edits survive addon changes.
- Search contacts by name, email, and phone; clear the search. Change sort/display knobs and verify favorites, alphabetical grouping, and names.
- Open a contact, toggle its favorite, edit/save it, create another contact, and delete it. Confirm the local lists and groups reflect these changes.
- Select contacts and add groups. Rename a group, remove members, and delete a group. Check membership and counts; removing the final member removes the group.
- Change settings and theme locally. Confirm the global theme selection takes precedence when changed. Change account knobs and confirm the session resets.
- Submit credentials or a complete OTP with Reject submission on/off. Check rejection messages, successful local navigation, unsupported TOTP, and all human-verification variants. In Verification required, press Start verification and confirm Google loads; Preview website opens it automatically. Unavailable URL stays disabled.
- Switch to another use case and back. Confirm fixture data is restored and no preview changes appear in the application's persisted contacts or preferences.

Verification for this change is static analysis only; the app and Widgetbook are not launched automatically and no tests are added.
