# Releasing RepLiT on Google Play

Since v1.12.44 every release builds two copies of the app:

| | APK page copy | Google Play copy |
| --- | --- | --- |
| Where people get it | reportwhatslit-apk.vercel.app, Firebase App Distribution | Google Play |
| Signed with | the team's debug key (as before) | the Play upload key, then Play's own key |
| Updates | its own updater and the "New Update!" push | Google Play; "Check for updates" opens the Play Store page |
| Developer options on | blocked (Exit, or call 911) | a warning with **Continue anyway** (Google's test phones have them on) |
| Asks to install apps | yes | no |

The Play copy is built with
`flutter build appbundle --android-project-arg=playStore=true --dart-define=PLAY_STORE=true`
(see `.github/workflows/android-release.yml` and `android/app/build.gradle.kts`).
It registers with the server as `"1.12.44 play"`, and the server never sends it
the GitHub "New Update!" push (backend v1.12.34).

## 1. The upload key (once)

Make it on a laptop with Android Studio's `keytool`, and keep the file and its
passwords in a password manager. Never put them in the repository.

```bash
"/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe" -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000
```

```bash
base64 -w0 upload.jks > upload.jks.b64
```

In GitHub: **Settings → Secrets and variables → Actions → New repository secret**:

- `UPLOAD_KEYSTORE_BASE64`: the contents of `upload.jks.b64`
- `UPLOAD_KEYSTORE_PASSWORD`: the keystore password
- `UPLOAD_KEY_ALIAS`: `upload`
- `UPLOAD_KEY_PASSWORD`: the key password

Then delete `upload.jks.b64`. Until these secrets are set, the release still
builds and publishes the APK; it only skips the Play bundle, with a notice.

## 2. Getting the bundle

Push to `main` (or **Actions → Android release → Run workflow**). When the run
finishes, open it and download the artifact **RepLiT-play-<run number>**: it
holds `app-release.aab`, the file Play Console takes.

## 3. Play Console (once)

- **Create the app**: name, default language, App, Free.
- **App signing**: keep Play App Signing (the default) and upload the `.aab`.
- **Privacy policy**: `https://reportwhatslit-app.vercel.app/privacy` (the
  residents' site, not the console).
- **Account deletion**: in the app, Profile → Delete my account; on the web,
  `https://reportwhatslit-app.vercel.app/delete-account`. The account is
  frozen for 30 days (restorable), then deleted; say so in the Data safety
  form's deletion answers.
- **App access**: give the reviewers a citizen test account made for them (not
  a staff account), and say that administrators use the web console only.
  Since v1.12.65 the Play copy opens residents only (coordinators and
  responders are refused there, as Admins are), so that account gives full
  access. Leave Google's automated device testing with it off: a test robot
  could send a real report.
- **Ads**: none. **Target audience**: 18 and over. **Content rating**: answer
  the questionnaire (emergency reporting, no user-to-user chat).
- **Data safety**: location (precise, optional; never in the background: no copy
  asks for "All the time" since v1.12.66), name,
  email, phone number, date of birth and gender (optional), photos (reports, and
  National ID photos deleted after review), app interactions (answers to
  alerts), device identifiers (the notification token). Shared with service
  providers only; encrypted in transit; people can ask for deletion.
- **Sensitive permissions**:
  - *Background location*: in neither copy since v1.12.66; a fire's alert
    checks where the resident is when they open it instead. Adding it back
    would need a declaration and a short video of the feature, its
    explanation and Android's "Allow all the time".
  - *Foreground service (location)*: not in the Play copy since v1.12.65
    (`foregroundLocationPermission`); only a dispatched responder's tracking
    used it, and Play's copy has no responders.
- **Government features**: RepLiT is a community reporting app for Barangay 76
  Zone 10. If the listing names BFP or PNP, be ready to show their
  authorization, or describe them as partner responders without their logos.

### New personal developer accounts

A personal account made after 13 November 2023 must run a **closed test with
at least 12 testers, opted in for 14 days in a row**, before it can apply for
production. Start it as soon as the first bundle is uploaded. An organization
account (with a D-U-N-S number) does not need this.

## 4. Each release

1. Raise `version:` in `pubspec.yaml`, merge to `main`.
2. Download the new `RepLiT-play-<n>` artifact and upload it to the track
   (closed testing, then production). Play reviews it, from hours to days.
3. Play tells Play users of the update; the server does not.

## Moving people from the APK to Google Play

The Play copy is signed with a different key, so Android will not install it
over the APK copy. Uninstall the APK copy first, install from Play, and sign in
again. Reports and accounts are on the server and are not lost.
