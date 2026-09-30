# Changelog

Versions follow `MAJOR.MINOR.PATCH` and match the backend (`replit-backend`):
MINOR tracks the Master Context generation, so 1.12.x implements Master
Context v12. The build number after `+` is the CI run number.

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
