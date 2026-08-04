# WorkSmart

WorkSmart is a Flutter mobile app for employee attendance and workforce management. Employees check in and out using face recognition and location verification, manage leave requests, and track tasks, while the app guards against location spoofing and rooted/jailbroken devices.

## Features

- **Face recognition check-in** — on-device face detection and matching (Google ML Kit + TFLite) to verify attendance.
- **Geofenced attendance** — location-based check-in/out with fake-GPS and jailbreak/root detection.
- **Leave management** — submit and review sick leave and annual leave requests, view leave history and details.
- **Attendance tracking** — attendance calendar, stats, and detail views.
- **Tasks & requests** — task list/detail screens and general request workflows.
- **Workspace invites** — invite and manage workspace members.
- **Notifications** — local and push notifications via Firebase Cloud Messaging.
- **Profile & settings** — profile management, language (English/Khmer), dark mode, and app settings.
- **PDF export** — generate attendance/report documents.

## Tech Stack

- **Flutter** (Dart SDK ^3.9.2)
- **Firebase** — Core, Cloud Messaging
- **Google Maps & Geolocation** — `google_maps_flutter`, `geolocator`, `geocoding`
- **ML/Face detection** — `google_mlkit_face_detection`, `tflite_flutter`
- **Local storage** — `sqflite`, `shared_preferences`
- **Networking** — `dio`, `http`
- **Auth** — `google_sign_in`

## Project Structure

```
lib/
├── app/            # App entry widget, routing, theming
├── config/         # API configuration
├── core/           # Constants, strings, and shared utilities (database, device, face, notifications, cloudinary)
├── features/
│   └── user/       # Auth, attendance, leave, tasks, workspace, profile features
│       ├── auth/
│       ├── logic/         # State/business logic
│       ├── presentation/  # Screens/UI
│       ├── repository/    # Data access layer
│       └── service/       # API/service layer
└── shared/         # Shared widgets and models
```

## Getting Started

### Prerequisites

- Flutter SDK (^3.9.2)
- A configured `.env` file (see `.env.example`)
- Firebase project configured for Android/iOS (`google-services.json` / `GoogleService-Info.plist`)

### Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```
2. Copy the environment template and fill in your keys:
   ```bash
   cp .env.example .env
   ```
   Required variables:
   - `GOOGLE_MAPS_API_KEY`
3. Run the app:
   ```bash
   flutter run
   ```

## Building

```bash
flutter build apk      # Android
flutter build ios      # iOS
```
