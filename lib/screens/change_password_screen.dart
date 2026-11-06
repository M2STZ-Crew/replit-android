import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../i18n/i18n.dart';
import '../theme.dart';
import '../widgets/design.dart';

/// Change password (WHAT'S NEXT, 1.2), from Profile for residents and staff
/// alike: the current password, the new one twice. The server checks the
/// current one and signs out every other phone and browser; this one stays
/// signed in, and the screen says so.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.api});

  final ApiClient? api;

  /// Opens the screen; true once the password has changed.
  static Future<bool?> open(BuildContext context, {ApiClient? api}) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ChangePasswordScreen(api: api)),
      );

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = _current.text;
    final next = _next.text;
    String? error;
    if (current.isEmpty) {
      error = t('Enter your current password.');
    } else if (next.length < 8 || next.length > 128) {
      error = t('Use 8 to 128 characters for the new password.');
    } else if (next != _again.text) {
      error = t('The two new passwords are not the same.');
    } else if (next == current) {
      error = t('The new password is the same as the current one.');
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.changePassword(current: current, next: next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Password changed. Other phones and browsers are signed out; '
              'this one stays signed in.',
            ),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on SessionExpiredException catch (e) {
      // The session ended: say so, rather than blame the password.
      if (mounted) setState(() => _error = e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = switch (e.code) {
          'wrong_password' => t('That is not your current password.'),
          'same_password' => t(
            'The new password is the same as the current one.',
          ),
          _ when e.statusCode == 422 => t(
            'Use 8 to 128 characters for the new password.',
          ),
          _ => t('The password could not be changed. Try again.'),
        },
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = t('The password could not be changed. Try again.'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    required String hint,
    required List<String> autofill,
    TextInputAction action = TextInputAction.next,
  }) {
    return LabeledField(
      label: label,
      builder: (focus) => TextField(
        controller: controller,
        focusNode: focus,
        obscureText: !_show,
        enabled: !_busy,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: action,
        autofillHints: autofill,
        onSubmitted: action == TextInputAction.done ? (_) => _save() : null,
        style: context.type.input,
        decoration: InputDecoration(hintText: hint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: FootedScroll(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          content: [
            const Align(alignment: Alignment.centerLeft, child: BackWell()),
            const SizedBox(height: 28),
            Text(t('CHANGE PASSWORD'), style: context.type.display),
            const SizedBox(height: 8),
            Text(
              t(
                'Changing it signs you out of RepLiT on your other phones and '
                'browsers. This phone stays signed in.',
              ),
              style: context.type.body,
            ),
            const SizedBox(height: 32),
            _field(
              t('Current password'),
              _current,
              hint: t('Your password'),
              autofill: const [AutofillHints.password],
            ),
            const SizedBox(height: 14),
            _field(
              t('New password'),
              _next,
              hint: t('At least 8 characters'),
              autofill: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 14),
            _field(
              t('New password again'),
              _again,
              hint: t('At least 8 characters'),
              autofill: const [AutofillHints.newPassword],
              action: TextInputAction.done,
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              value: _show,
              onChanged: (on) => setState(() => _show = on ?? false),
              title: Text(t('Show passwords'), style: context.type.label),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: context.type.caption.copyWith(color: context.pal.live),
                ),
              ),
            ],
          ],
          footer: AppButton(
            t('Change password'),
            height: 54,
            busy: _busy,
            onPressed: _busy ? null : _save,
          ),
        ),
      ),
    );
  }
}
