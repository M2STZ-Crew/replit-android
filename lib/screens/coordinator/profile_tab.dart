import 'package:flutter/material.dart';

import '../../app_version.dart';
import '../../models/coordinator_powers.dart';
import '../../sound/sound_cues.dart';
import '../../theme.dart';
import '../../updates/app_updates.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/staff_account_section.dart';
import '../../widgets/staff_shell.dart';
import '../bfp/bfp_alarm_requests_screen.dart';
import '../notifications_screen.dart';
import '../responder/responder_status.dart';
import '../subadmin/ai_summaries_screen.dart';
import '../subadmin/team_screen.dart';
import 'coordinator_feed.dart';
import 'my_decisions_screen.dart';
import '../../i18n/i18n.dart';

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
            SheetTitles(
              eyebrow: t('Alerts'),
              title: t('Alert volume'),
              body: t(
                'How loud the alarm rings in the app, on top of your '
                "phone's notification volume. At 0% it stays quiet here "
                'only; the notification still shows.',
              ),
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
              t('Save'),
              run: true,
              onPressed: () => Navigator.of(context).pop(value),
            ),
            const SizedBox(height: 10),
            AppButton.secondary(
              t('Play it'),
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
        (_me['full_name'] as String?) ?? (_me['email'] as String?) ?? t('You');
    final team = (_me['organization_name'] as String?)?.trim();
    final agency = responderAgencyLabel(widget.feed.agency);
    final bfp = widget.feed.isBfp;
    final powers = CoordinatorPowers.of(_me);
    final asked = switch (widget.feed.agency) {
      'police' => t('Police'),
      'medical' => t('Medical'),
      'barangay' => t('Barangay'),
      _ => t('Fire'),
    };
    const gap = SizedBox(height: 8);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabHeader(eyebrow: t('Account'), title: t('Profile')),
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
                    subtitle: t('Coordinator · {value}', {
                      'value': team == null || team.isEmpty
                          ? agency
                          : '$team, $agency',
                    }),
                  ),
                  gap,
                  ListRow(
                    leading: const IconPlate(AppIcons.shield),
                    title: powers.rejects
                        ? t('You can accept and reject')
                        : t('You can accept'),
                    subtitle: powers.rejects
                        ? t(
                            'Any agency can accept. Only Fire Volunteer and BFP '
                            'can reject.',
                          )
                        : t(
                            'Accepting acknowledges the Areas that ask for {asked}. Only Fire Volunteer and BFP can reject.',
                            {'asked': asked},
                          ),
                    chevron: true,
                    onTap: () => _push(PermissionsScreen(me: _me)),
                  ),
                  const SizedBox(height: 16),
                  SectionHeader(t('Alerts')),
                  const SizedBox(height: 12),
                  ListRow(
                    leading: const IconPlate(AppIcons.volumeUp),
                    title: t('Fire alert sound'),
                    subtitle: t(
                      'Rings in the app when a new Area asks for {asked}. With the app closed, Android\'s {asked2} alerts channel rings it.',
                      {'asked': asked, 'asked2': asked},
                    ),
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
                    title: t('Alert volume'),
                    subtitle: t('In the app only. At 0% it is quiet here.'),
                    trailing: RowValue(
                      '${((_volume ?? 1) * 100).round()}%',
                      color: pal.onBackground,
                    ),
                    onTap: _pickVolume,
                  ),
                  gap,
                  ListRow(
                    leading: const IconPlate(AppIcons.explore),
                    title: t('Map rotation'),
                    subtitle: t('Heading-up while moving, compass when still'),
                    trailing: RowValue(t('Hybrid'), color: pal.onBackground),
                  ),
                  const SizedBox(height: 16),
                  StaffAccountSection(api: widget.feed.api, me: _me),
                  const SizedBox(height: 16),
                  SectionHeader(t('More')),
                  const SizedBox(height: 12),
                  ListRow(
                    leading: const IconPlate(AppIcons.history),
                    title: t('My decisions'),
                    subtitle: t(
                      'Every accept, reject, merge and fire out you made',
                    ),
                    chevron: true,
                    onTap: () => _push(MyDecisionsScreen(feed: widget.feed)),
                  ),
                  gap,
                  ListRow(
                    leading: const IconPlate(AppIcons.group),
                    title: t('Responders'),
                    subtitle: t("Make and manage your responders' accounts"),
                    chevron: true,
                    onTap: () => _push(TeamScreen(me: _me)),
                  ),
                  // The server keeps AI summaries to the coordinators who run
                  // the response (ai.py: assert_coordinator).
                  if (powers.coordinates) ...[
                    gap,
                    ListRow(
                      leading: const IconPlate(AppIcons.autoAwesome),
                      title: t('AI summaries'),
                      subtitle: t(
                        'What each fire your teams filed for came to',
                      ),
                      chevron: true,
                      onTap: () => _push(AiSummariesScreen(me: _me)),
                    ),
                  ],
                  if (bfp) ...[
                    gap,
                    ListRow(
                      leading: const IconPlate(AppIcons.campaign),
                      title: t('Alarm requests'),
                      subtitle: t('Fire Volunteer asks to raise the alarm'),
                      chevron: true,
                      onTap: () => _push(const BfpAlarmRequestsScreen()),
                    ),
                  ],
                  gap,
                  ListRow(
                    leading: const IconPlate(AppIcons.notifications),
                    title: t('Alerts'),
                    subtitle: t('Every notification sent to you'),
                    chevron: true,
                    onTap: () => _push(const NotificationsScreen()),
                  ),
                  if (AppUpdates.supported) ...[
                    gap,
                    ListRow(
                      leading: const IconPlate(AppIcons.download),
                      title: t('Check for updates'),
                      subtitle: AppVersion.label.isEmpty
                          ? t('Get the newest version of RepLiT')
                          : t('Version {label} installed', {
                              'label': AppVersion.label,
                            }),
                      chevron: true,
                      onTap: () => showUpdateSheet(context),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AppButton.danger(
                    t('Log out'),
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
        eyebrow: t('Coordinator · {responderAgencyLabel}', {
          'responderAgencyLabel': responderAgencyLabel(
            me['agency_type'] as String?,
          ),
        }),
        can: [
          (
            t('Accept an Area'),
            t(
              'Acknowledges it for your organization when it asks for your '
              'agency',
            ),
          ),
          (t('Merge or keep separate'), t('When two Areas overlap')),
          (
            t('Follow an Area on LIVE and the map'),
            t('Its units and its alarm level'),
          ),
          (t('Route to an Area'), t('Directions, once it has been accepted')),
          (t("Make your responders' accounts"), t('Under Profile, Responders')),
        ],
        cannot: [
          (t('Reject an Area'), t('Fire Volunteer and BFP coordinators')),
          (t('Respond or mark fire out'), t('Fire Volunteer and BFP')),
          (t('Press fire codes'), t('Fire Volunteer and BFP coordinators')),
          (t('File the post-incident report'), t('The responding fire team')),
          (t('Change the alarm level'), t('BFP coordinators only')),
        ],
      );
    }
    final can = <(String, String)>[
      (
        t('Accept an Area'),
        t(
          'Verifies it — and puts you on the way, on your unit, if you are '
          'going too',
        ),
      ),
      (t('Reject an Area'), t('Fire Volunteer and BFP coordinators only')),
      (t('Merge or keep separate'), t('When two Areas overlap')),
      (
        t('Mark fire out'),
        t('Your units stand down and stop sharing location'),
      ),
      (t('Press fire codes'), t('Recorded as events on the incident')),
      (
        t('File the post-incident report'),
        t('Once per Area for your team, no draft'),
      ),
      (t("Make your responders' accounts"), t('Under Profile, Responders')),
      if (bfp)
        (
          t('Raise the alarm level'),
          t('From the alarm requests Fire Volunteer sends'),
        )
      else
        (t('Ask BFP to raise the alarm'), t('From the alarm level on LIVE')),
    ];
    final cannot = <(String, String)>[
      if (!bfp) (t('Change the alarm level'), t('BFP coordinators only')),
      (t('Edit a filed report'), t('A post-incident report saves once')),
      (t('Reopen a rejected Area'), t('It has left the live feed for good')),
    ];
    return CapabilitiesScreen(
      eyebrow: t('Coordinator · {responderAgencyLabel}', {
        'responderAgencyLabel': responderAgencyLabel(
          me['agency_type'] as String?,
        ),
      }),
      can: can,
      cannot: cannot,
    );
  }
}
