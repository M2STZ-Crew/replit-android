import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'bfp/bfp_dashboard_screen.dart';
import 'map_screen.dart';
import 'onboarding_screen.dart';
import 'observer_handoff_screen.dart';
import 'responder/responder_duty_screen.dart';
import 'subadmin/subadmin_dashboard_screen.dart';

/// Decides which home screen to show after authentication, based on the user's
/// role from GET /auth/me: response_team → the responder console; a coordinator
/// sub-admin (Fire Volunteer, BFP) → their console; an observer sub-admin
/// (Police, Medical, Barangay) → a pointer to the Observer Console on the web;
/// everyone else → the citizen app.
///
/// The citizen app now opens on the map, not the SOS dial. That is the v2
/// design's arrangement: residents open the app to see what is happening, and
/// the SOS is one tap away on a coral button that floats over the map — a
/// bigger, more findable target than a quarter of the tab bar.
class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _me;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final me = await _api.getMe();
      if (mounted) setState(() => _me = me);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your account.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _shell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: context.pal.muted, size: 40),
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: context.pal.muted)),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _load,
              child: Text(
                'Retry',
                style: TextStyle(
                  color: context.pal.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final me = _me;
    if (me == null) {
      return _shell(
        child: CircularProgressIndicator(color: context.pal.accent),
      );
    }
    final role = me['role'] as String?;
    if (role == 'response_team') {
      return ResponderDutyScreen(me: me);
    }
    if (role == 'sub_admin') {
      // Observers (police, medical, barangay) work from the Observer Console on
      // the web (v10 §2.6); only the coordinators run the response from here.
      if (isObserverCaptain(me)) {
        return ObserverHandoffScreen(me: me);
      }
      // BFP sub-admins get the alarm-review console; Fire-Vol get the full console.
      if (me['agency_type'] == 'bfp') {
        return BfpDashboardScreen(me: me);
      }
      return SubAdminDashboardScreen(me: me);
    }
    return const _CitizenEntry();
  }

  Widget _shell({required Widget child}) {
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(Art.mark, width: 90, height: 90),
              const SizedBox(height: 28),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// The resident's way in: the tour the first time, the map ever after.
///
/// Reading the flag takes a frame or two, so the wait is the app's own ground
/// rather than a spinner — a resident opening the app should never see a
/// loading state before the map they came for.
class _CitizenEntry extends StatelessWidget {
  const _CitizenEntry();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: Tour.seen(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(backgroundColor: context.pal.background);
        }
        return snapshot.data! ? const MapScreen() : const OnboardingScreen();
      },
    );
  }
}
