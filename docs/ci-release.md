# Building and sharing the app without a laptop

Every push to `main` builds the Android app on GitHub's servers and sends it to the
team through **Firebase App Distribution**. Teammates get an email and install from
their phones. Nobody's laptop is involved.

The workflow is `.github/workflows/android-release.yml`. This page is the one-time
setup it needs. Until every item below exists, runs stop at the first step and name
what is missing.

---

## What the workflow does

1. Checks every secret and variable below is set
2. Runs `flutter analyze` and `flutter test`. A failing test stops the release
3. Writes the signing key, `google-services.json` and `env.json` from secrets
4. Builds the APK with a build number that rises every run
5. **Refuses to distribute** unless the APK is signed with the team's key *and* has the
   Render address compiled in
6. Uploads it to Firebase App Distribution, which emails the tester group
7. Deletes the secret files from the build machine

The APK is **not** attached to the GitHub run. The repository is public, so an
attachment would let anyone install the app and send reports into the live system.

---

## One-time setup

Do these in order. Each takes a few minutes.

### 1. Create the tester group — Firebase

1. [console.firebase.google.com](https://console.firebase.google.com) → project **replit-pasay**
2. **Release & Monitor → App Distribution**. Click **Get started** if it asks
3. **Testers & Groups → Add group**. Name it, e.g. `M2STZ`
4. Note the group's **alias** shown next to its name, e.g. `m2stz`
5. Add each teammate's email to the group

### 2. Create a service account — Google Cloud

This is the identity the build uses to upload. It can only manage App Distribution.

1. [console.cloud.google.com](https://console.cloud.google.com) → select project **replit-pasay**
2. **IAM & Admin → Service Accounts → Create service account**
   - Name: `github-app-distribution`
3. Grant it the role **Firebase App Distribution Admin**. Nothing else
4. Open the new account → **Keys → Add key → Create new key → JSON**
5. A `.json` file downloads. **Treat it like a password**: never commit it, never send
   it in chat

### 3. Add the secrets — GitHub

`github.com/M2STZ-Crew/replit-android` → **Settings → Secrets and variables → Actions**.

Each command below, run in **PowerShell on the laptop that has the files**, copies a
value straight to the clipboard, so it never appears on screen or in a chat. Paste it
into **New repository secret**.

| Secret name | Copy it with |
|---|---|
| `DEBUG_KEYSTORE_BASE64` | `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\.android\debug.keystore")) \| Set-Clipboard` |
| `GOOGLE_SERVICES_JSON` | `Get-Content -Raw android\app\google-services.json \| Set-Clipboard` |
| `MAPBOX_TOKEN` | `(Get-Content -Raw env.json \| ConvertFrom-Json).MAPBOX_TOKEN \| Set-Clipboard` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | `Get-Content -Raw "$env:USERPROFILE\Downloads\<the-file-from-step-2>.json" \| Set-Clipboard` |

Run the middle two from the project folder. Use the **mobile-only** Mapbox token here,
not the URL-restricted one the websites use.

After adding `FIREBASE_SERVICE_ACCOUNT_JSON`, delete the downloaded `.json` file.

### 4. Add the variables — GitHub

Same page, **Variables** tab → **New repository variable**. These are not secret.

| Variable name | Value |
|---|---|
| `REPLIT_API_BASE` | `https://replit-backend-2li4.onrender.com` |
| `OBSERVER_CONSOLE_URL` | `https://replit-backend-gedk.vercel.app` |
| `FIREBASE_TESTER_GROUPS` | the alias from step 1, e.g. `m2stz` |

### 5. Run it

**Actions → Android release → Run workflow**. It takes about ten minutes. When it goes
green, the tester group gets an email.

---

## For teammates: installing

1. Open the Firebase App Distribution email on your phone and accept the invitation
2. Follow the link to download the build
3. Allow installing from this source when Android asks
4. New builds arrive the same way, and install over the old one

---

## Things that will bite

**The signing key must never change.** Builds are signed with one specific debug key.
Android refuses to update an installed app from a build signed with any other key, and
the workflow refuses to distribute one. Back up `%USERPROFILE%\.android\debug.keystore`
somewhere safe. GitHub secrets cannot be read back, so the secret is not a backup.

**Don't install laptop builds over these.** Every run gets a higher build number. A
laptop build is build number 1, so Android treats it as a downgrade and refuses it once
a newer build from this workflow is installed.

**Changing a URL needs a new build.** The backend address is compiled in. Update the
variable, then **Run workflow**.

**Before a real pilot**, replace the debug key with a proper release keystore. Everyone
reinstalls once, and then the app can also go to the Play Store.
