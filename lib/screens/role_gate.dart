import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'bfp/bfp_dashboard_screen.dart';
import 'map_screen.dart';
import 'observer_handoff_screen.dart';
import 'responder/responder_home_screen.dart';
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
            const Icon(Icons.cloud_off, color: AppColors.muted, size: 40),
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _load,
              child: const Text('Retry',
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }
    final me = _me;
    if (me == null) {
      return _shell(
        child: const CircularProgressIndicator(color: AppColors.accent),
      );
    }
    final role = me['role'] as String?;
    if (role == 'response_team') {
      return ResponderHomeScreen(me: me);
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
    return const MapScreen();
  }

  Widget _shell({required Widget child}) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
