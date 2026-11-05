import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/push_service.dart';
import '../theme.dart';
import '../widgets/design.dart';
import '../widgets/app_icons.dart';
import '../i18n/i18n.dart';

/// Notification settings — toggle emergency/neighborhood alerts on or off (which
/// registers/unregisters this device with the backend) and send a test push.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final ApiClient _api = ApiClient();

  bool _enabled = true;
  bool _busy = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await PushService.instance.isEnabled();
    if (mounted) setState(() => _enabled = enabled);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('Could not send a test notification.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              const SizedBox(height: 24),
              _toggleCard(),
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
        Text(t('Notifications').toUpperCase(), style: context.type.screenTitle),
      ],
    );
  }

  Widget _toggleCard() {
    return Panel(
      padding: const EdgeInsets.all(18),
      color: context.pal.glassDim,
      child: Row(
        children: [
          IconWell(
            tint: context.pal.accent,
            icon: AppIcons.notificationsActive,
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
                  t('EMERGENCY ALERTS'),
                  style: context.type.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  t('Get alerted about incidents reported near you.'),
                  style: context.type.meta.copyWith(height: 15 / 11),
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

  Widget _testButton() => AppButton.secondary(
    t('Send test notification'),
    busy: _testing,
    onPressed: (_enabled && !_testing) ? _sendTest : null,
  );

  Widget _note() {
    return Panel(
      radius: AppRadius.control,
      color: context.pal.glassDim,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.info, size: 16, color: context.pal.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t(
                'Turning alerts off unregisters this device, so nearby-incident '
                'notifications stop until you turn it back on. Alerts still '
                'appear in the inbox.',
              ),
              style: context.type.meta.copyWith(height: 16 / 11),
            ),
          ),
        ],
      ),
    );
  }
}
