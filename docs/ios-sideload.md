# Installing the iPhone app without a Mac

GitHub's Macs build the app; each tester signs and installs it from a **Windows**
PC with their own **free Apple ID**. No MacBook, no paid developer account.

The workflow is `.github/workflows/ios-unsigned-ipa.yml`. It runs on every push to
`main` and from **Actions → iOS unsigned IPA → Run workflow**.

---

## What a free Apple ID gets you — read this first

| Limit | What it means |
|---|---|
| **Expires after 7 days** | The app stops opening. Re-sign it (step 3 again) every week |
| **3 sideloaded apps per device** | Counts every sideloaded app, not only Replit |
| **No push notifications** | Apple doesn't give free accounts the push entitlement. Replit runs without it |
| **One device per signing** | Each tester signs with their own Apple ID for their own iPhone |

For real distribution (TestFlight, no weekly re-sign, push) the team needs the paid
Apple Developer Program, $99/year.

---

## One-time setup — GitHub

`github.com/M2STZ-Crew/replit-android` → **Settings → Secrets and variables → Actions**.

| Kind | Name | Value |
|---|---|---|
| secret | `MAPBOX_TOKEN` | already set for Android |
| variable | `REPLIT_API_BASE` | already set for Android |
| secret | `IPA_ZIP_PASSWORD` | **new** — a long random password. Share it with testers privately, never in the repo |

The repository is public, so anyone signed in to GitHub can download a run's files.
The workflow therefore puts the app inside a password-protected 7z.

---

## For each tester — Windows

### 1. Install the tools (once)

1. **iTunes** and **iCloud** from apple.com — *not* the Microsoft Store versions.
   Sideloadly needs Apple's own drivers
2. **Sideloadly** from sideloadly.io
3. **7-Zip** from 7-zip.org

### 2. Get the app

1. GitHub → **Actions → iOS unsigned IPA** → newest green run
2. Under **Artifacts**, download `Replit-ios-<number>`
3. Extract it, then open the `.7z` inside with 7-Zip and enter the password.
   You now have `Replit-<number>.ipa`

### 3. Sign and install

1. Plug the iPhone in by cable and tap **Trust** on the phone
2. Open Sideloadly. Your iPhone appears at the top
3. Drag the `.ipa` in, type your Apple ID, click **Start**. Enter the password and
   the 2-factor code when asked. Sideloadly sends them only to Apple
4. On the iPhone: **Settings → General → VPN & Device Management** → your Apple ID
   → **Trust**
5. iOS 16 or later: **Settings → Privacy & Security → Developer Mode** → on, restart

To update or renew after 7 days, repeat step 3 with the newest `.ipa`. Data in the
app is kept.

---

## When it goes wrong

- **Sideloadly doesn't see the phone** — iTunes is the Microsoft Store version, or
  the phone wasn't trusted. Reinstall iTunes from apple.com
- **"Maximum number of apps"** — delete another sideloaded app; the limit is 3
- **App opens then closes after a week** — the signature expired. Re-sign it
- **Login spins forever** — `REPLIT_API_BASE` is wrong; the build already refuses to
  finish without the address compiled in, so check the variable's value
