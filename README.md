# RepLiT — Mobile

**Report Location and Incident In Time** — the resident and responder app for
the Fire Volunteer emergency-response system in Pasay City.

One codebase serves four roles, chosen after sign-in from `GET /auth/me`:

| Role | What they get |
|---|---|
| General user | Map, SOS, hotlines, guides, their own reports |
| Response team | Dashboard, incident list, dispatch acceptance, fire codes |
| Sub-admin (Fire Volunteer) | Verification, dispatch, incident command |
| Sub-admin (BFP) | Situational awareness, alarm-request review |

The UI follows the "General User App v2" design hand-off: a `#131313` ground
with translucent glass surfaces and hairline edges, a coral accent, and glow
reserved for the splash mark and the SOS button. Tokens live in
`lib/theme.dart`; the shapes every screen repeats live in
`lib/widgets/design.dart`.

---

## Setting up on a new machine

### 1. Install the toolchain

- **Flutter SDK** — https://docs.flutter.dev/get-started/install (this project
  is on Dart SDK `^3.11.1`)
- **Android Studio**, including the Android SDK and at least one emulator
- **Git**

Confirm the toolchain is healthy before going further:

```bash
flutter doctor
```

Every line under "Android toolchain" must be a checkmark. Ignore complaints
about Xcode unless you are building for iOS.

### 2. Clone the repository

```bash
git clone https://github.com/M2STZ-Crew/replit-android.git
cd replit-android
flutter pub get
```

### 3. Create `env.json`

The Mapbox token and the backend address are **not** in the repository — this
repo is public, and tokens committed to public repos get harvested. Copy the
example and fill it in:

```bash
cp env.example.json env.json
```

```json
{
  "MAPBOX_TOKEN": "pk.your_mapbox_public_token",
  "REPLIT_API_BASE": "http://10.0.2.2:8000",
  "OBSERVER_CONSOLE_URL": ""
}
```

- `MAPBOX_TOKEN` — from https://account.mapbox.com/access-tokens/. Ask a
  teammate for the project's token rather than making a new one, so usage
  stays on one account. Leave it blank and the maps fall back to
  OpenStreetMap; they still work, they just are not the designed style.
- `REPLIT_API_BASE` — where the FastAPI backend is:
  - **Android emulator:** `http://10.0.2.2:8000` (the emulator's alias for
    your machine's localhost)
  - **Physical phone:** `http://<your PC's LAN IP>:8000`, e.g.
    `http://192.168.1.20:8000`. The phone and PC must be on the same Wi-Fi,
    **and** that address must be listed in
    `android/app/src/main/res/xml/network_security_config.xml` — Android
    blocks cleartext HTTP to any address not named there.
  - **Deployed backend:** the `https://…` URL. No config file entry needed,
    because HTTPS is allowed by default.
- `OBSERVER_CONSOLE_URL` — optional. Police, Medical and Barangay team
  captains work from the Observer Console on the web (Master Context v10
  §2.6); when one signs in to the app it shows them this address with an
  **Open** button. Leave it blank and it tells them to ask their Admin.

`env.json` is gitignored. Never commit it.

### 4. Add the Firebase config

Push notifications need `android/app/google-services.json`, which is also
gitignored. Either get the file from a teammate, or register your own Android
app in the Firebase console with package name `com.m2stz.replit` and download
it. `android/app/google-services.example.json` shows the shape.

The app runs without it — `PushService` catches the absence and reports
`isAvailable == false`, leaving the in-app alert inbox working. Only push
notifications are lost.

### 5. Run

```bash
flutter run --dart-define-from-file=env.json
```

The flag is required for the token and API address to reach the app. Forget it
and you get OpenStreetMap tiles and `10.0.2.2:8000`.

To build an installable APK:

```bash
flutter build apk --release --dart-define-from-file=env.json
```

The file lands at `build/app/outputs/flutter-apk/app-release.apk`.

---

## Before running the app: start the backend

The app is useless without the API. In the backend repository
(`M2STZ-Crew/replit-backend`):

```bash
uv sync
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
```

`--host 0.0.0.0` matters — without it the server only accepts connections from
the machine itself, and a phone on the same Wi-Fi cannot reach it.

---

## Checks

```bash
flutter analyze          # must report no issues
flutter test             # 66 tests
```

The widget tests pump each redesigned screen at the design's 402×874 viewport
at both normal and 1.5× system font scale, and fail on any layout overflow.
That guard exists because three real overflows reached a handset before it did.

---

## Timing the report flow

Meeting 12 found the citizen flow too slow (about 20 seconds), and Master
Context v10 §6 sets no target until it is measured. Every report the app sends
logs one line saying where the time went:

```
[report-timing] origin=sos outcome=sent total=12.4s hold_complete=3.0s camera_ready=3.6s location_fix=5.2s photo_taken=6.9s send_pressed=9.8s upload_started=9.8s server_ack=12.4s
```

Each figure is seconds since the resident first touched SOS (`origin=map` for
the map's SOS button, `neighbour_alert` for a Report from a nearby-fire alert).
`upload_started − send_pressed` is time spent still waiting for GPS, and
`server_ack − upload_started` is the network plus the server. Only durations
are logged — no location or content.

With a phone plugged in:

```bash
adb logcat -s flutter | grep report-timing
```

The GPS fix now starts when the SOS hold begins rather than when the camera
opens, and the shutter no longer waits for it, so a cold fix overlaps the hold,
the photo and the agency choice instead of adding to them. If the fresh fix
times out indoors, the report falls back to the phone's last known position
(up to 10 minutes old) rather than failing; the accuracy is sent with it.

---

## Responder location sharing

Master Context v10 §6 has a dispatched responder's position reach command
every 5 seconds *while dispatched*. `lib/location/responder_tracker.dart` does
this for the whole app, not one screen: it starts when the responder has an
active dispatch (opening the incident, tapping the dispatch push, or the
dashboard noticing a dispatch a coordinator made), keeps going when they leave
the incident screen, and stops by itself once the server refuses a point
because the dispatch ended (fire out, withdrawn).

On Android it runs as a location foreground service, so it continues with the
screen off. The phone shows an ongoing "Sharing your location with command"
notification while it runs; that notification is required by Android and is
also how the responder knows. This needs the `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_LOCATION` and `WAKE_LOCK` permissions in the manifest. If
the phone refuses the service, sharing carries on while the app is open.

---

## Known gaps

These are deliberate and documented rather than hidden:

- **Release builds sign with the debug key.** `android/app/build.gradle.kts`
  still carries the Flutter template's TODO. A real keystore and
  `android/key.properties` are needed before distribution; both are gitignored.
- **SMS verification uses a trial gateway.** Philippine numbers may not receive
  the code. The phone-verification screen says so on screen rather than
  failing silently.
- **National ID review is manual.** The automated KYC provider has no credits,
  so `POST /verification/national-id/manual` routes submissions to an
  administrator in the web console.
