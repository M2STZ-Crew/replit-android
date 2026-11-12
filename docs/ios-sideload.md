# Building and installing the iPhone app without a Mac

GitHub's Macs build the iPhone app. It comes out **unsigned**: each iPhone user signs and
installs it from a **Windows PC** with **Sideloadly** and their own **free Apple ID**.
No MacBook, no paid Apple developer account.

The workflow is `.github/workflows/ios-unsigned-ipa.yml`. It runs on every push to
`main`, and from **Actions → iOS unsigned IPA → Run workflow**.

---

## What a free Apple ID allows — read this first

| Limit | What it means |
|---|---|
| **The app stops opening after 7 days** | Sideloadly re-signs it before then if auto-refresh is on (step 4). Otherwise sign it again by hand |
| **3 sideloaded apps per iPhone** | Counts every sideloaded app, not only Replit |
| **No push notifications** | Apple doesn't give free accounts the push permission, so nothing reaches the phone while Replit is closed |
| **Location only while Replit is on screen** | The iPhone build stops sharing a responder's location when Replit goes to the background or the phone locks. The Android app keeps sharing |
| **Each iPhone user signs their own copy** | With their own Apple ID, for their own iPhone |

A paid Apple Developer Program membership, $99 a year, is what removes these: no
weekly re-sign, push notifications, and TestFlight.

---

## One-time setup — GitHub

`github.com/M2STZ-Crew/replit-android` → **Settings → Secrets and variables → Actions**.

| Kind | Name | Value |
|---|---|---|
| secret | `MAPBOX_TOKEN` | Already set for the Android release |
| variable | `REPLIT_API_BASE` | Already set for the Android release |
| secret | `IPA_ZIP_PASSWORD` | **iOS only.** A random password, at least 12 characters |

The repository is public, so anyone signed in to GitHub can download a run's files.
The workflow therefore locks the app inside a 7-Zip archive with this password
(AES-256, file names hidden too), and refuses to run with a password under 12
characters.

To make one, run this in **PowerShell**. It copies a random 24-character password
straight to the clipboard, so it never appears on screen or in a chat:

```powershell
$b = New-Object byte[] 18; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); [Convert]::ToBase64String($b) | Set-Clipboard
```

Paste it into **New repository secret**, and keep it in the team's password manager:
GitHub secrets cannot be read back. Give it to iPhone users privately, never anywhere
public.

---

## What the workflow does

1. Checks the secrets and the variable above are set
2. Runs `flutter analyze` and `flutter test`. A failing test stops the build
3. Builds the app for iPhone, unsigned, with the Render address compiled in
4. **Refuses to hand it over** unless the Render address really is in the app and the
   camera and location permission messages are present. Without them iOS closes the
   app the moment it asks
5. Packs it as `Replit-<version>-<build>.ipa`, locks that in a `.7z` with the
   password, and checks the password opens it
6. Attaches the `.7z` to the run for 14 days

---

## For each iPhone user — Windows

### 1. Install the tools (once)

1. **iTunes and iCloud from apple.com**, not the Microsoft Store versions. Uninstall the
   Store versions first if you have them. [sideloadly.io](https://sideloadly.io) links
   the right downloads
2. **Sideloadly** from [sideloadly.io](https://sideloadly.io)
3. **7-Zip** from [7-zip.org](https://www.7-zip.org)

### 2. Get the app

1. Sign in to GitHub. Any free account can download
2. Open [Actions → iOS unsigned IPA](https://github.com/M2STZ-Crew/replit-android/actions/workflows/ios-unsigned-ipa.yml)
   and pick the newest run with a green tick
3. Under **Artifacts**, download `Replit-<version>-<build>.7z`
4. Right-click it → **7-Zip → Extract Here** (on Windows 11, **Show more options**
   first), and enter the password the team gave you. You now have
   `Replit-<version>-<build>.ipa`

No GitHub account? Someone on the team can send you the `.7z`. It is useless without
the password.

### 3. Sign and install

1. Plug the iPhone in by cable, unlock it, and tap **Trust** when it asks
2. Open Sideloadly. Your iPhone appears at the top
3. Drag the `.ipa` onto Sideloadly, type your Apple ID, and click **Start**. Enter the
   Apple ID password and the two-factor code when asked: Sideloadly signs in to Apple
   with them to make your free signing certificate. Many people use a spare Apple ID
   for this rather than their main one
4. On the iPhone: **Settings → General → VPN & Device Management** → your Apple ID →
   **Trust**
5. iOS 16 or later: **Settings → Privacy & Security → Developer Mode** → on. The phone
   restarts; tap **Turn On** when it asks again
6. Open Replit

### 4. Keep it working

- **Auto-refresh.** Sideloadly can re-sign Replit before the 7 days run out, from a
  background service on the PC. Turn it on for Replit in Sideloadly. The PC has to be
  on and able to reach the iPhone: by cable, or over Wi-Fi once **Sync with this
  iPhone over Wi-Fi** is ticked in iTunes
- **Without auto-refresh**, repeat step 3 before the week is up
- **A new build** installs the same way, over the old one, and keeps what the app had
  saved — as long as it has the same bundle ID as before

---

## Things that will bite

**"The App ID is not available".** A bundle ID can belong to only one Apple account,
and another user's free account most likely registered `com.m2stz.replit` first. In
Sideloadly open **Advanced options**, set a custom **Bundle ID** such as
`com.m2stz.replit.yourname`, and use that same one every time. A different ID
installs as a second, empty copy of the app.

**Sideloadly doesn't see the iPhone.** iTunes is the Microsoft Store version, or the
phone wasn't unlocked and trusted. Reinstall iTunes from apple.com, plug in again, and
tap **Trust**.

**"Maximum number of apps".** A free Apple ID can have 3 sideloaded apps on a phone.
Delete one you don't need.

**The app closes straight away a week later.** The signature expired. Re-sign it
(step 3), or turn on auto-refresh.

**Sign-in never finishes.** Check the backend is up. If the address itself is wrong,
fix the `REPLIT_API_BASE` variable, then **Run workflow** and install the new build:
the address is compiled in.
