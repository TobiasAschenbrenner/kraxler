# iOS application

The Kraxler iPhone application is built with Swift and SwiftUI.

## Requirements

- Xcode 27.1 or later
- iOS 18.0 or later

## Open the project

Open `Kraxler/Kraxler.xcodeproj` in Xcode. The project includes:

- `Kraxler` — application target
- `KraxlerTests` — Swift Testing unit-test target
- `KraxlerUITests` — XCTest UI-test target

The bundle identifier is `com.tobiasaschenbrenner.kraxler`. Automatic signing
is enabled, but a development team is not required when running in the iOS
Simulator. A personal or paid Apple developer team can be selected later when
the app is installed on a physical iPhone.

The initial target is iPhone only. Location access is configured for showing the
user's position and nearby climbing areas on the map.

