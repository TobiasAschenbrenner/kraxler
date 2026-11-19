# Kraxler 🧗

Kraxler is a native, offline-first climbing guide for iPhone. It helps climbers
discover nearby climbing areas and routes, navigate with their current location,
save future projects, track completed climbs, and download selected areas for use
with poor or no reception.

---

## ✨ Features

- Explore climbing areas on an interactive Mapbox map
- Show the user's location and heading, with automatic initial centering
- Search globally for climbing areas and routes
- Filter routes by grade, discipline, climbing style, length, and pitch count
- View route grades, styles, descriptions, and locations
- Save routes to a personal library and mark completed climbs as ticked
- Download climbing data and map tiles for offline use
- Manage downloaded areas from the profile
- Register and sign in with email and password or Google
- Restore the authenticated session after restarting the app
- Follow the system appearance or select light and dark mode manually

---

## 🛠 Tech Stack

### iOS

- Swift and SwiftUI
- Mapbox Maps SDK and Core Location
- SwiftData for downloaded climbing data
- Firebase Authentication
- AuthenticationServices and Google Sign-In
- Swift Testing and XCTest

### Backend

- Node.js, Express, and TypeScript
- MongoDB Atlas and Mongoose
- Firebase Admin for ID-token verification
- Zod, Helmet, and Pino
- Vitest, Supertest, and MongoDB Memory Server

### Development

- Postman for manual API testing
- ESLint and the TypeScript compiler
- Git and GitHub

---

## 📁 Project Structure

```text
kraxler/
├── ios/
│   └── Kraxler/
│       ├── Kraxler/          # SwiftUI app, domain models, services and features
│       ├── KraxlerTests/     # Unit and integration tests using Swift Testing
│       └── KraxlerUITests/   # End-to-end UI tests using XCTest
├── backend/
│   ├── src/                  # Express API, MongoDB models and seed data
│   └── test/                 # API integration tests
├── postman/                  # Postman API collection
└── docs/                     # Supporting project documentation
```

---

## 🧩 Application Architecture

The SwiftUI application reads climbing content through a repository that combines
the Express API with a local SwiftData store. Mapbox provides the interactive map
and offline tile regions. Firebase authenticates users on iOS, while the backend
verifies their ID tokens before reading or changing personal route data.

---

## 🗂️ Data Model

MongoDB stores hierarchical climbing areas, routes, and user-specific route state.
Areas reference an optional parent area, allowing regions, climbing areas, and
sectors to share one collection. Routes reference their sector or climbing area,
while personal-route documents connect a Firebase user to saved and ticked routes.
GeoJSON points and `2dsphere` indexes support location-based queries.

---

## 🚀 Getting Started

### Prerequisites

- macOS with Xcode 27 or later
- An iOS 26 or newer Simulator
- Node.js 22 or later and npm
- MongoDB, locally or through MongoDB Atlas
- A Firebase project with an iOS app and Authentication enabled
- A Mapbox account and public access token

Clone the repository and install the backend dependencies:

```bash
git clone https://github.com/TobiasAschenbrenner/kraxler.git
cd kraxler/backend
npm ci
```

### Backend configuration

Create the local environment file:

```bash
cp .env.example .env
```

Configure these values in `backend/.env`:

```bash
NODE_ENV=development
PORT=3000
MONGODB_URI=your_mongodb_connection_string
FIREBASE_PROJECT_ID=your_firebase_project_id
```

Authenticated API routes use Firebase Admin Application Default Credentials.
Configure them locally with either `gcloud auth application-default login` or a
private service-account file referenced by `GOOGLE_APPLICATION_CREDENTIALS`.
Never commit the service-account file.

Load the development dataset and start the API:

```bash
npm run seed
npm run dev
```

The API runs at [http://localhost:3000](http://localhost:3000). `GET /health`
reports process health and `GET /ready` additionally checks the database connection.

### iOS configuration

Create `ios/Kraxler/Config/MapboxSecrets.xcconfig` and add your public Mapbox token:

```text
MAPBOX_ACCESS_TOKEN = your_public_mapbox_access_token
```

The file is ignored by Git. Add the Firebase `GoogleService-Info.plist` for the
bundle identifier `com.tobiasaschenbrenner.kraxler` if you are connecting a
different Firebase project.

Open the Xcode project:

```bash
open ios/Kraxler/Kraxler.xcodeproj
```

Select the **Kraxler** scheme and an iOS Simulator, then press **⌘R**. The local
development build connects to `http://localhost:3000`, so the backend must be
running before loading online climbing content.

---

## 📊 Development Data

The seed script creates a compact demonstration dataset for Fontainebleau and the
Frankenjura. It contains a region, climbing area, and sector hierarchy together
with bouldering and sport routes using Fontainebleau and UIAA grades. Seeding uses
upserts, so it can be run repeatedly without duplicating the included records.

---

## 🧪 Tests and Quality Checks

Run the backend checks from `backend/`:

```bash
npm run lint
npm run build
npm test
```

The backend test suite uses isolated in-memory MongoDB instances and does not modify
the configured development database.

Run the iOS unit and UI tests in Xcode with **Product → Test** or from the repository
root:

```bash
xcodebuild test \
  -project ios/Kraxler/Kraxler.xcodeproj \
  -scheme Kraxler \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

The iOS tests cover authentication state, networking, filtering, personal routes,
offline persistence, download management, map loading, navigation, and sign-out.

---

## 🔐 Security Considerations

- Firebase handles user credentials and persistent authentication sessions.
- The iOS app sends short-lived Firebase ID tokens to protected API routes.
- The backend verifies every protected request with Firebase Admin.
- Request validation, security headers, body-size limits, and centralized errors
  reduce the API's exposed surface.
- Mapbox access configuration, environment variables, and service-account
  credentials are kept outside version control.

---

## 🚧 Project Status

Kraxler is an active ten-week solo capstone project. The current prototype runs in
the iOS Simulator with the local API. Backend hosting, physical-device testing, and
TestFlight distribution are the next deployment milestones. Sign in with Apple is
implemented in the app, but its capability and Firebase provider remain disabled
until the Apple Developer Program enrollment is approved.

---

## 🎓 Project Context

The project brings together native mobile development, API design, NoSQL data
modelling, geospatial queries, authentication, offline storage, automated testing,
clean-code practices, and application security. It is also used as practical work
for the Mobile App Development module.

---

## 🤖 Use of AI Tools

AI tools supported architecture discussions, implementation, debugging, testing,
and documentation. The author reviews the resulting code and remains responsible
for understanding, validating, and explaining the submitted work.

