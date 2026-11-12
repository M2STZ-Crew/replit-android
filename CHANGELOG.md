# Changelog

Versions follow `MAJOR.MINOR.PATCH` and match the backend (`replit-backend`):
MINOR tracks the Master Context generation, so 1.12.x implements Master
Context v12. The build number after `+` is the CI run number.

---

## v1.12.36 — 12 November 2026 — A suspended organisation is told why

With backend v1.12.28, where the central hub suspends, revokes or deletes an
affiliate organisation. No new permission or dependency.

### Changes
- **Someone of a suspended or revoked organisation is told why** where their
  account would have loaded (the splash, and after signing in): "Your
  organization's RepLiT access is suspended. Ask the central hub (Barangay 76)
  why…", or that it has been removed from RepLiT, in English and Tagalog,
  rather than "Could not load your account".

### Tests
- `test/v1_12_36_test.dart`: both refusals in the app's words, and nothing
  else taken for them.

---

## v1.12.35 — 12 November 2026 — Every alert vibrates, iPhones ring while open, one phone

With backend v1.12.27, which names the new channels and refuses an older
sign-in: deploy it after this release reaches phones. Adds the VIBRATE
permission (a normal one, granted at install; nothing is asked).

### Changes

**Alerts**
- **Every alert vibrates** ("vibration when notifying, both Android and iOS,
  every stage and every notif"). With the app closed: new vibrating copies of
  the report-stage channels, "Report updates" and "Updates" (a channel's
  settings are fixed once a phone has made it); the old ones stay for a
  server that still names them. With the app open: every push vibrates too,
  in the alert channels' rhythm on Android, and twice on an iPhone.
- **iPhones ring for news while the app is open** ("to make sound work on iOS
  when the app is open"). The iPhone build has no Apple push, so the open app
  reads the inbox every 15 seconds and, for anything new, plays the sound the
  push would have (the report's stage, the agency's alarm, the fire near
  you), vibrates, and shows the banner. News that is already old when the app
  opens stays in the Alerts list. Android keeps getting these from Firebase.
- **One phone per account: the newest sign-in wins** ("single device only
  policy ... a warning and a button will lead to exit"). Signed in on another
  phone, this one shows "Opened on another phone" over every screen, with
  EXIT: it forgets the session here (without signing the newer phone out)
  and closes the app; an iPhone goes to the sign-in screen.

### Tests
- `test/v1_12_35_test.dart`: the vibration call, which sound each kind of
  news plays, the watcher ringing only for new news and once, the refusal
  telling the app once per sign-in, and the warning's Exit.

---

## v1.12.34 — 12 November 2026 — What's burning, staff reports, System theme, one loader

With backend v1.12.27 (fire type, 50 m / 100 m, 18+): deploy it first. No new
permission or dependency.

### Changes

**Field**
- **"What's burning?" on arrival** (PRD v14 §4.5.3; Figma C18 / R08b). Once
  a unit is on scene and nobody has said, the picker opens by itself for the
  Coordinator or Responder who went; until it is answered a red row on LIVE
  and on the Responder's run asks for it. Six types, with the subtypes of
  Structural (no Agricultural), Electrical and Vehicular. Answered, the row
  names it ("Structural — Residential"), and a tap corrects it.
- **Coordinators and Responders report a fire** (PRD v14 §4.6.3; Figma C23 /
  R20): a **REPORT A FIRE** button on the Queue and Duty headers opens the
  same camera and report residents use. The report says "You report as …,
  counted as fully trusted", and after sending they stay in their own app.
- **The navigation panel gets out of the way**: while driving to a fire it
  folds down 3 seconds after it opens, or as soon as the vehicle moves; a
  swipe or a tap brings it back.

**Everyone**
- **50 m incident, 100 m corroboration**: every place that said 300 m (what
  joins an Area) now says 50 m, and every 150 m (who is asked "Is there a fire
  near you?") now says 100 m, in English and Tagalog; the Area circles and the
  maps that frame them follow.
- **Theme: System, Light or Dark** (Figma 14T, with System added). System
  follows the phone's light or dark and changes with it; it is the default.
  Whoever chose Light or Dark before keeps it.
- **One loading look**: every skeleton placeholder is gone. A screen that is
  loading shows the splash's mark and coral loader with what is loading; part
  of a screen shows the loader alone.
- **The light theme follows the Figma's light mode** (pass 7 variables):
  ground #F6F5F3, white cards, the 3 : 1 control border #8A847E, the deep
  brown accent #8C4F38, and the light danger, success, warning, police,
  medical, water and map colours.
- **18 and over**: the date of birth calendar ends 18 years back, and the
  server's refusal reads "You must be 18 or older to use RepLiT."
- **Back to the app after confirming an email**: the page the link opens has
  an Open RepLiT button (`reportwhatslit://`), which brings the app forward.

### Tests
- `test/v1_12_34_test.dart`: fire types to and from the server, the red row,
  the staff button, the Theme picker, the panel folding (3 s, moving, not
  asked), 18+. `test/loading_test.dart` replaces the skeleton tests;
  `test/theme_choice_test.dart` covers System. Older tests follow the new
  radii and the Theme row.

---

## v1.12.33 — 9 November 2026 — The En route sound, and a Rejected one

With backend v1.12.25, which names the new channels: deploy it first. No new
permission or dependency.

### Changes

**Sounds**
- **En route plays the En route recording** (9 November: "the phase is en
  route but the notification sound is on scene"). Since the stage recordings
  came in on 28 October, `sound_on_route.mp3` was a copy of
  `sound_on_scene.mp3`, for everyone who reported; a test let it through as a
  known copy. Both copies of it (res/raw, which a closed app's channel plays,
  and assets/sounds, which the open app plays) now hold the En route recording.
- **Rejected has its own recording**, where a rejected report played the
  general "Report updates" one: a new channel, "Report rejected"
  (`citizen_rejected_v1`).
- **"Incident verified" moved to a new channel** (`citizen_verified_v2`).
  `sound_rejected` sorts before `sound_verified`, so on a phone whose channels
  predate v1.12.23 (held by resource number) the old channel would have played
  the rejected recording. The old channel is deleted.

### Tests
- `test/sound_files_test.dart`: no two stages share a recording, with no
  exception any more; the five stages; res/raw's new list.

---

## v1.12.32 — 8 November 2026 — The sign-in screen fits without scrolling

App only. No new permission or dependency.

### Changes

**UI**
- **The sign-in screen fits the screen** (8 November: "why the sign-in
  screen is scrollable?"). A fixed 120 above the title made the page a
  little taller than a phone with a wider system font, and more so with the
  affiliate line, so it scrolled. Now the room above the title gives way
  first (up to 104, so the title still sits 120 down on the design frame),
  and the page scrolls only when it cannot fit at all: the keyboard up, a very
  large font, a small phone. A few gaps are tighter (32 under the subtitle, 18
  above SIGN IN, 12 above the hotline note). With Roboto it fits a 393 × 780
  screen up to a 1.2 font scale; a 360 × 700 one still scrolls a little.
- `FootedScroll.topRoom` lays the content and footer out for real rather
  than from intrinsic heights, which a text held narrower than the page (the
  subtitle, 306 wide) reports for the wrong width.

### Tests
- `test/login_fit_test.dart`: the room above the title gives way before the
  page scrolls; with room to spare the title sits 120 down and the footer at
  the foot; a very large font scrolls and nothing overflows.

---

## v1.12.31 — 8 November 2026 — The update banner on the home screen, one look for every Profile, affiliates from sign-in

App only; no backend change. No new permission or dependency.

### Changes

**Logic**
- **"There's a new update!" on the home screen** (8 November: "why there's no
  banner in the home screen?"). It was a pop-up for ten seconds, after a look
  at most every six hours that counted a look which found nothing: a release
  out an hour after a look went unseen for hours, and a pop-up shown as the
  home screen was drawn was easy to miss. Now the app looks every time it
  opens and on coming back to the front, at most every 15 minutes (the
  release's `latest.json`, a small file, not GitHub's rate-limited API), and
  the banner stays at the top of the home screen until UPDATE or ×: the
  resident's map, the coordinator's Queue, the responder's Duty
  (`lib/updates/update_banner.dart`). × keeps it away until a newer release.
- **An iPhone is told too.** Nothing sideloaded can update itself, so its
  banner says "RepLiT 1.12.31 is out. Install it with Sideloadly, as before.",
  with only ×. Its build numbers count apart from Android's (8 to 52), so it
  compares versions.

**UI**
- **The resident's Profile looks like the coordinator's and the responder's**
  (8 November): every row has its icon plate, the same one where staff have
  the row too (a key for Change password, an eye for Light mode), on the
  shared `ListRow`, under the same section headers.
- **"Want to be an affiliate? REGISTER HERE"** under "New to the app? CREATE
  ACCOUNT" on the sign-in screen opens the Admin console's affiliation form
  (replit-backend-5u9u.vercel.app/register) in the browser, or says where it
  is when no browser opens. In Tagalog too.

### Tests
- `test/update_nudge_test.dart`, rewritten: a look every time the app opens
  and at most every 15 minutes on coming back; a release out after a look
  that found nothing shows 15 minutes on; the banner stays; × until a newer
  one; an iPhone is told to use Sideloadly. The banner on the map, the Queue
  and Duty, not on the other tabs; an iPhone's check compares versions. The
  affiliate link and its fallback; every Profile row's icon.

---

## v1.12.30 — 7 November 2026 — Burner email addresses are refused

With backend v1.12.23, which refuses them; deploy it first. On an older
backend nothing changes. No new permission or dependency.

### Changes

**UI**
- **Temporary email addresses can't be used** (Disposable Email Address
  detection, 7 November). Signing up, a new responder's email and a staff
  Profile's personal email all say "Temporary email addresses can't be used.
  Use an email that will last, like your Gmail.", in English or Tagalog, and
  nothing is made or sent. The server decides what is a burner address; the
  app says it in its own words wherever the answer comes back (`ApiClient`).
- An account made with such an address earlier keeps working, but its email
  link says "Your email is from a temporary email service, so it can't be
  confirmed."

### Tests
- Sign-up, the email link sheet, New responder and the staff Profile each
  refuse a mailinator.com address in the app's words.

---

## v1.12.29 — 7 November 2026 — First and last name, and the email confirmed in Gmail

With backend v1.12.22: deploy it first. This app works with v1.12.21 too, but
then a confirmed email can be un-confirmed by asking again, and an old link
shows an error in JSON. No new permission or dependency.

### Changes

**UI**
- **First name and last name** at sign-up (7 November), in place of one Full
  name field. Both are required, with the email; the account's name is the
  two together.
- **The mobile number is optional** while SMS is unavailable: "Mobile number
  (optional)", with "Checking it by SMS is coming soon." under it. A number
  given has to be a PH mobile and is kept as a contact number, unchecked; no
  code is texted.

**Logic**
- **The email is confirmed in Gmail, in place of a texted code** ("instead of
  OTP, they will confirm it via email in Gmail"). The moment the account
  exists a link is emailed, and a sheet over the form says where it went.
  OPEN GMAIL opens Gmail, or the phone's email app for another address. The
  sheet sees the link opened by itself: on coming back from Gmail, or within
  five seconds if it was opened on a computer. Then EMAIL CONFIRMED, +10%,
  and Continue. Send again after a minute; Later goes on into the app, and
  Profile > Verify beside the email opens the same sheet.

**Android**
- `MainActivity`: `openMailApp` on the `replit/device` channel starts Gmail, or
  the phone's email app, at the inbox. An iPhone opens Gmail's address, then
  Mail's.

### Tests
- `test/email_link_sheet_test.dart` (17): sending as it opens or on Send the
  link, Gmail or another email app, Send again after a minute, confirmed on
  coming back or while open, Later, no connection, the wait and the day's
  links, a large font, Tagalog.
- `test/phone_signup_test.dart`: first and last name required, the optional
  mobile number, and sign-up ending in the email link sheet. 704 tests in all.

---

## v1.12.28 — 7 November 2026 — Email first, change password, Tagalog for staff, the two-state splash

With backend v1.12.21, which has to be deployed first (its migration
`20261106090000_staff_personal_email.sql` before it), and with
`REQUIRE_CITIZEN_PHONE_VERIFICATION=false` on Render: this app asks residents
for no mobile number. No new permission or dependency.

### Changes

**Logic**
- **"There's a new update!"** (WHAT'S NEXT, 1.1). On Android the app looks for
  a newer release by itself, once past the splash and when it comes back to
  the front, at most every six hours, and says so in a banner like an alert's.
  UPDATE opens Check for updates; closing it keeps it away until a release
  newer than that one. iPhones are sideloaded and look for nothing.
- **Change password** (1.2) on Profile for residents and staff: the current
  password, the new one twice. Other phones and browsers are signed out; this
  one stays signed in.
- **Email first** (2.2). Signing in and signing up take an email; the mobile
  number shows greyed out, "Coming soon", on sign in, on sign up and in
  Verification, and sign up texts no code. One switch turns it back on
  (`PhoneNumbers.open`, `lib/models/phone_numbers.dart`).
- **The app follows the account's language** (1.3): a choice made in the Admin
  console or on another phone reaches this one at start and at sign-in. A
  choice made here that the account does not have yet stands, and is sent at
  the next sign-in.
- **Staff accounts** (the 6 November list). Making a responder asks for their
  own email instead of a mobile number, beside the sign-in address now made
  agency first (`jdelacruz.firres@replit.com`); the link to set the password
  goes there, so there is nothing to hand over. A staff Profile whose sign-in
  is at @replit.com has a Personal email row, where password links go.

**UI**
- **The splash in two states** (2.1), as the Figma's 01 Splash: the
  flame-and-pin mark alone in the middle of the screen, then the coral loader
  and "Connecting to RepLiT" at the foot. No wordmark, glow or footer. The
  phone's own launch screen hands over to it without a seam: the same image at
  the same size and place on Android (12+ and 11 and older) and on the iPhone,
  Android 13+ on the app's own ground, the mark decoded before the first frame,
  and Android's slide-and-fade exit off.
- **Opening the app signed in shows no skeleton**: the splash stays until the
  account is loaded, and answers a slow or failed load itself. The skeleton
  remains only right after signing in, under the new mark.
- **Staff screens in Tagalog** (1.3): every line on the coordinator and
  responder screens and the older staff screens, 749 lines of B1 Tagalog.
  Language, Light mode and Change password are on the staff Profile.
- **Light mode for coordinators and responders**, and the older staff screens
  follow it instead of keeping dark colours.
- **"200 M FROM YOU"** on the nearby alert reads over the title in the accent
  ink, as the Figma has it, on both grounds; it was dark on dark in light mode.
- **"Are you safe?"** on the nearby alert comes in Tagalog too.

### Verified

- `flutter analyze`; `flutter test` (682 passed).
- On the Pixel 6 emulator (Android 15, a debug build): the launch screen and
  the splash measured frame by frame, the mark the same size and place to a
  pixel, no dim frame at the hand-off, the dark ground on a phone in light mode
  from the second launch on.
- Not run: a release build on a phone, an iPhone, Android 11 or older, a
  password change or a staff account against the live server.

---

## v1.12.27 — 6 November 2026 — Open the installer again, a smaller logo, "New to the app?"

With backend v1.12.20; nothing new needed from it. No new setting, permission
or dependency.

### Changes

**Logic**
- **"Open the installer again"** on the update sheet. Closing Android's install
  dialog, or tapping Cancel, no longer means a second download: a finished
  download waits in the app's cache while it is the newest release, so the next
  "Check for updates" offers **Install** at once, and it is cleared once that
  version is installed. Downloads go to a `.part` file, renamed when whole.

**UI**
- **The flame-and-pin mark a fifth smaller, and sized from the screen**: 80×112
  on RepLiT's splash on a 402-wide phone (64×90 at 320, at most 100×140 on a
  tablet), the wordmark and glow in proportion. Android 12+'s own launch
  screen shows it about a fifth smaller too (an inset of the launcher mark).
- **The iPhone's launch screen** had no logo: Flutter's 1×1 placeholder on
  white, a white flash in Dark Mode. It now shows the mark at a fifth of the
  screen's width (at most 100 pt), on #EEEDEA, or #131313 in Dark Mode.
- **Sign-in:** "New to the app? CREATE ACCOUNT" (Tagalog "Bago ka sa app?
  GUMAWA NG ACCOUNT") in place of "New to the barangay app?".
- **Tagalog tour:** "Laktawan" (Skip) stays on one line; Back and Skip share
  the bar's two sides equally, so the progress stays centred. The first tour
  screen scrolls instead of overflowing on a small phone at a large text size.

---

## v1.12.26 — 6 November 2026 — The app opens again, updates for anyone, the Figma splash

With backend v1.12.20; nothing new needed from it. New permission:
`REQUEST_INSTALL_PACKAGES`, for "Check for updates". The Firebase App
Distribution SDK is gone; testers still get every build through App
Distribution. **The APK is public** from this version: every build is also a
GitHub release (docs/ci-release.md).

### Changes

**Found**
- **1.12.24 and 1.12.25 closed on every Android phone a few seconds after
  opening.** The App Distribution SDK added in 1.12.24 (16.0.0-beta21) depends
  on `firebase-common` 23.0.0, which Gradle chose over the 22.1.0 in
  FlutterFire's BoM (34.15.0). 23.0.0 no longer has
  `FirebaseOptions.getRecaptchaSiteKey()`, which `firebase_core` 4.11.0 calls
  as Firebase starts, so the app died with a `NoSuchMethodError` on a
  background thread. It was not the Developer options check. Builds made
  without `google-services.json` never start Firebase, which is why no local
  build showed it.

**Logic**
- **The App Distribution SDK is removed**, which puts `firebase-common` back
  on 22.1.0.
- **"Check for updates" works for anyone (Android).** Every main build is also
  published as a GitHub release (`android-v<version>-<build>`) with a
  `latest.json` beside the APK: version, build, size, SHA-256, notes. The app
  reads the newest one's `latest.json` (a plain download, not GitHub's
  rate-limited API), downloads the APK with progress, and Android checks the
  SHA-256 before opening its installer, which asks once to allow installs
  from RepLiT. No tester invitation, no email to the team. iPhones still have
  no button.

**UI**
- **The splash** is built from the Figma archive's LOGO section: the
  flame-and-pin mark at 100×140 with its glow, the "REPLIT" wordmark made for
  each ground (black on light, white on dark) instead of a tinted copy, and
  "Connecting to RepLiT".

---

## v1.12.25 — 5 November 2026 — Developer options: a warning, like GCash

With backend v1.12.20; nothing new needed from it. No new setting, permission
or dependency.

### Changes

**Logic**
- **Developer options open to a warning, not a block screen.** With Developer
  options on, a release build on Android opens with the app dimmed under a
  warning, the way GCash does it: what was found, a reference code (Ref 02 for
  Developer options, Ref 03 when USB debugging is on too), **Exit**, which
  closes RepLiT and takes it out of Recents, and "In an emergency, call 911".
  The app can't be used until they are off. Switching them off in Settings
  and coming back clears the warning in place.
- **USB debugging on its own doesn't count.** It lives inside Developer
  options, and the Android emulator reports it on with Developer options off;
  counting it would leave nothing to switch off.

Checked with a release build on an Android 15 emulator: off opens to sign-in;
on shows the warning (Ref 03); Exit closes the app; switching them off while
away clears the warning on the way back, and on again brings it back.

---

## v1.12.24 — 5 November 2026 — The 5 November issue list, on the phone

With backend v1.12.20, which must be deployed first (its two migrations and
`PUT /auth/me/language`). New permission: `ACCESS_BACKGROUND_LOCATION`, asked
for only from Profile. New dependencies: `image`, `workmanager`, and Firebase
App Distribution (Gradle). The iPhone build (`ios-unsigned-ipa`) now comes from
`main`.

### Changes

**UI**
- **Tagalog mode** at CEFR B1 for residents: a Language switch in onboarding and
  on Profile, 811 lines translated, alerts in the same language. Staff screens
  stay in English.
- **Email and mobile hidden** on Profile until the eye is tapped.
- **The splash and top-bar logo** show on the light ground; the Android launcher
  icon is the flame-and-pin mark again; iOS shows "RepLiT".
- **"Responders" and "Pasay City"** instead of "Barangay 76".
- **Skeleton loaders** instead of spinners on loading screens.
- **National ID photos** come back as framed in the box, shown in its shape.
- **Drawer handles** stay put while the rows scroll.
- **"Check for updates"** on Profile (Android), through App Distribution.

**Logic**
- **Fire is locked in** on every report.
- **Developer options must be off** for a release build to run on Android.
- **The 150 m alert finds people where they are**: the phone reports its
  location every 5 minutes while open, and about every 15 while closed for
  residents who allow "All the time".

**Before it works on phones:** the Firebase App Testers API enabled for the
project, for "Check for updates".

---

## v1.12.23 — 2 November 2026 — Incident sounds, and "Active areas near you"

With backend v1.12.19, which needs nothing from this build and changes no push.
No new setting, no new permission.

### Changes

**Found**
- **On Scene announces "On route".** `sound_on_scene.mp3` is a byte-for-byte copy
  of `sound_on_route.mp3`: one ElevenLabs file (its C2PA id appears in both),
  added as both on 28 October, in assets/sounds and in res/raw. No On Scene
  recording exists in the repository's history or on the build PC.
- **Reported was not silent.** Sending a report played `report_sent.wav`, which
  the same commit had replaced with a 1.7 s recording in the stage clips' voice.
  The server sends the reporter nothing at that stage; the sound was the app's.
- **A channel can play another channel's recording.** Each channel stored its
  sound as a resource number, and adding the four stage recordings renumbered
  res/raw (`aapt2 dump resources`, v1.12.17 against v1.12.22): 0x7f0d0005 was
  `sound_medical` and is now `sound_fire_out`; 0x7f0d0006 was `sound_police` and
  is now `sound_medical`. On a phone that had the app before v1.12.20, Medical
  alerts play "Fire out" and Police alerts the medical recording. Seen on an
  Android 15 emulator: upgraded in place from v1.12.17, "alert_medical" still
  points at 0x7f0d0005 (not heard: the emulator ran without audio).
- **"Area 50.4" and "Area 50.3" were real, but not near.** They are the only two
  Areas still active (one report each, open since 29 October). With no GPS fix
  yet, `_nearbyAreas()` listed the newest two Areas in the city under "Active
  areas near you", and the map asked for the fix only after the server
  answered. So every resident saw those two on signing in until the GPS
  replied, and for good with location off. A server error read as "Nothing
  active".

**Changed**
- **Sending a report plays nothing.** `report_sent.wav`, `playReportSent()` and
  both switches for it are gone (Profile's "Notification sounds", Notification
  settings' "Report sent sound"). This replaces PRD v14 §4.13.4's "salamat!" cue.
- **Channels made from now on name their recording**
  (`android.resource://com.m2stz.replit/raw/sound_fire`), which renumbering cannot
  move. Channel ids are unchanged. Checked on the emulator: a fresh install
  names all ten; an upgraded phone gets the four stage channels by name and
  keeps its older ones by number.
- **The areas sheet names an Area only once it has measured it.** While the
  server or the GPS has not answered: "Checking what is happening around you…"
  over a placeholder row. With location off or refused, it says so and how to
  fix it; when the server fails, it says that. Otherwise it shows Areas within
  1.5 km, nearest first, or "Nothing active within 1.5 km". The map still draws
  every Area. The first fix gives up after 20 s, as the SOS screen does.

**Tests**
- `test/sound_files_test.dart`: every sound is the same file in assets/sounds and
  res/raw; res/raw keeps its list (a new file renumbers the channels); no two
  stages share a recording, except the On Scene copy above, named.
- `test/map_screen_test.dart`: six new cases for the sheet: GPS pending, server
  pending, nothing near, location off, location refused, server error.

**Still to do**
- **The On Scene recording.** Replace both copies of `sound_on_scene.mp3` with it
  under the same name, and delete the exception in `test/sound_files_test.dart`.
  Keep the name: renaming or adding a file renumbers res/raw.
- **Phones that had the app before v1.12.20** keep the swapped Medical and Police
  sounds until the app is uninstalled and installed again.

---

## v1.12.22 — 31 October 2026 — The National ID camera from Figma

App-only, UI. The backend stays at v1.12.18.

### Changes

- **The National ID photos open the Figma camera** ("20 National ID · ID photo",
  460:4632, and "20B · Selfie", 464:1209) instead of the phone's own camera app:
  close button, title, step, guide frame, hint, 76 px shutter and the camera-only
  note. Figma has no QR frame, so that step is frame 20 with a square guide, and
  the steps read 1 to 3.
- The viewfinder is darkened around the guide, so the words stay readable over a
  live scene. The flash stays off, and the cached file is deleted after capture.
- The QR photo is taken at 4K, the other two at 1080p. `image_picker` is gone: this
  screen was its only user.

---

## v1.12.9 — 15 October 2026 — Turn-by-turn navigation to the fire

App-only. The backend stays at v1.12.6. Implements PRD v12 §4.9 (route
optimisation and navigation) on the existing `DirectionsScreen`.

### Changes

**Root causes found**
- **Routes ignored traffic and favoured main roads.** Navigation used the
  public OSRM demo server: free-flow speed tables (a main road always looks
  fastest), no traffic, only its first route, no turn steps. Tested on a
  Pasay trip: OSRM said 278 s; Mapbox with live traffic said 473 s.
- **The map jumped.** Android delivers a GPS fix every 5 s unless an interval
  is asked for, and the dot animated each fix in 200 ms, so at 40 km/h it
  jumped about 55 m every 5 s. Three separate GPS streams (dot, progress,
  tracker) also disagreed, and the map turned by compass, which swings
  inside a vehicle.
- **Rerouting was fragile.** Two fixes over 50 m off triggered it whatever
  the GPS accuracy was, then a fixed 30 s wait. Progress searched the whole
  route each fix and could jump backwards. Failures were silent, and requests
  were not sequenced.

**Added**
- **Routing from Mapbox Directions** (`lib/navigation/routing_service.dart`),
  using the public token the app already ships for its tiles.
  - Profile `driving-traffic`: live traffic in the times, up to three
    routes, turn steps with street names, and congestion per stretch.
  - `max_width=2.5`: roads tagged narrower than a fire truck are skipped,
    while residential streets stay in.
  - When moving, the request carries the truck's heading, so a new route
    starts the way it is already going.
  - OSRM is the fallback when Mapbox fails (no token, quota, network). Its
    routes are never labelled as traffic-aware.
  - Shelters use Mapbox `walking`.
  - Both providers share one parser (`nav_route.dart`), since their answers
    have the same shape.
- **Turn-by-turn.**
  - A banner shows the next maneuver: a drawn arrow, the distance ("250 m")
    and the instruction ("Turn left onto Taft Avenue"). A "Then …" line
    appears when a second turn follows within 100 m.
  - The time left, distance left and arrival clock count down. Times come
    from the provider's own per-step times, so they're traffic-aware with
    Mapbox.
- **Voice** (`flutter_tts`, the phone's own text-to-speech, offline).
  - Each maneuver is said once 300 m ahead (60 m on foot) and once at it,
    plus the first instruction and arrival.
  - It plays as navigation audio, so music ducks under it.
  - On/off toggle, remembered.
- **Alternatives.** Before Start, every route offered is on the map: the
  chosen one in blue, the others grey. A list shows time, distance and
  main road for each, with "Fastest" marked; tap one to take it.
  - Live traffic is drawn over the chosen route only: amber for slow, red
    for heavy, dark red for severe. Grey always means "another route",
    never traffic.
  - The card says "Times include live traffic." only when that's true.
    Otherwise it says "No live traffic data — times are estimates."
- **Smooth movement.**
  - While navigating, GPS is asked for a fix every second at best accuracy
    (`LivePosition` precise mode). The dot and camera glide across the
    whole second.
  - The dot sits low on the screen so the road ahead shows.
  - The dot is drawn on the road when the fix agrees with it (within its
    accuracy, at most 20 m). Otherwise it's drawn where the GPS says, so a
    real wrong turn is visible.
- **Hybrid rotation** (PRD §4.9.4). While moving, the road's direction
  turns the map; standing still, the compass does. The existing compass
  button forces north-up.
- **Re-centre.** Moving the map by hand stops the following, and a
  Re-centre button appears. It brings back the navigation view (latest
  position, navigation zoom, heading-up). The dot and route keep updating
  meanwhile.
- **Rerouting** (`NavigationController`).
  - Triggers when off by more than the larger of 35 m and 1.5× the fix's
    accuracy (capped at 80 m), on two usable fixes at least 3 s apart.
  - Fixes worse than 50 m are ignored, and the card says the GPS is weak.
  - One request at a time. A destination change or retry supersedes it,
    and a late answer for a superseded request is dropped.
  - After a failure, the last route stays and the card says so; retries back
    off 5–60 s. With no route at all, a dashed straight line is shown,
    labelled as one, while a real route is retried.
  - Progress searches near the last position, and the next maneuver never
    moves backward.
- **The destination follows the incident.** When opened from an incident,
  its centre is read again every 30 s; if more reports moved it by over
  30 m, the route follows.

**Modified**
- The incident screens' ETA labels (responder and coordinator) use the same
  routing service, with a one-minute / 50 m cache (`DriveTime`). They no
  longer call the OSRM demo every 6 s.

### Files Changed
- New: `lib/navigation/` (`nav_route.dart`, `routing_service.dart`,
  `instructions.dart`, `navigation_controller.dart`, `voice_guide.dart`),
  `lib/widgets/maneuver_arrow.dart`, `test/navigation_test.dart`.
- `lib/screens/directions_screen.dart` (the navigation UI on the
  controller), `lib/location/live_position.dart` (precise mode, full fixes),
  `lib/location/route_progress.dart` (search window),
  `lib/widgets/you_are_here.dart` (injectable streams, navigation view,
  smooth animation, hybrid heading).
- `lib/screens/responder/responder_incident_screen.dart`,
  `lib/screens/subadmin/subadmin_incident_command_screen.dart` (ETA via
  `DriveTime`; route opens with the incident id),
  `responder_incident_report_screen.dart`,
  `subadmin_incident_report_screen.dart` (incident id).
- `test/directions_live_test.dart` (rewritten for the new screen).
- `pubspec.yaml`: `flutter_tts`, version 1.12.9.

### Database Changes
None.

### API Changes
None to RepLiT's API. New outbound calls from the app to
`api.mapbox.com/directions/v5`, using the existing public `MAPBOX_TOKEN`.

### Testing
- Parser: routes, step positions in order, congestion, walking pace,
  multi-name roads, empty geometry dropped. Also checked against a live
  Mapbox answer for a Barangay 76 → Pasay City Hall trip: 2 routes, steps in
  order, a residential street (Padre Vergel) in the route.
- Instructions: turns, forks, end of road, roundabouts, departure,
  arrival, rounded distances.
- Routing service: Mapbox parameters (profile, alternatives, steps,
  `max_width`, bearings); fallback to OSRM, which never claims traffic;
  OSRM only without a token; walking; an error, never an invented route,
  when nobody answers.
- Controller: next maneuver and distance; no going back past a turn;
  fastest chosen and switching; reroute only after two usable fixes 3 s
  apart, from where they are and the way they head; poor GPS ignored; the
  dot drawn on the road only within accuracy; a late answer dropped; a
  failed reroute keeps the route, says so, backs off and retries; voice
  says each cue once and nothing before Start; a straight line, then a
  real route.
- Screen: countdown on foot and by road; the walked part fades; the
  off-route note; Start, Stop, compass; alternatives and switching;
  traffic and no-traffic notes; banner and voice counting down and
  advancing; Re-centre after a drag; destination follows the incident;
  arrival.
- Result: **all app tests pass**; `flutter analyze` clean.
- **Not field-tested.** Smoothness, GPS behaviour, rerouting thresholds and
  voice timing on a real phone in a moving vehicle still need a drive test.

### Known limits
- Traffic comes from Mapbox. Coverage in Pasay is partial: one probe route
  had live data and the other had none. When none exists, the app says
  so.
- `max_width` only skips roads whose width is tagged in OpenStreetMap.
  Untagged narrow alleys can still appear.
- Mapbox's free tier is 100,000 requests a month. Each route request or
  reroute is one, plus the cached ETA labels.
- PRD §4.9.2's record of the chosen route (`route_choices` table,
  `POST /routes/choose`) is not built. That needs a backend change.

---

## v1.12.8 — 15 October 2026 — The REPLIT (MAIN) pass 4 design, and a new launcher icon

App-only. The backend stays at v1.12.6. The full account — which Figma
screens are built, which wait for a feature, and why — is
`docs/figma-pass4.md`.

### Changes

**Modified — one visual system from the pass 4 Figma**
- **Icons.** Every icon is Material Symbols Rounded, filled (Fill 1,
  weight 400), from a 26 KB font cut down to the 108 icons the app draws
  (`assets/fonts/app_symbols.ttf`, `AppIcons`). check, close, add and the
  chevrons stay strokes. `tool/symbols/` rebuilds both from `icons.txt`.
- **Colours.** Text steps down from `#F3F3F3` to `#8A8A8A` and no further;
  card edges are the PRD hairline; fields, switches, secondary buttons and
  progress tracks get a 3 : 1 control edge; warning `#FFB020`, info
  `#5B93F5`, police text violet-300.
- **Status.** Status pills are tinted, 11 px and sentence case. An
  incident's status has the Lifecycle chip's tone: amber needs a decision or
  a record, blue verified, red under way, green out, grey off the feed.
  Staff screens use the PRD words ("En route", "Report pending" — it read
  "REPORT DUE").
- **Tab bar.** Filled glyphs, a pill with a coral edge on the selected tab,
  a white ring on the SOS disc on its own screen. A screen reader hears
  "Hotlines, tab 2 of 5" and can now activate a tab.
- **Lists fade at their edges** only where there is more to scroll to:
  Hotlines, Guides, Profile, My duty, the coordinator queue, the citizen
  report review, the Post-Incident Report.
- **Maps.** Markers are the design's rounded squares with white glyphs on
  darker category colours, a white edge and a dark plate, 48 px to tap and
  named for screen readers; a live Area pulses. Layer chips get a check when
  on. The places' panels follow the glass rules (stronger over the
  OpenStreetMap fallback, solid under high contrast). You are a coral dot.
- **Forms.** Labels are sentence case above each field; "Use email
  instead", "Forgot password?" and "Create account" are text links with
  44 px targets; hotline filters are 36 px chips with a check.
- **Motion.** Buttons give under a finger; sheets and dialogs open in
  280 ms and close in 200 ms over a darker scrim; the live pulse and every
  decorative fade stop when the phone asks for reduced motion.

**Modified — launcher icon**
- Pass 4 Treatment A: the orange flame and white pin on the dark ground with
  a soft coral glow, as adaptive vector layers taken from the Figma masters,
  a monochrome layer for Android 13+ themed icons, and legacy square and
  round icons for older launchers.

**Unchanged**
- Every request, permission, status transition and screen flow. Screens the
  design draws for features the app does not have yet (Didit, route choice,
  merge, staff profile and history) are listed in `docs/figma-pass4.md`, not
  built.

### Files Changed
- New: `lib/widgets/app_icons.dart` (generated), `motion.dart`,
  `scroll_fade.dart`, `map_marker.dart`, `map_glass.dart`;
  `assets/fonts/app_symbols.ttf`, `assets/fonts/LICENSE-material-symbols.txt`;
  `tool/symbols/` (`build_font.py`, `icons.txt`, `README.md`);
  `android/app/src/main/res/drawable/ic_launcher_foreground.xml`,
  `ic_launcher_monochrome.xml`, `drawable-v26/ic_launcher_background.xml`,
  `mipmap-*/ic_launcher_round.png`; `docs/figma-pass4.md` and its
  screenshots; tests `nav_bar_test.dart`, `scroll_fade_test.dart`,
  `map_marker_test.dart`.
- Removed: the bitmap tab glyphs (`assets/design/nav-{map,hotlines,guides,profile}.png`)
  and `test/nav_icons_test.dart`; the raster launcher foregrounds and the
  `ic_launcher_background` colour.
- `lib/theme.dart`, `lib/widgets/design.dart`, `app_nav_bar.dart`,
  `you_are_here.dart`, `incident_map.dart`; every screen's icons; the map,
  Track It Live, sign in, the staff dashboards and lists.
- `pubspec.yaml`: the `AppSymbols` font; version 1.12.8.

### Database Changes
None.

### Testing
- `flutter analyze`: no issues. `flutter test`: 356 passed.
- New: the tab bar's selection, semantics, disc ring and reduced motion; the
  scroll fade in every scroll state, taps passing through it, the last row
  clearing it; the marker's surface, size, target, name, pulse and contrast.
- Tests that pinned the old uppercase tags, token values and status colours
  now pin the new ones.
- Installed on a Pixel 7 emulator (Android 15): the launcher icon with
  themed icons off and on, Sign in and Create account. Not checked on a
  physical phone or a Samsung launcher.

---

## v1.12.7 — 12 October 2026 — Trucks travelling together share one marker

App-only. The backend stays at v1.12.6.

### Changes

**Added**
- **Merged truck markers on Track It Live** (the resident's live tracker).
  Trucks whose markers would overlap at the current zoom share one marker:
  the truck in its agency's colour, a second disc peeking out behind it, and
  the count at the top right ("2", "3" … "9+"). When the group mixes agencies
  (Fire Volunteer and BFP), the disc behind takes the other agency's colour.
  A group whose trucks have all lost their location is greyed.
- Grouping is by distance **on screen**, not by road. Trucks in convoy merge;
  as the resident zooms in, or the trucks spread out, they split back into
  their own markers. Regrouped on every camera move and every frame of a
  truck's glide. A group never spreads wider than the merge radius (44 px)
  around its centre, so the marker sits where its trucks are, not between two
  far-apart ones (`lib/widgets/unit_groups.dart`).
- **Tapping a merged marker zooms in until its trucks separate.** Trucks
  parked within 30 m of each other, which no zoom would separate, are listed
  instead ("2 TRUCKS HERE": name, brigade, "Location lost" when stale).
- A screen reader reads a merged marker as "3 trucks: Apollo, Hermes, Ares".

**Unchanged**
- The sheet below the map still lists every truck on its own row. Only the
  map merges.

### Files Changed
- New: `lib/widgets/unit_groups.dart` (`groupOnScreen`, `UnitGroupMarker`),
  `test/unit_groups_test.dart`.
- `lib/screens/live_update_screen.dart`: the units layer groups, draws and
  opens merged markers.
- `test/track_it_live_test.dart`: the "one marker per truck" case now spaces
  its trucks apart; new cases for trucks together.
- `pubspec.yaml`: version 1.12.7.

### Database Changes
None.

### API Changes
None.

### Frontend Changes
Residents: fewer, clearer truck markers when several trucks come together.

### Testing
- Grouping: far apart → a marker each; overlapping → one; a five-truck convoy
  splits rather than drawing one marker far from its ends; a truck joins the
  nearest group; nothing in → nothing out; the count stops at 9+.
- The merged marker: count at the top right, its spoken label, tappable.
- Track It Live: three trucks together → one marker reading 3, labelled with
  all three names, every truck still in the sheet; two trucks apart → a
  marker each; tapping two parked trucks lists them with their brigade.
- Result: **341 app tests pass** (9 new), `flutter analyze` clean.

### Regression Check
Full suite passes. A single truck's marker is exactly as before.

---

## v1.12.6 — 7 October 2026 — Notifications outside the app, a fire alarm, and taps that open

Needs backend v1.12.6 (`replit-backend`) for the new-fire alert and the alarm
channel, and Render's `FCM_CREDENTIALS_JSON` for any push at all.

### Changes

**Added**
- **The fire alarm.** Two notification channels, made when the app opens
  (`MainActivity.kt`):
  - **Fire alerts** rings with the app's own fire alarm
    (`res/raw/fire_alarm.wav`: three rising whoops, about 2.3 s, synthesized
    for RepLiT), vibrates, and shows on the lock screen;
  - **Updates** uses the phone's own tone.
  The server picks the channel: a new fire for staff, a neighbour's first
  alert, or an alarm request rings the alarm. With the app open, the same
  pushes play the same alarm (`SoundCues.playFireAlarm`). It plays as a
  notification, so it follows the notification volume and the silent switch.
- **Every notification opens what it is about** (`NotificationRouter`), the
  same way from the phone's shade, from the banner while the app is open
  (**OPEN**), and from a row in **Alerts**:
  - a new fire → the incident. A responder lands where Verify and Respond are;
    a coordinator lands where their dashboard would send them for its state.
  - a fire nearby → "Do you see it too?" for a resident, the incident for
    staff;
  - news about your report → its live tracker;
  - an alarm request → BFP's alarm queue (the incident for others).
- **Alerts**: a **New fire** label; a chevron on rows that lead somewhere;
  "There is nothing to open for this one." when a row has nowhere to go.
- A status-bar icon (a flame) in place of the white square the launcher icon
  made, tinted in the accent.

**Modified**
- The in-app banner for a fire is red and stays 12 s; others stay 6 s.
- A neighbour alert arriving with the app open goes through the same router,
  so a staff member near a fire lands on the incident, not the resident's
  question.

### Files Changed
- New: `lib/api/notification_router.dart`, `test/notifications_test.dart`,
  `assets/sounds/fire_alarm.wav`, `android/app/src/main/res/raw/fire_alarm.wav`,
  `android/app/src/main/res/raw/keep.xml` (the release build's resource
  shrinker would otherwise drop the sound and icon),
  `android/app/src/main/res/drawable/ic_stat_replit.xml`.
- `android/app/src/main/kotlin/com/m2stz/replit/MainActivity.kt` (the
  channels), `android/app/src/main/AndroidManifest.xml` (default channel, icon,
  colour), `android/app/src/main/res/values/colors.xml`.
- `lib/api/push_service.dart` (alarm in the foreground, OPEN, everything
  through the router), `lib/screens/notifications_screen.dart`,
  `lib/sound/sound_cues.dart`.
- `pubspec.yaml`: version 1.12.6.

### Database Changes
None.

### API Changes
Reads the new `incident_new` push and Alerts type (backend v1.12.6). Nothing
else changes.

### Frontend Changes
Everyone: notifications ring, look like RepLiT's, and open where they belong.
Staff: a new fire now arrives as a notification with the alarm, with the app
closed too.

### Testing
- Where each type leads, for a citizen, a responder (fire and police), Fire
  Volunteer, BFP and barangay coordinators. Older staff types still open the
  incident; a test push and unknown types open nothing.
- Which types ring the alarm, and which notifications have something to open.
- The router opens nothing when the account cannot be read, or for an
  observer coordinator.
- Alerts: the New fire label and the chevron only on rows that lead
  somewhere; a tap marks the row read and opens it; a row with nowhere to go
  only marks read; a row that cannot be opened says so.
- A release build compiles the channels, and the APK carries the alarm and
  the icon.
- Result: **332 app tests pass** (14 new), `flutter analyze` clean.

### Regression Check
Full suite passes. Pushes from a backend that names no channel go to
**Updates**, as before but under RepLiT's own name.

---

## v1.12.5 — 5 October 2026 — AI summaries for coordinators

Needs backend v1.12.5 (`replit-backend`).

### Changes

**Added**
- **Menu → AI summaries** for Fire Volunteer and BFP coordinators
  (`lib/screens/subadmin/ai_summaries_screen.dart`).
  - A list of **"Summarized incident — 10/5/2026"** (the Philippine day the
    summary was written), with the area and the teams that filed, newest
    first.
  - Nobody asks for a summary: the AI writes one when a team files and
    rewrites it when another does. One still being written shows
    **Writing** (or **Updating**, with the older one readable meanwhile), and
    the list checks back by itself every 10 seconds, up to six times. Pull to
    refresh as well.
  - Tapping one opens it as a **note**: the summary, which model wrote it and
    when, and a reminder to check it against the teams' reports.
  - **Download PDF** opens the report in the phone's browser, which saves it
    to Downloads. The app gets a five-minute link first, since the browser
    cannot sign in. The PDF is made at download, so it always includes every
    report filed by then. An incident with no summary still has its PDF.
- `ApiClient`: `getAiSummaries`, `getReportLink`.

### Files Changed
- New: `lib/screens/subadmin/ai_summaries_screen.dart`,
  `test/ai_summaries_screen_test.dart`.
- `lib/widgets/staff_shell.dart`: `StaffPage.summaries` and the AI summaries
  item (Fire Volunteer and BFP coordinators only; the server refuses
  observers).
- `lib/api/api_client.dart`: the two calls.
- `pubspec.yaml`: version 1.12.5.
- `test/staff_shell_test.dart`: AI summaries for fire coordinators, not
  responders or observer coordinators.

### Database Changes
None.

### API Changes
Uses `GET /ai-summaries`, `POST /incidents/{id}/report-link` and the
browser's `GET /incidents/{id}/report-download` (backend v1.12.5).

### Frontend Changes
Coordinator: menu → AI summaries. Responder: nothing new.

### Testing
- The date is the Philippine day, M/D/YYYY (5:30 PM UTC on the 4th → 10/5).
- The list: title, area and teams; Writing until it arrives, the list
  checking back by itself and stopping once nothing is owed; Updating and
  No summary; empty; the server's refusal in its own words.
- The note: the summary, model and time; Download PDF asks for the link and
  hands the browser the full address. An incident with no summary still
  downloads.
- The menu: AI summaries for Fire Volunteer and BFP coordinators, not for
  responders or a barangay coordinator.
- Result: **318 app tests pass**, `flutter analyze` clean.

### Regression Check
Full suite passes. The rest of the menu is unchanged.

---

## v1.12.4 — 5 October 2026 — Coordinators make their responders' accounts

Needs backend v1.12.4 (`replit-backend`), and its migration applied first.

### Changes

**Added**
- **Menu → Responders** for coordinators (Fire Volunteer and BFP): where a
  responder's account comes from (`lib/screens/subadmin/team_screen.dart`).
  - The roster: name, sign-in address, **On a run** / **Deactivated**.
  - **New responder**: first name, surname, optional mobile; the address it
    makes is shown as the name is typed (`jdelacruz.resfir@replit.com`,
    numbered after the surname when taken — the server decides).
  - **Account ready**: the address and a generated password, shown once, with
    Copy — to hand over in person.
  - Per responder: **Reset password** (a new one, shown once) and
    **Deactivate** / **Reactivate** (asks first; says when a live response
    will be released).
- `ApiClient`: `getTeamResponders`, `previewResponderEmail`,
  `createResponder`, `resetResponderPassword`, `deactivateResponder`,
  `reactivateResponder`.

### Files Changed
- New: `lib/screens/subadmin/team_screen.dart`, `test/team_screen_test.dart`.
- `lib/widgets/staff_shell.dart` — `StaffPage.team`, the Responders item.
- `lib/api/api_client.dart` — the six calls.
- `pubspec.yaml` — version 1.12.4.
- `test/staff_shell_test.dart` — Responders for coordinators only.

### Database Changes
None here (the backend adds `users.is_active` and friends).

### API Changes
Uses the new `/team/responders` endpoints (backend v1.12.4).

### Frontend Changes
Coordinator: menu → Responders. Responder: nothing new to do. A deactivated
account's session stops working (back to the sign-in screen), and signing in
then says "This account has been deactivated. Ask your coordinator to
reactivate it."

### Testing
- The roster shows who is on a run and who is deactivated, and the count
  active.
- New responder: the address appears as the name is typed; Create shows the
  address and password once; the new responder is then listed.
- Deactivate asks first (and says a live response will be released), then
  turns the account off.
- The menu offers Responders to coordinators, not to responders.
- Result: **309 app tests pass**, `flutter analyze` clean.

### Regression Check
Whole app suite passes; nothing else changed.

---

## v1.12.3 — 1 October 2026 — One console for responders and coordinators; Done right after fire out

App only: no backend or API change (the backend stays at 1.12.1).

### Changes

**Modified — responder and coordinator: one consistent console**
- Every staff screen now sits in the same frame (`lib/widgets/staff_shell.dart`,
  `StaffScaffold`): a top bar with Back (or the mark on a dashboard), the
  screen's name, a **RESPONDER** or **COORDINATOR** tag under it, the bell and
  the **menu**. The same menu opens from every screen — including the
  incident, report review, command and Post-Incident Report screens, which had
  none before (only the dashboards did).
- One menu (`StaffDrawer`) for everyone: name, role tag, team and agency, then
  Dashboard and Incidents; **My duty** for a responder; **Pending reports** for
  a coordinator (with the count owed); **Alarm requests** for BFP (with the
  count pending); Log out. Choosing a section goes back to the dashboard and
  opens it from there, so Back from any section is the dashboard.
- Responders land on the same dashboard as coordinators (counts and the live
  map). The Duty screen is "My duty" in the menu; the responder-only bottom
  tab bar (Duty / Map / RUN / Unit / Profile) is gone — it switched to a
  different navigation on the Map tab and opened the citizen profile.
- The per-screen settings cog, account sheet and log-out copies are replaced
  by the one menu and one sign-out (`staffSignOut`), which also stops location
  sharing.
- Staff screens draw with the same REPLIT x DAWI palette as the citizen ones
  (solid `#1D1D1D` cards on `#424242` edges; the old `AppColors` ground
  constants now carry the DAWI values).
- The back chevrons drawn over the report photo are gone (Back is in the bar);
  the command screens' map sits under the bar instead of under the status bar.
- The driver/crew boxes on the command screens grow with a large font instead
  of clipping it.

**Modified — citizen: the finished screen comes next at fire out**
- When the resident is on Track It Live and their report's fire is out (or it
  was not confirmed), the app takes them straight to the report's finished
  screen — "Report done · Fire out" with **Done** — instead of leaving them to
  back out to find it. If the report screen is underneath it is brought
  forward and updated at once; otherwise it replaces the live screen. A report
  already finished with, opened again from Your reports, is left as it ended.

### Files Changed
- New: `lib/widgets/staff_shell.dart`; removed: `lib/widgets/responder_nav_bar.dart`.
- Staff: `lib/screens/responder/responder_home_screen.dart`,
  `responder_duty_screen.dart`, `responder_incidents_screen.dart`,
  `responder_incident_report_screen.dart`, `responder_incident_screen.dart`;
  `lib/screens/subadmin/subadmin_dashboard_screen.dart`,
  `subadmin_home_screen.dart`, `subadmin_incident_report_screen.dart`,
  `subadmin_incident_command_screen.dart`, `pending_reports_screen.dart`,
  `post_incident_report_screen.dart`; `lib/screens/bfp/bfp_dashboard_screen.dart`,
  `bfp_alarm_requests_screen.dart`; `lib/screens/role_gate.dart`.
- Citizen: `lib/screens/live_update_screen.dart`,
  `lib/screens/report_status_screen.dart`.
- `lib/theme.dart` — `AppColors` ground on the DAWI values.
- `pubspec.yaml` — version 1.12.3.
- Tests: `test/staff_shell_test.dart` (new), `test/track_it_live_test.dart`,
  `test/responder_duty_test.dart`.

### Database Changes
None.

### API Changes
None.

### Frontend Changes
Responder: dashboard (now the home), My duty, incidents, report, incident.
Coordinator (Fire Volunteer and BFP): dashboard, incidents, report review,
command, pending reports, Post-Incident Report, alarm requests. Citizen:
Track It Live → the finished screen.

### Testing
- A responder gets the RESPONDER tag and Dashboard / Incidents / My duty; a
  coordinator the COORDINATOR tag, their team line and Pending reports; BFP
  also Alarm requests.
- Inside an incident: Back, the same tag and the same menu; Dashboard from the
  menu returns home; Back returns to the dashboard.
- Fire out on the resident's own report goes straight to the finished screen
  with Done; a report already finished with stays on Track It Live.
- Staff screens rendered off-device (both dashboards, the open menu for each
  role, the coordinator command screen) and checked.
- Result: **306 app tests pass**, `flutter analyze` clean.

### Regression Check
The whole suite passes. The Duty test now reads the screen's name from the
top bar ("MY DUTY") and checks the RESPONDER tag; nothing else changed.

---

## v1.12.2 — 1 October 2026 — REPLIT x DAWI colours; sheets that drag out of the way

App only: no backend or API change (the backend stays at 1.12.1).

### Changes

**Modified — colours (REPLIT x DAWI Figma, file `yTInpc7mWlTug0PQzKiW0L`)**
- Dark palette (`AppPalette.dark`): cards and rows are solid `#1D1D1D`
  (SURFACE/grey-500) on `#424242` hairlines (BACKGROUND/grey-400), not the
  overhaul's translucent glass; `#4A4A4A` for the stronger edge; the tab bar
  and map sheets on the `#131313` ground; secondary text `#C9C9C9`.
- Agency colours, app-wide: police violet `#8B5CF6` (was blue), medical teal
  `#14B8A6` (was green), barangay amber `#FFB020`; map water (hydrants,
  cisterns, bodies of water) one blue `#5B93F5`; shelters `#22C55E`.
- Icon wells: each accent's deep 900 shade with a white glyph (fire
  `#6B3C2B`, police `#3A2767`, medical `#084D46`, barangay `#6B4A0D`, shelter
  `#0E5327`) — `IconWell`, the map sheet rows, report details, hotlines,
  guides, Track It Live. The light theme keeps its washes.
- Map: a live incident marker is the fire's coral on a white edge; layer
  chips are washed and edged in their colour when on; the location card's
  well is the coral gradient; the areas sheet is the design's 50% glass over
  a 9px blur, with a coral LIVE and coral confidence bars.
- Track It Live: the "Your report is live" banner and the incident circle
  are coral (they were the risk-zone red).
- Grab handles are the design's 80 × 4.

**Added — sheets that drag out of the way**
- Map ("AREAS SHEET"): drag the sheet down — from anywhere on it — and it
  folds to its title just above the tab bar, so the map is clear; drag it up
  or tap the title to open it again. A tap on a row still opens the row.
  (`lib/widgets/drag_down_sheet.dart`.)
- Track It Live: the sheet drags down to its status line (pulling the list
  down from its top does it too, as does tapping the handle) and snaps open
  or folded.

### Files Changed
- `lib/theme.dart` — DAWI dark palette, agency colours, `wellFor`, `glyphOn`,
  `water`.
- `lib/widgets/design.dart` — `IconWell` wells, `SheetHandle` size.
- `lib/widgets/drag_down_sheet.dart` — new.
- `lib/screens/map_screen.dart`, `lib/screens/live_update_screen.dart`,
  `lib/screens/call_screen.dart`, `lib/screens/sos_report_screen.dart`,
  `lib/screens/guide_screen.dart`, `lib/screens/guide_detail_screen.dart`,
  `lib/models/hotline.dart`.
- `pubspec.yaml` — version 1.12.2.
- Tests: `test/drag_down_sheet_test.dart`, `test/dawi_palette_test.dart` (new);
  `test/map_screen_test.dart`, `test/track_it_live_test.dart`.

### Database Changes
None.

### API Changes
None.

### Frontend Changes
Citizen: Map, Track It Live, report details, hotlines, guides, and every
screen drawn with the shared panels and wells. Staff screens that use the
shared agency colours show police violet and medical teal too.

### Testing
- The areas sheet folds when dragged from a row, keeps its title reachable,
  hides its rows from taps while folded, and reopens on a tap of the title
  or a drag up; a short drag springs back; a tap on a row still lands.
- The Track It Live sheet folds to its status line and the handle reopens it.
- The palette matches the DAWI tokens; wells are the 900 shades with white
  glyphs; the light theme keeps washes.
- Screens rendered off-device (map open and folded, Track It Live open,
  folded and scrolled, hotlines) and compared with the Figma frames.
- Result: **299 app tests pass**, `flutter analyze` clean.

### Regression Check
The whole suite passes unchanged apart from the two tests added to
`map_screen_test.dart` and `track_it_live_test.dart`.

---

## v1.12.1 — 30 September 2026 — Who verified a fire, and for which organization

### Changes

**Added**
- **Citizen — Track It Live**: a "Verified by Hercules Fire Brigade" row under
  the status rail once the report is verified, with how long ago. The team
  only, never the person's name (the server sends none).
- **Staff — who verified and their team**: the responder and coordinator
  report screens' VERIFIED BY now read "Ramon Dizon · Hercules Fire Brigade";
  the responder incident screen and the coordinator command screen show
  "Verified by …" under the address.

**Unchanged, confirmed**
- The moving fire-truck marker on the reporter's Track It Live, for every
  responder and responding coordinator, from their first GPS fix.

### Files Changed
- `lib/models/tracking.dart` — `verifiedBy`, `verifiedByAgency`, `verifiedAt`.
- `lib/screens/live_update_screen.dart` — the Verified-by row.
- `lib/screens/responder/responder_status.dart` — `verifierLine`.
- `lib/screens/responder/responder_incident_report_screen.dart`,
  `lib/screens/responder/responder_incident_screen.dart`,
  `lib/screens/subadmin/subadmin_incident_report_screen.dart`,
  `lib/screens/subadmin/subadmin_incident_command_screen.dart`.
- `pubspec.yaml` — version 1.12.1.
- Tests: `test/verifier_line_test.dart` (new), `test/track_it_live_test.dart`.

### Database Changes
None.

### API Changes
Reads the new optional fields from backend v1.12.1 (`verified_by*` on the
incident detail and the tracking snapshot). Against an older backend they are
absent and nothing new is shown.

### Frontend Changes
Citizen: Track It Live. Responder: incident screen, report screen.
Coordinator: review screen, command screen.

### Testing
- The resident sees which team verified it, with the time; someone who did not
  report it is not told.
- `verifierLine`: name and team; agency fallback; Admin; nothing before
  verification.
- Result: **280 app tests pass**, `flutter analyze` clean.

### Regression Check
Whole app suite passes, including every existing Track It Live test (truck
markers, stale units, polling, background). No existing test changed.

---

## v1.12.0 — 30 September 2026 — Verify, Respond, Reject; zoomable photos; routing to the fire

### Changes

**Added**
- **Verify for responders**: a new report can be verified by a responder
  (incident screen "VERIFY THIS INCIDENT", report screen "VERIFY — IT IS A REAL
  FIRE"), not only by a captain. Verifying sends nobody.
- **Respond for coordinators**: the coordinator review screen offers "RESPOND —
  I'M GOING" once an incident is verified and opens the command screen; the
  command screen offers Respond, Mark arrived, and Reject while on the way. A
  responding coordinator shares their location like a responder.
- **Zoomable report photo** (`PhotoViewer`): tap the photo on the responder and
  coordinator report screens for full screen; pinch or double-tap to zoom, drag
  to pan, close to return. The original photo is only displayed.
- **Route to the fire**: "ROUTE TO THE FIRE" on the responder incident screen,
  both report screens and the coordinator command screen opens road directions
  (the live navigation screen, now with a fire mode): from the phone's live GPS
  to the incident, driving time from the road route, counting down, re-routing
  when off the route, "You are at the fire" within 100 m.
- **Live staff screens** (`LiveRefresh`): the responder and coordinator
  dashboards, feeds and incident screens re-read the moment the server reports
  a change on the incident's or the agency's socket channel, so one person's
  verify, respond or reject shows on everyone else's screen within a second.

**Modified**
- Coordinator review: VERIFY / REJECT for a new report; RESPOND, FIRE OUT,
  REJECT once verified or on the way; FIRE OUT only once someone is on scene.
  "ACCEPT — WE'RE COMING TOO" is replaced by RESPOND.
- The responder feed shows OPEN on new reports too (to verify them).
- A refused action (the screen was behind) now re-reads the screen instead of
  leaving the stale button up.
- Directions no longer invent a starting point: with location off or refused,
  the screen says so, offers Try again, and draws no route. A citizen's shelter
  route may still start from where the report was sent.

**Fixed**
- The disabled "FOR SUB ADMIN ONLY" button on the responder report screen is
  gone; it blocked the action responders now have.

### Files Changed
- New: `lib/api/live_refresh.dart`, `lib/widgets/photo_viewer.dart`,
  `CHANGELOG.md`.
- `lib/api/api_client.dart` — `verifyIncident` (replaces `acceptIncident`);
  `selfDispatch` documented as Respond.
- `lib/screens/directions_screen.dart` — `DirectionsTo.fire`,
  `openRouteToFire`, driving pace, 100 m arrival, no-location state.
- `lib/screens/responder/responder_incident_screen.dart`,
  `lib/screens/responder/responder_incident_report_screen.dart`,
  `lib/screens/responder/responder_incidents_screen.dart`,
  `lib/screens/responder/responder_home_screen.dart`.
- `lib/screens/subadmin/subadmin_incident_report_screen.dart`,
  `lib/screens/subadmin/subadmin_incident_command_screen.dart`,
  `lib/screens/subadmin/coordinator_nav.dart`,
  `lib/screens/subadmin/subadmin_home_screen.dart`,
  `lib/screens/subadmin/subadmin_dashboard_screen.dart`,
  `lib/screens/bfp/bfp_dashboard_screen.dart`.
- `pubspec.yaml` — version 1.12.0.
- Tests: `test/subadmin_test.dart` (v12 group replaces the v11 Accept group),
  `test/directions_live_test.dart` (fire routing).

### Database Changes
None in this repository. The backend's v1.12.0 migration lets responders
verify (see `replit-backend/CHANGELOG.md`).

### API Changes
Uses the new `POST /incidents/{id}/verify`; everything else it calls already
existed.

### Frontend Changes
Responder: incident screen, report screen, feed, dashboard. Coordinator (Fire
Volunteer and BFP): review screen, command screen, home list, dashboards.
Shared: directions (fire mode), photo viewer. Citizen screens unchanged.

### Testing
- Coordinator verify posts `/verify`; respond posts `/self-dispatch` and lands
  on the command screen; someone already responding is not offered Respond;
  reject offered while verified / on the way, not on scene.
- Command screen offers Respond and Reject while on the way.
- Photo opens full screen with zoom and closes.
- Route to the fire opens fire mode at the incident's coordinates; with
  location off it says so and draws no route.
- Fire routing: driving minutes from the road route count down; "You are at
  the fire" within 100 m.
- Live refresh: a socket change re-reads once per burst; responder GPS fixes
  do not.
- Result: **275 app tests pass**, `flutter analyze` clean.

### Regression Check
The whole app suite (citizen map, Track It Live, sign-up and login, phone
verification, maps, offline queue, responder tracker, Post-Incident Report)
passes. Citizen-facing screens were not changed; "On the way" now appears when
the first responder or coordinator responds, as the backend decides.
