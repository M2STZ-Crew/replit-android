import 'package:flutter/material.dart';

import '../../models/coordinator_powers.dart';
import '../../sound/sound_cues.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/staff_shell.dart';
import '../bfp/bfp_alarm_requests_screen.dart';
import '../notifications_screen.dart';
import '../responder/responder_status.dart';
import '../subadmin/ai_summaries_screen.dart';
import '../subadmin/team_screen.dart';
import 'coordinator_feed.dart';
import 'my_decisions_screen.dart';

/// The Profile tab (06 · C15): who you are, what you may do, how the fire
/// alert sounds, and the rest of the console — your decisions, your
/// responders' accounts, the AI summaries, BFP's alarm requests.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.feed});

  final CoordinatorFeed feed;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final SoundCues _sound = SoundCues.instance;
  bool? _alarmOn;
  double? _volume;

  Map<String, dynamic> get _me => widget.feed.me;

  @override
  void initState() {
    super.initState();
    _loadSound();
  }

  Future<void> _loadSound() async {
    try {
      final on = await _sound.fireAlarmEnabled();
      final volume = await _sound.fireAlarmVolume();
      if (mounted) {
        setState(() {
          _alarmOn = on;
          _volume = volume;
        });
      }
    } catch (_) {
      // The rows show the defaults.
    }
  }

  Future<void> _setAlarm(bool on) async {
    setState(() => _alarmOn = on);
    await _sound.setFireAlarmEnabled(on);
  }

  Future<void> _pickVolume() async {
    var value = _volume ?? 1;
    final picked = await showFrameSheet<double>(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => SheetFrame(
          children: [
            const SheetTitles(
              eyebrow: 'Alerts',
              title: 'Alert volume',
              body:
                  'How loud the alarm rings in the app, on top of your '
                  "phone's notification volume. At 0% it stays quiet here "
                  'only; the notification still shows.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: value,
                    divisions: 10,
                    label: '${(value * 100).round()}%',
                    onChanged: (v) => set(() => value = v),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: RowValue(
                    '${(value * 100).round()}%',
                    color: context.pal.onBackground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              'Save',
              run: true,
              onPressed: () => Navigator.of(context).pop(value),
            ),
            const SizedBox(height: 10),
            AppButton.secondary(
              'Play it',
              icon: AppIcons.volumeUp,
              onPressed: () async {
                final before = await _sound.fireAlarmVolume();
                await _sound.setFireAlarmVolume(value);
                await _sound.playAlert(
                  SoundCues.categoryForAgency(_me['agency_type'] as String?),
                );
                await _sound.setFireAlarmVolume(before);
              },
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _sound.setFireAlarmVolume(picked);
    if (mounted) setState(() => _volume = picked);
  }

  void _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final name =
        (_me['full_name'] as String?) ?? (_me['email'] as String?) ?? 'You';
    final team = (_me['organization_name'] as String?)?.trim();
    final agency = responderAgencyLabel(widget.feed.agency);
    final bfp = widget.feed.isBfp;
    final powers = CoordinatorPowers.of(_me);
    final asked = switch (widget.feed.agency) {
      'police' => 'Police',
      'medical' => 'Medical',
      'barangay' => 'Barangay',
      _ => 'Fire',
    };
    const gap = SizedBox(height: 8);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TabHeader(eyebrow: 'Account', title: 'Profile'),
          Expanded(
            child: ScrollFade(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  MediaQuery.paddingOf(context).bottom + kScrollFadeEndPadding,
                ),
                children: [
                  ListRow(
                    leading: AgencyPlate(agency: widget.feed.agency ?? ''),
                    title: name,
                    subtitle:
                        'Coordinator · ${team == null || team.isEmpty ? agency : '$team, $agency'}',
                  ),
                  gap,
                  ListRow(
                    leading: const IconPlate(AppIcons.shield),
                    title: powers.rejects
                        ? 'You can accept and reject'
                        : 'You can accept',
                    subtitle: powers.rejects
                        ? 'Any agency can accept. Only Fire Volunteer and BFP '
                              'can reject.'
                        : 'Accepting acknowledges the Areas that ask for '
                              '$asked. Only Fire Volunteer and BFP can reject.',
                    chevron: true,
                    onTap: () => _push(PermissionsScreen(me: _me)),
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader('Alerts'),
                  const SizedBox(height: 12),
                  ListRow(
                    leading: const IconPlate(AppIcons.volumeUp),
                    title: 'Fire alert sound',
                    subtitle:
                        'Rings in the app when a new Area asks for $asked. '
                        "With the app closed, Android's $asked alerts channel "
                        'rings it.',
                    trailing: Switch(
                      value: _alarmOn ?? true,
                      onChanged: _alarmOn == null ? null : _setAlarm,
                    ),
                    onTap: _alarmOn == null
                        ? null
                        : () => _setAlarm(!(_alarmOn ?? true)),
                  ),
                  gap,
                  ListRow(
                    leading: const IconPlate(AppIcons.volumeUp),
                    title: 'Alert volume',
                    subtitle: 'In the app only. At 0% it is quiet here.',
                    trailing: RowValue(
                      '${((_volume ?? 1) * 100).round()}%',
                      color: pal.onBackground,
                    ),
                    onTap: _pickVolume,
                  ),
                  gap,
                  ListRow(
                    leading: const IconPlate(AppIcons.explore),
                    title: 'Map rotation',
                    subtitle: 'Heading-up while moving, compass when still',
                    trailing: RowValue('Hybrid', color: pal.onBackground),
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader('More'),
                  const SizedBox(height: 12),
                  ListRow(
                    leading: const IconPlate(AppIcons.history),
                    title: 'My decisions',
                    subtitle:
                        'Every accept, reject, merge and fire out you made',
                    chevron: true,
                    onTap: () => _push(MyDecisionsScreen(feed: widget.feed)),
                  ),
                  gap,
                  ListRow(
                    leading: const IconPlate(AppIcons.group),
                    title: 'Responders',
                    subtitle: "Make and manage your responders' accounts",
                    chevron: true,
                    onTap: () => _push(TeamScreen(me: _me)),
                  ),
                  // The server keeps AI summaries to the coordinators who run
                  // the response (ai.py: assert_coordinator).
                  if (powers.coordinates) ...[
                    gap,
                    ListRow(
                      leading: const IconPlate(AppIcons.autoAwesome),
                      title: 'AI summaries',
                      subtitle: 'What each fire your teams filed for came to',
                      chevron: true,
                      onTap: () => _push(AiSummariesScreen(me: _me)),
                    ),
                  ],
                  if (bfp) ...[
                    gap,
                    ListRow(
                      leading: const IconPlate(AppIcons.campaign),
                      title: 'Alarm requests',
                      subtitle: 'Fire Volunteer asks to raise the alarm',
                      chevron: true,
                      onTap: () => _push(const BfpAlarmRequestsScreen()),
                    ),
                  ],
                  gap,
                  ListRow(
                    leading: const IconPlate(AppIcons.notifications),
                    title: 'Alerts',
                    subtitle: 'Every notification sent to you',
                    chevron: true,
                    onTap: () => _push(const NotificationsScreen()),
                  ),
                  const SizedBox(height: 24),
                  AppButton.danger(
                    'Log out',
                    icon: AppIcons.logout,
                    onPressed: () => staffSignOut(
                      Navigator.of(context),
                      api: widget.feed.api,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a coordinator may do (06 · C15b). The server enforces every one of
/// these; the screen only mirrors them, so it never promises more.
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key, required this.me});

  final Map<String, dynamic> me;

  @override
  Widget build(BuildContext context) {
    final bfp = me['agency_type'] == 'bfp';
    final powers = CoordinatorPowers.of(me);
    if (!powers.coordinates) {
      // A Police, Medical or Barangay coordinator (06 · C01P): the server
      // lets them acknowledge their agency's Areas and follow them.
      return CapabilitiesScreen(
        eyebrow:
            'Coordinator · ${responderAgencyLabel(me['agency_type'] as String?)}',
        can: const [
          (
            'Accept an Area',
            'Acknowledges it for your organisation when it asks for your '
                'agency',
          ),
          ('Merge or keep separate', 'When two Areas overlap'),
          (
            'Follow an Area on LIVE and the map',
            'Its units and its alarm level',
          ),
          ("Make your responders' accounts", 'Under Profile, Responders'),
          ('Report a fire', 'From the map, like a resident'),
        ],
        cannot: const [
          ('Reject an Area', 'Fire Volunteer and BFP coordinators'),
          ('Go to the scene or mark fire out', 'Fire Volunteer and BFP'),
          ('Press fire codes', 'Fire Volunteer and BFP coordinators'),
          ('File the post-incident report', 'The responding fire team'),
          ('Change the alarm level', 'BFP coordinators only'),
        ],
      );
    }
    final can = <(String, String)>[
      (
        'Accept an Area',
        'Verifies it — and puts you on the way, on your unit, if you are '
            'going too',
      ),
      ('Reject an Area', 'Fire Volunteer and BFP coordinators only'),
      ('Merge or keep separate', 'When two Areas overlap'),
      ('Mark fire out', 'Your units stand down and stop sharing location'),
      ('Press fire codes', 'Recorded as events on the incident'),
      (
        'File the post-incident report',
        'Once per Area for your team, no draft',
      ),
      ("Make your responders' accounts", 'Under Profile, Responders'),
      if (bfp)
        (
          'Raise the alarm level',
          'From the alarm requests Fire Volunteer sends',
        )
      else
        ('Ask BFP to raise the alarm', 'From the alarm level on LIVE'),
    ];
    final cannot = <(String, String)>[
      if (!bfp) ('Change the alarm level', 'BFP coordinators only'),
      ('Edit a filed report', 'A post-incident report saves once'),
      ('Reopen a rejected Area', 'It has left the live feed for good'),
    ];
    return CapabilitiesScreen(
      eyebrow:
          'Coordinator · ${responderAgencyLabel(me['agency_type'] as String?)}',
      can: can,
      cannot: cannot,
    );
  }
}
