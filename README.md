# Kraxler 🧗

Kraxler is a native iPhone climbing guide. It helps climbers find areas and routes,
save projects, track completed climbs and download areas for offline use.

---

## ✨ Features

- Explore climbing areas on a map and center it on your location
- Search for climbing areas and routes
- Filter routes by grade, discipline, style, length and pitches
- View route details and locations
- Save projects and tick completed climbs in a library grouped by climbing area
- Download climbing data and maps for offline use, and manage downloads
- Register and sign in with email and password or Google, with persistent sessions
- Edit your name and profile picture, and choose system, light or dark appearance

---

## 🛠 Tech Stack

- **iOS:** Swift, SwiftUI, Mapbox Maps, Core Location and SwiftData
- **Backend:** Node.js, TypeScript, Express and MongoDB Atlas (Mongoose)
- **Authentication:** Firebase Authentication, Google Sign-In and Firebase Admin
- **Testing:** Swift Testing, XCTest, Vitest and Supertest
- **Deployment:** Hostinger, with automatic deployments from GitHub's `main` branch

---

## 🏗 Architecture

The SwiftUI app connects to an Express API hosted on Hostinger. MongoDB Atlas
stores climbing content and personal data. Firebase authenticates users, and the
API verifies their ID tokens before accessing profiles or saved and ticked routes.
SwiftData stores downloaded climbing content; Mapbox provides maps and offline tiles.

---

## 📁 Project Structure

```text
kraxler/
├── ios/Kraxler/             # iPhone app, Xcode project and tests
├── backend/                 # Express API, MongoDB models, seed script and tests
├── postman/                 # API request collection
└── docs/                    # Project documentation
```

---

## 🚀 Getting Started

### Prerequisites

- macOS with Xcode 27 or later and an iOS 26 or newer simulator or iPhone
- Node.js 22 or later and npm
- MongoDB, locally or through Atlas
- Firebase project with Email/Password and Google authentication enabled
- Mapbox account and public access token

---

## 🔧 Environment Variables

Create these local configuration files with your own values.
Both files are **ignored by Git**.

### `backend/.env`

```bash
PORT=3000
NODE_ENV=development

MONGODB_URI=your_mongodb_connection_string
FIREBASE_PROJECT_ID=your_firebase_project_id
```

### `ios/Kraxler/Config/MapboxSecrets.xcconfig`

```text
MAPBOX_ACCESS_TOKEN = your_public_mapbox_access_token
```

---

## ▶️ Running the Application

### Backend

```bash
git clone https://github.com/TobiasAschenbrenner/kraxler.git
cd kraxler/backend
npm ci
```

Create the configuration files above. For backend authentication, run
`gcloud auth application-default login` or set `GOOGLE_APPLICATION_CREDENTIALS`
to a private service-account file. Then start the API:

```bash
npm run seed
npm run dev
```

The local API runs at [http://localhost:3000](http://localhost:3000).

### iOS

For your own Firebase project, replace `GoogleService-Info.plist` and update the
Google Sign-In URL scheme in `ios/Kraxler/Kraxler/Info.plist`.

Open `ios/Kraxler/Kraxler.xcodeproj`, select the **Kraxler** scheme and a simulator,
then press **⌘R**. Select your development team when running on an iPhone.

The app uses the hosted API by default. For local simulator testing, change the
default `baseURL` in [APIClient.swift](ios/Kraxler/Kraxler/Core/Networking/APIClient.swift)
to `http://localhost:3000`.

---

## 🧪 Running Tests and Quality Checks

From `backend/`:

```bash
npm run lint
npm run build
npm test
```

Backend tests use isolated in-memory MongoDB instances. The iOS tests cover
authentication, networking, filtering, saved and ticked routes, offline storage
and navigation. Run them in Xcode with **Product → Test** (**⌘U**).

---

## 🗂️ Data Model

MongoDB stores areas, routes, personal route records and user profiles. Areas form
an optional region–climbing area–sector hierarchy. Routes reference an area;
personal records link Firebase user IDs to saved and ticked routes. GeoJSON points
and `2dsphere` indexes support map queries.

---

## 📊 Development Data

`npm run seed` adds six area records and five routes across Cuvier in Fontainebleau
and Röthelfels in the Frankenjura. It uses upserts, so repeated runs update the
included records without duplicating them.

---

## 🚧 Project Status

Kraxler is a prototype under active development. Physical-iPhone testing is still
pending. Sign in with Apple has app-side support but still needs its capability
and Firebase provider activated. Grade conversion between systems is planned.

---

## 🎓 Project Context

A solo university capstone project, also used for the Mobile App Development
module, covering native iOS development, API design, NoSQL modelling,
authentication, offline storage and automated testing.

---

## 🤖 Use of AI Tools

AI tools were used to support implementation, discuss architecture and refactoring
options, understand errors and reason about native iOS development, MongoDB data
modelling, authentication and offline storage. They also supported testing and
project documentation. All implementation decisions and final validations were
performed by the author.
