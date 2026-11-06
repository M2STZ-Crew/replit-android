import 'package:flutter/material.dart';

import '../../app_version.dart';
import '../../navigation/voice_guide.dart';
import '../../sound/sound_cues.dart';
import '../../theme.dart';
import '../../updates/app_updates.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/staff_account_section.dart';
import '../../widgets/staff_shell.dart';
import 'responder_feed.dart';
import 'responder_status.dart';
import '../../i18n/i18n.dart';

/// Profile (REPLIT (MAIN) 07 · R13): who you are and which unit, the sounds
/// and voice of a run, and what you can do.
///
/// R13's "Affiliate registration" opens a registration page whose URL does
/// not exist yet; it stays on standby, so it is not drawn.
class ResponderProfileTab extends StatefulWidget {
  const ResponderProfileTab({super.key, required this.feed, this.voice});

  final ResponderFeed feed;
  final VoiceGuide? voice;

  @override
  State<ResponderProfileTab> createState() => _ResponderProfileTabState();
}

class _ResponderProfileTabState extends State<ResponderProfileTab> {
  final SoundCues _sound = SoundCues.instance;
  late final VoiceGuide _voice = widget.voice ?? VoiceGuide();
  bool? _alarmOn;

  Map<String, dynamic> get _me => widget.feed.me;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      await _voice.load();
      final on = await _sound.fireAlarmEnabled();
      if (mounted) setState(() => _alarmOn = on);
    } catch (_) {
      // The rows show the defaults.
    }
  }

  Future<void> _setAlarm(bool on) async {
    setState(() => _alarmOn = on);
    await _sound.setFireAlarmEnabled(on);
  }

  void _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  /// R14 — what a responder may do. The server enforces every line.
  Widget _capabilities() {
    final agency = widget.feed.agency;
    final fire = isFireCrew(agency);
    return CapabilitiesScreen(
      eyebrow: t('Responder · {agencyLabel}', {
        'agencyLabel': agencyLabel(agency),
      }),
      can: [
        (
          t('Go to an Area'),
          t('I am going — verifies it if it is still Reported'),
        ),
        (t('Verify an Area'), t('Without going, while it is still Reported')),
        (t('Choose your route'), t('Up to three, all passable by a truck')),
        (t('Mark arrived'), t('Or arrive on your own when you reach the Area')),
        (
          t('Share your position on a run'),
          t('Every 5 seconds, from going to fire out'),
        ),
        if (fire)
          (t('Call for water or help'), t('A code to command and every unit')),
        if (mayRequestAlarm(agency))
          (t('Ask BFP to raise the alarm'), t('BFP sets the level')),
      ],
      cannot: [
        (t('Reject an Area'), t('Coordinators only')),
        (t('Mark fire out'), t('The Captain on scene')),
        (
          t('File the post-incident report'),
          t('The Captain files for the whole team'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final name =
        (_me['full_name'] as String?) ?? (_me['email'] as String?) ?? t('You');
    final agency = agencyLabel(widget.feed.agency);
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
                    subtitle: t('Responder — {agency}, {unit}', {
                      'agency': agency,
                      'unit': widget.feed.unit,
                    }),
                  ),
                  const SizedBox(height: 16),
                  SectionHeader(t('Settings')),
                  const SizedBox(height: 12),
                  ListRow(
                    leading: const IconPlate(AppIcons.volumeUp),
                    title: t('Incident sounds'),
                    subtitle: t(
                      'A longer alert when an Area asks for your agency',
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
                  ValueListenableBuilder<bool>(
                    valueListenable: _voice.enabled,
                    builder: (context, on, _) => ListRow(
                      leading: const IconPlate(AppIcons.recordVoiceOver),
                      title: t('Voice directions'),
                      subtitle: t('Spoken turn-by-turn on runs'),
                      trailing: Switch(
                        value: on,
                        onChanged: (v) => _voice.setEnabled(v),
                      ),
                      onTap: () => _voice.setEnabled(!on),
                    ),
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
                    leading: const IconPlate(AppIcons.info),
                    title: t('What you can do'),
                    subtitle: t('Your actions as a Responder'),
                    chevron: true,
                    onTap: () => _push(_capabilities()),
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
