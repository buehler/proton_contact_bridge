# Flutter Proton Contact Bridge

This is a flutter application for Proton (proton.me) contacts. It resembles a simple but easy to use
application that centers around contacts for a phone / tablet instead of strong focus on email only.

Its overall features are:
- Contact list that shows all possible contacts and favorites ordered on top
- Contact detail with more detailed information about a contact
- Group list / detail that shows a list of groups (collected via VCARD Categories field) and the detail shows
  the contained contacts
- Settings to change settings about the app and access to the app logs.
- Two way data sync to proton and back. Data locally stored within sqlite database.

The repository is structured as follows:
- The main app contains only the UI code
- In general, riverpod providers with code generations are used for state and invalidation of state
- The design system and design spec is documented in ./design and ./design/screens.
- Currently, the app focuses on iphone and phone formfactor. android and tablet are planned for later.
- The "proton_go_api_bridge" contains the native code that is built for the app.
- The native code contains all the proton logic (communication with the api and auth and storage) as well
  as the synchronization logic.
- It uses GORM in the native code to use SQLite directly on the device, but the initial database initialization
  is done from the app (because database pathes may vary).
- The communication between the native code is done via one general C ABI and utilizes protobuf as its protocol.
  This allows the C ABI to change / advance without a lot of memory management. The user of the library uses
  convenience functions inside the dart part of the native lib which manages memory.

## Code style and dev guide

If not explicitly requested in a prompt/session, this project does not need the addition of tests. So, no UI/magic
tests shall be generated with the exception if specifically requested for a certain feature.
This also accounts for general analysis. Checking if the code works shall be done via static analysis as well as
`flutter analyze` and `go build`. Along with "no tests": don't run the app to do some verification.
Instruct the user how to verify the functionality manually. You are only allowed to run flutter analyze and
go build as well as other static analytics tools and formatting tools.

Regarding style: keep the code lean. Compositions in the UI are currently kept where they are needed if they are
only used in one particular screen. If there is a composition that is used in multiple screens, they shall be flagged
and then the engineer may decide to extract them. But there must be no automatic creation of a lot of compositions and
one time components. The base components (UI atoms) are in the UI/components folder and if a prompt suggests
creating a new one it may be done. However, an engineer needs to acknowledge this.

In general the values of the theme shall be used. If there is something missing for a particular use-case, flag it
and an engineer may decline or acknowledge the request.
