import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/push_service.dart';
import '../sound/sound_cues.dart';
import '../theme.dart';
import '../widgets/design.dart';

/// Notification settings — toggle emergency/neighborhood alerts on or off (which
/// registers/unregisters this device with the backend) and send a test push.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final ApiClient _api = ApiClient();

  bool _enabled = true;
  bool _busy = false;
  bool _testing = false;
  bool _reportSound = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await PushService.instance.isEnabled();
    final sound = await SoundCues.instance.reportSentEnabled();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _reportSound = sound;
      });
    }
  }

  Future<void> _toggleReportSound(bool value) async {
    setState(() => _reportSound = value);
    await SoundCues.instance.setReportSentEnabled(value);
    // Let the resident hear what they just turned on.
    if (value) SoundCues.instance.playReportSent();
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _enabled = value;
      _busy = true;
    });
    await PushService.instance.setEnabled(value);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _sendTest() async {
    setState(() => _testing = true);
    try {
      final message = await _api.sendTestPush();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send a test notification.')),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              const SizedBox(height: 24),
              _toggleCard(),
              const SizedBox(height: 12),
              _soundCard(),
              const SizedBox(height: 16),
              _testButton(),
              const SizedBox(height: 20),
              _note(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const BackWell(),
        const SizedBox(width: 16),
        Text('Notifications'.toUpperCase(), style: AppText.screenTitle),
      ],
    );
  }

  Widget _toggleCard() {
    return Panel(
      padding: const EdgeInsets.all(18),
      color: AppColors.glassDim,
      child: Row(
        children: [
          const IconWell(
            tint: AppColors.accent,
            icon: Icons.notifications_active_outlined,
            size: 44,
            glyph: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'EMERGENCY ALERTS',
                  style: AppText.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Get alerted about incidents reported near you.',
                  style: AppText.meta.copyWith(height: 15 / 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(value: _enabled, onChanged: _busy ? null : _toggle),
        ],
      ),
    );
  }

  /// The "salamat!" cue when a report goes through (v10 §2.8).
  Widget _soundCard() {
    return Panel(
      padding: const EdgeInsets.all(18),
      color: AppColors.glassDim,
      child: Row(
        children: [
          const IconWell(
            tint: AppColors.ok,
            icon: Icons.volume_up_outlined,
            size: 44,
            glyph: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'REPORT SENT SOUND',
                  style: AppText.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'A short “salamat!” when your report reaches responders.',
                  style: AppText.meta.copyWith(height: 15 / 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(value: _reportSound, onChanged: _toggleReportSound),
        ],
      ),
    );
  }

  Widget _testButton() => AppButton.secondary(
    'Send test notification',
    busy: _testing,
    onPressed: (_enabled && !_testing) ? _sendTest : null,
  );

  Widget _note() {
    return Panel(
      radius: AppRadius.control,
      color: AppColors.glassDim,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Turning alerts off unregisters this device, so nearby-incident '
              'notifications stop until you turn it back on. Alerts still '
              'appear in the inbox.',
              style: AppText.meta.copyWith(height: 16 / 11),
            ),
          ),
        ],
      ),
    );
  }
}
