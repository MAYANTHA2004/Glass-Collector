# Waste Glass Collection App

A mobile app + backend system for a glass-recycling collector: loads today's
suppliers, computes the shortest visiting route (Haversine + Dijkstra),
guides the collector stop-by-stop with a barcode check-in gate, and produces
a final trip report that syncs to the backend.

This repo contains **two projects**:

```
glass-collector/
├── backend/         .NET 8 Web API + SQLite
└── flutter_app/      Flutter (Android) app
```

---

## Contents

1. [Backend setup](#1-backend---backendglasscollectorapi)
2. [Flutter app setup](#2-flutter-app---flutter_app)
3. [Running the APK on a real device](#3-running-the-apk-on-a-real-device)
4. [Offline-first behaviour](#4-offline-first-behaviour)
5. [Project structure reference](#5-project-structure-reference)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Backend — `backend/GlassCollector.Api`

### Prerequisites

- **.NET 8 SDK** — https://dotnet.microsoft.com/download/dotnet/8.0
  Download the **SDK** installer (not "Runtime") for your OS.

  **Windows:** after installing, **fully close and reopen your terminal**
  (a currently-open PowerShell/cmd window won't pick up the new PATH).
  Verify with:
  ```powershell
  dotnet --version
  ```
  If it still says "not recognized" after reopening the terminal, restart
  your machine — this refreshes environment variables system-wide.

### Run locally

```bash
cd backend/GlassCollector.Api
dotnet restore
dotnet run
```

### Inspecting the SQLite file directly (optional)

If you want to look inside the database without going through the API:

```bash
sqlite3 backend/GlassCollector.Api/glasscollector.db
sqlite> .tables
sqlite> SELECT * FROM Suppliers;
sqlite> .quit
```

(Requires the `sqlite3` CLI tool — separate from anything in this repo,
purely a debugging convenience.)

### API endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/trips/today` | Screen 1: get (or create) today's trip with optimised stop order |
| POST | `/api/trips/new` | Force a new trip/route (useful for repeated demo runs) |
| GET | `/api/trips/{tripId}/report` | Screen 3: trip report data |
| POST | `/api/collections/verify` | Screen 2: verify scanned barcode against the expected stop |
| POST | `/api/collections/submit` | Screen 2: confirm a collection, update status to Collected |
| POST | `/api/collections/sync` | Screen 3: final batch sync of all locally stored records |
| GET | `/api/suppliers` | List all seeded suppliers + their codes (for generating barcodes) |

### Database schema

- **Suppliers** — `Id`, `SupplierCode` (unique, barcode-encoded), `Name`,
  `Address`, `Latitude`, `Longitude`, `ExpectedClearKg`, `ExpectedColouredKg`,
  `IsActive`
- **Trips** — `Id`, `CreatedAtUtc`, `CompletedAtUtc`, start GPS,
  `TotalDistanceKm`
- **TripStops** — `Id`, `TripId`, `SupplierId`, `SequenceNumber`,
  `Status` (Pending/Next/Collected), `DistanceFromPreviousKm`,
  `CollectedClearKg`, `CollectedColouredKg`, `Condition`, `CollectedAtUtc`

---

## 2. Flutter app — `flutter_app/`

### Prerequisites

- **Flutter SDK** (3.3+) — https://docs.flutter.dev/get-started/install
- Android Studio (for an emulator) or a physical Android device with USB
  debugging enabled
- A second phone/tablet (or printed pages) to display barcodes for
  scanning during testing

### First-time setup

This repo ships only `lib/`, `pubspec.yaml`, and a hand-written
`android/app/src/main/AndroidManifest.xml` (camera + internet permissions
already added). Run `flutter create .` once to generate the rest of the
standard Android platform scaffold (Gradle files, launcher icons, etc.)
cleanly for your machine/Flutter version:

```bash
cd flutter_app
flutter create . --platforms=android --org com.glasscollector
```

This will **not** overwrite `lib/` or `pubspec.yaml`. It **will**
regenerate `android/app/src/main/AndroidManifest.xml` with default
(no-permission) content — re-apply this repo's version afterwards, e.g.:

```bash
git checkout -- android/app/src/main/AndroidManifest.xml
```

(If you're not using git, just re-copy the manifest from this repo back
into place manually.)

Then fetch dependencies:

```bash
flutter pub get
```
### Run in debug mode

```bash
flutter run
```

### Build the release APK

```bash
flutter build apk --release
```

Output: `flutter_app/build/app/outputs/flutter-apk/app-release.apk`

---

## 3. Running the APK on a real device

1. Build the release APK (section 2), with `api_config.dart` already
   pointing at hosted backend URL.
2. Get the APK onto the phone, either:
   - **USB + adb** (most reliable):
     ```bash
     adb install build/app/outputs/flutter-apk/app-release.apk
     ```
     (use `adb install -r ...` to reinstall over an existing install)
   - **Direct file transfer**: copy the `.apk` via USB, email, Drive, etc.,
     then tap it in the Files app to install.
3. The phone will warn about installing from outside the Play Store —
   allow it (Settings → Security, or inline on first install attempt).
4. Open the app. Screen 1 calls your hosted API directly over the phone's
   normal internet connection (mobile data or Wi-Fi) — no dependency on
   your dev machine or local network at all.

**This project is Android-only**

---

## 4. Offline-first behaviour

- Every confirmed collection is written to the device's local SQLite
  database (`lib/services/local_database.dart`) **before** any network
  call is attempted — the app works through the whole trip with no
  connectivity at all.
- A best-effort live push happens after each confirmation if a connection
  is available, but nothing in the flow depends on it succeeding.
- On Screen 3, "Sync to server" reads all **unsynced** local records and
  pushes them in a single batch call. Records are only marked `synced`
  locally once the backend confirms acceptance; a failed sync leaves data
  untouched and safely retryable.

---

## 5. Project structure reference

```
backend/GlassCollector.Api/
├── Controllers/
│   ├── TripsController.cs        # Screen 1 + Screen 3 endpoints
│   ├── CollectionsController.cs  # Screen 2 verify/submit + sync
│   └── SuppliersController.cs    # debug/listing endpoint
├── Models/                       # Supplier, Trip, TripStop, StopStatus
├── Dtos/Dtos.cs                  # all request/response shapes
├── Services/RouteOptimizer.cs    # Haversine + Dijkstra route logic
├── Data/
│   ├── GlassCollectorDbContext.cs
│   └── DbSeeder.cs               # 5 sample suppliers
├── Program.cs
└── appsettings.json

flutter_app/lib/
├── main.dart
├── models/
│   ├── trip_stop.dart
│   └── collection_record.dart
├── services/
│   ├── api_config.dart           # <- set your hosted backend URL here
│   ├── api_service.dart          # all HTTP calls
│   ├── local_database.dart       # offline-first sqflite storage
│   └── trip_session.dart         # shared state across the 3 screens
└── screens/
    ├── trip_sequence_screen.dart  # Screen 1
    ├── scan_collect_screen.dart   # Screen 2
    └── trip_report_screen.dart    # Screen 3
```

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `dotnet : term not recognized` (Windows) | SDK not installed, or terminal opened before install | Install the .NET 8 **SDK**, then fully close and reopen the terminal (or restart the machine) |
| App can't reach the backend on an emulator | Used `localhost` instead of `10.0.2.2` | Emulator can't see your machine's `localhost` directly — use `10.0.2.2:8080`, or point at your hosted URL instead |
| App can't reach the backend on a physical device (local dev) | Phone and PC on different networks, or used `localhost` | Use your PC's LAN IP with both devices on the same Wi-Fi, or just use the hosted URL |
| Old APK still hits the old backend URL after rebuilding | Stale install on the device | Reinstall with `adb install -r ...` instead of just relaunching |
| First request after idle takes 10–60s | Free-tier cold start (service spun down) | Hit the health check URL once before demoing/recording |
| Trying to install the `.apk` on an iPhone | APK is an Android-only format | Not supported — out of scope for this Android-only assignment |
