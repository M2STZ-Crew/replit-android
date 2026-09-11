import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'responder/responder_status.dart';

/// Agencies whose team captains observe rather than coordinate. Mirrors
/// OBSERVER_AGENCIES in app/services/incident.py.
const Set<String> kObserverAgencies = {'police', 'medical', 'barangay'};

bool isObserverCaptain(Map<String, dynamic> me) =>
    me['role'] == 'sub_admin' && kObserverAgencies.contains(me['agency_type']);

/// Where a Police, Medical or Barangay team captain lands on mobile.
///
/// Master Context v10 §2.6: observers watch from a stationed view, so their
/// surface is the Observer Console on the web — Dashboard, Map and Audit log,
/// with Accept on routed incidents. The coordinator console that used to open
/// here offered verify, dispatch and fire codes, every one of which the server
/// refuses an observer. This screen says where to go instead, and still lets
/// them see the public map.
class ObserverHandoffScreen extends StatelessWidget {
  const ObserverHandoffScreen({super.key, required this.me});

  final Map<String, dynamic> me;

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await PushService.instance.unregister();
    await ApiClient().logout();
    await Session.instance.clear();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const url = ApiConfig.observerConsoleUrl;
    final agency = responderAgencyLabel(me['agency_type'] as String?);
    final name = (me['full_name'] as String?) ?? (me['email'] as String?) ?? 'Team captain';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Image.asset(Art.mark, width: 64, height: 64, alignment: Alignment.centerLeft),
            const SizedBox(height: 28),
            Eyebrow('$agency · Observer', color: AppColors.accent),
            const SizedBox(height: 8),
            const Text('YOUR CONSOLE IS ON THE WEB', style: AppText.title),
            const SizedBox(height: 14),
            Text(
              'Hi $name. $agency team captains work from the Observer Console: '
              'a dashboard of incidents that asked for your agency, a live map, '
              'and the audit log. When Admin routes an incident to you, you press '
              'Accept there.',
              style: AppText.body,
            ),
            const SizedBox(height: 22),
            Panel(
              color: AppColors.glassDim,
              child: Row(
                children: [
                  const IconWell(tint: AppColors.info, icon: Icons.desktop_windows_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OBSERVER CONSOLE', style: AppText.cardTitle.copyWith(fontSize: 13)),
                        const SizedBox(height: 6),
                        SelectableText(
                          url.isEmpty ? 'Ask your Admin for the address.' : url,
                          style: AppText.meta.copyWith(height: 1.4, color: AppColors.textSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (url.isNotEmpty) ...[
              AppButton(
                'Open the Observer Console',
                icon: Icons.open_in_new_rounded,
                onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              ),
              const SizedBox(height: 12),
            ],
            AppButton.secondary(
              'View the public map',
              icon: Icons.map_outlined,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MapScreen()),
              ),
            ),
            const SizedBox(height: 12),
            AppButton.danger('Log out', icon: Icons.logout, onPressed: () => _logout(context)),
            const SizedBox(height: 22),
            Text(
              'Verifying, dispatching and resolving are for Fire Volunteer and BFP '
              'coordinators, who use this app.',
              style: AppText.meta.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
