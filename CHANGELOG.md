# Changelog

Versions follow `MAJOR.MINOR.PATCH` and match the backend (`replit-backend`):
MINOR tracks the Master Context generation, so 1.12.x implements Master
Context v12. The build number after `+` is the CI run number.

---

## v1.12.9 — 15 October 2026 — Turn-by-turn navigation to the fire

App-only. The backend stays at v1.12.6. Implements PRD v12 §4.9 (route
optimisation and navigation) on the existing `DirectionsScreen`. Branched
from v1.12.7 (`main`): 1.12.8 is the pass 4 design branch, not yet merged.

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
