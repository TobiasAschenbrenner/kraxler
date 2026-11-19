# iOS application

The Kraxler iPhone application is built with Swift and SwiftUI.

## Requirements

- Xcode 27 or later
- iOS 26.0 or later

## Open the project

Open `Kraxler/Kraxler.xcodeproj` in Xcode. The project includes:

- `Kraxler` — application target
- `KraxlerTests` — Swift Testing unit-test target
- `KraxlerUITests` — XCTest UI-test target

The bundle identifier is `com.tobiasaschenbrenner.kraxler`. Automatic signing
is enabled, but a development team is not required when running in the iOS
Simulator. A personal or paid Apple developer team can be selected when the app
is installed on a physical iPhone. Sign in with Apple additionally requires the
corresponding capability and an active Apple Developer Program membership.

The initial target is iPhone only. Location access is configured for showing the
user's position and nearby climbing areas on the map.

