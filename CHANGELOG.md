# Changelog

Versions follow `MAJOR.MINOR.PATCH` and match the backend (`replit-backend`):
MINOR tracks the Master Context generation, so 1.12.x implements Master
Context v12. The build number after `+` is the CI run number.

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
