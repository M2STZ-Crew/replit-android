import 'package:flutter/material.dart';

import '../../navigation/voice_guide.dart';
import '../../sound/sound_cues.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/staff_shell.dart';
import 'responder_feed.dart';
import 'responder_status.dart';

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
      eyebrow: 'Responder · ${agencyLabel(agency)}',
      can: [
        ('Go to an Area', 'I am going — verifies it if it is still Reported'),
        ('Verify an Area', 'Without going, while it is still Reported'),
        ('Choose your route', 'Up to three, all passable by a truck'),
        ('Mark arrived', 'Or arrive on your own when you reach the Area'),
        (
          'Share your position on a run',
          'Every 5 seconds, from going to fire out',
        ),
        if (fire)
          ('Call for water or help', 'A code to command and every unit'),
        if (mayRequestAlarm(agency))
          ('Ask BFP to raise the alarm', 'BFP sets the level'),
      ],
      cannot: const [
        ('Reject an Area', 'Coordinators only'),
        ('Mark fire out', 'The Captain on scene'),
        (
          'File the post-incident report',
          'The Captain files for the whole team',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final name =
        (_me['full_name'] as String?) ?? (_me['email'] as String?) ?? 'You';
    final agency = agencyLabel(widget.feed.agency);
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
                    subtitle: 'Responder — $agency, ${widget.feed.unit}',
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader('Settings'),
                  const SizedBox(height: 12),
                  ListRow(
                    leading: const IconPlate(AppIcons.volumeUp),
                    title: 'Incident sounds',
                    subtitle:
                        'A longer alert when an Area asks for your agency',
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
                      title: 'Voice directions',
                      subtitle: 'Spoken turn-by-turn on runs',
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
                    title: 'Map rotation',
                    subtitle: 'Heading-up while moving, compass when still',
                    trailing: RowValue('Hybrid', color: pal.onBackground),
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader('More'),
                  const SizedBox(height: 12),
                  ListRow(
                    leading: const IconPlate(AppIcons.info),
                    title: 'What you can do',
                    subtitle: 'Your actions as a Responder',
                    chevron: true,
                    onTap: () => _push(_capabilities()),
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
