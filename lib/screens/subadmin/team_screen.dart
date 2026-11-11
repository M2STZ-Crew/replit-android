import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_client.dart';
import '../../theme.dart';
import '../../widgets/design.dart';
import '../../widgets/sheet_grip.dart';
import '../../widgets/staff_shell.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/loading.dart';
import '../../i18n/i18n.dart';

/// The coordinator's responder accounts (v1.12.4) — where a responder's
/// account comes from.
///
/// A coordinator makes the Response Team accounts of their own agency and
/// team. The address follows the account directory (first initial and
/// surname, `.res` and the agency: `jdelacruz.resfir@replit.com`, numbered
/// after the surname when taken) and is shown as the name is typed. The
/// password is generated and shown once, to hand over in person: @replit.com
/// has no mailboxes, so the coordinator is also where a forgotten password is
/// reset. Deactivating stops an account signing in and keeps its history.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key, this.me, this.api});

  final Map<String, dynamic>? me;
  final ApiClient? api;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  List<Map<String, dynamic>> _responders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _api.getTeamResponders();
      if (!mounted) return;
      setState(() {
        _responders = raw.cast<Map<String, dynamic>>();
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = t('Could not load your responders. Check your connection.');
        });
      }
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  // ------------------------------------------------------------ actions ---
  Future<void> _create() async {
    final made = await showAppSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.pal.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => _NewResponderSheet(api: _api),
    );
    if (made == null || !mounted) return;
    await _showCredentials(made, created: true);
    _load();
  }

  Future<void> _manage(Map<String, dynamic> r) async {
    final active = r['is_active'] != false;
    final action = await showAppSheet<String>(
      context: context,
      backgroundColor: context.pal.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SheetHandle()),
              Text(
                (r['full_name'] as String?) ?? t('Responder'),
                style: context.type.cardTitle,
              ),
              const SizedBox(height: 6),
              Text('${r['email']}', style: context.type.caption),
              const SizedBox(height: 20),
              if (active) ...[
                AppButton.secondary(
                  t('Reset password'),
                  icon: AppIcons.key,
                  height: 50,
                  onPressed: () => Navigator.of(sheet).pop('reset'),
                ),
                const SizedBox(height: 10),
                AppButton.danger(
                  t('Deactivate account'),
                  icon: AppIcons.block,
                  height: 50,
                  onPressed: () => Navigator.of(sheet).pop('deactivate'),
                ),
              ] else
                AppButton(
                  t('Reactivate account'),
                  icon: AppIcons.restartAlt,
                  height: 50,
                  onPressed: () => Navigator.of(sheet).pop('reactivate'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    final id = '${r['id']}';
    final name = (r['full_name'] as String?) ?? t('this responder');
    try {
      switch (action) {
        case 'reset':
          if (!await _confirm(
            t('Give {name} a new password?', {'name': name}),
            t(
              'Their current password stops working. You will see the new one '
              'once, to hand over.',
            ),
            t('New password'),
          )) {
            return;
          }
          final creds = await _api.resetResponderPassword(id);
          if (mounted) await _showCredentials(creds, created: false);
        case 'deactivate':
          if (!await _confirm(
            t('Deactivate {name}?', {'name': name}),
            r['responding'] == true
                ? t(
                    'They are on a response now; it will be released. They '
                    'will not be able to sign in. Their history stays.',
                  )
                : t(
                    'They will not be able to sign in. Their history stays, and '
                    'you can reactivate the account later.',
                  ),
            t('Deactivate'),
            danger: true,
          )) {
            return;
          }
          await _api.deactivateResponder(id);
          _toast(t('{name} can no longer sign in.', {'name': name}));
        case 'reactivate':
          await _api.reactivateResponder(id);
          _toast(
            t('{name} can sign in again with their last password.', {
              'name': name,
            }),
          );
      }
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast(t('Could not reach the server. Try again.'));
    }
    _load();
  }

  Future<bool> _confirm(
    String title,
    String body,
    String yes, {
    bool danger = false,
  }) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title, style: context.type.cardTitle),
        content: Text(body, style: context.type.bodySm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(
              t('Cancel'),
              style: context.type.label.copyWith(color: context.pal.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(
              yes,
              style: context.type.label.copyWith(
                color: danger ? context.pal.live : context.pal.accentInk,
              ),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _showCredentials(
    Map<String, dynamic> creds, {
    required bool created,
  }) {
    return showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CredentialsDialog(
        name:
            ((creds['responder'] as Map?)?['full_name'] as String?) ??
            'The responder',
        email: '${creds['email']}',
        password: creds['temporary_password'] as String?,
        personalEmail: creds['personal_email'] as String?,
        detail: creds['invite_email_sent'] == false
            ? creds['detail'] as String?
            : null,
        created: created,
      ),
    );
  }

  // -------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    return StaffScaffold(
      me: widget.me,
      page: StaffPage.team,
      home: true,
      title: t('Responders'),
      body: RefreshIndicator(
        color: context.pal.accent,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text(
              t(
                'Your responders sign in with the accounts you make here. Each '
                'gets a @replit.com address, and a link to set the password '
                'goes to their own email.',
              ),
              style: context.type.bodySm,
            ),
            const SizedBox(height: 16),
            AppButton(
              t('New responder'),
              icon: AppIcons.personAdd,
              onPressed: _create,
            ),
            const SizedBox(height: 22),
            ..._roster(),
          ],
        ),
      ),
    );
  }

  List<Widget> _roster() {
    if (_loading) {
      return const [SizedBox(height: 8), LoadingInline()];
    }
    if (_error != null) {
      return [
        Text(
          _error!,
          style: context.type.caption.copyWith(color: context.pal.live),
        ),
      ];
    }
    final active = _responders.where((r) => r['is_active'] != false).length;
    return [
      Row(
        children: [
          Expanded(
            child: Eyebrow(t('Your responders'), color: context.pal.accent),
          ),
          Eyebrow(
            t('{active} active', {'active': active}),
            color: context.pal.muted,
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_responders.isEmpty)
        Panel(
          child: Text(
            t(
              'No responder accounts yet. Make one for each person on your team.',
            ),
            style: context.type.bodySm,
          ),
        ),
      for (final r in _responders) ...[
        _ResponderRow(responder: r, onTap: () => _manage(r)),
        const SizedBox(height: 8),
      ],
    ];
  }
}

/// One responder: name, address, and whether they are on a run or switched off.
class _ResponderRow extends StatelessWidget {
  const _ResponderRow({required this.responder, required this.onTap});

  final Map<String, dynamic> responder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = responder['is_active'] != false;
    final responding = responder['responding'] == true;
    return Opacity(
      opacity: active ? 1 : 0.6,
      child: Panel(
        radius: AppRadius.card,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconWell(
              tint: active ? context.pal.accentInk : context.pal.muted,
              icon: AppIcons.person,
              size: 36,
              glyph: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (responder['full_name'] as String?) ?? t('Responder'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.rowTitleLg,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${responder['email']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!active)
              Tag(t('Deactivated'), color: context.pal.muted)
            else if (responding)
              Tag(t('On a run'), color: context.pal.accentInk, dot: true),
            Icon(AppIcons.chevronRight, color: context.pal.muted),
          ],
        ),
      ),
    );
  }
}

/// First name, surname, their own email — and the address it makes, live.
///
/// The 6 November list: the email replaces the mobile number. A link sent
/// there confirms it and sets the password, so there is no password to hand
/// over, and Forgot password? sends there later: @replit.com has no mailboxes.
class _NewResponderSheet extends StatefulWidget {
  const _NewResponderSheet({required this.api});

  final ApiClient api;

  @override
  State<_NewResponderSheet> createState() => _NewResponderSheetState();
}

class _NewResponderSheetState extends State<_NewResponderSheet> {
  final TextEditingController _first = TextEditingController();
  final TextEditingController _last = TextEditingController();
  final TextEditingController _email = TextEditingController();
  Timer? _debounce;
  String? _preview;
  bool _previewing = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _first.dispose();
    _last.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _ready =>
      _first.text.trim().isNotEmpty &&
      _last.text.trim().isNotEmpty &&
      _email.text.trim().isNotEmpty &&
      !_busy;

  /// The address as the name is typed — a moment after the last key.
  void _onName(String _) {
    setState(() {});
    _debounce?.cancel();
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _preview = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _fetchPreview);
  }

  Future<void> _fetchPreview() async {
    final first = _first.text.trim();
    final last = _last.text.trim();
    setState(() => _previewing = true);
    try {
      final email = await widget.api.previewResponderEmail(first, last);
      if (!mounted) return;
      // Only if the name has not changed while the answer was on its way.
      if (first == _first.text.trim() && last == _last.text.trim()) {
        setState(() {
          _preview = email;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      // The create works out the address itself; the preview is a courtesy.
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = t('Enter an email like name@gmail.com.'));
      return;
    }
    if (email.toLowerCase().endsWith('@replit.com')) {
      setState(
        () => _error = t(
          'Use their own email: @replit.com addresses have no mailbox.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final made = await widget.api.createResponder(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        personalEmail: email,
      );
      if (mounted) Navigator.of(context).pop(made);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = t('Could not reach the server.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        // The grabber stays put; the form scrolls under it.
        child: FrozenHandleSheet(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          handlePadding: const EdgeInsets.only(top: 12, bottom: 16),
          children: [
            Text(t('NEW RESPONDER'), style: context.type.headline),
            const SizedBox(height: 18),
            LabeledField(
              label: t('First name'),
              builder: (focus) => TextField(
                controller: _first,
                focusNode: focus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: _onName,
                style: context.type.input,
                decoration: InputDecoration(hintText: t('Juan')),
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: t('Surname'),
              builder: (focus) => TextField(
                controller: _last,
                focusNode: focus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: _onName,
                style: context.type.input,
                decoration: InputDecoration(hintText: t('Dela Cruz')),
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: t('Their personal email'),
              builder: (focus) => TextField(
                controller: _email,
                focusNode: focus,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                style: context.type.input,
                decoration: InputDecoration(hintText: t('name@gmail.com')),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t(
                'We email them a link to confirm it and set their password. '
                'If they forget it, the reset link goes there too.',
              ),
              style: context.type.caption,
            ),
            const SizedBox(height: 18),
            Panel(
              radius: AppRadius.card,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    AppIcons.alternateEmail,
                    size: 18,
                    color: context.pal.accentInk,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(t('Their sign-in'), color: context.pal.muted),
                        const SizedBox(height: 6),
                        Text(
                          _preview ??
                              (_previewing
                                  ? t('Working it out…')
                                  : t(
                                      'Made from the first initial and surname',
                                    )),
                          key: const ValueKey('email-preview'),
                          style: _preview == null
                              ? context.type.caption
                              : context.type.rowValue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: context.type.caption.copyWith(color: context.pal.live),
              ),
            ],
            const SizedBox(height: 18),
            AppButton(
              t('Create account'),
              busy: _busy,
              onPressed: _ready ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The address and how the password is set, with copy buttons: a link at
/// their personal email (new accounts), or a temporary password, once (a
/// reset, or an account made without a personal email).
class _CredentialsDialog extends StatelessWidget {
  const _CredentialsDialog({
    required this.name,
    required this.email,
    required this.password,
    required this.created,
    this.personalEmail,
    this.detail,
  });

  final String name;
  final String email;
  final String? password;
  final bool created;
  final String? personalEmail;

  /// Why the email to [personalEmail] did not go, when it did not.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final password = this.password;
    if (password == null) return _linkSent(context);
    return AlertDialog(
      title: Text(
        created ? t('Account ready') : t('New password'),
        style: context.type.headline,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            created
                ? t('Give {name} these to sign in with.', {'name': name})
                : t('Give {name} this password to sign in with.', {
                    'name': name,
                  }),
            style: context.type.bodySm,
          ),
          const SizedBox(height: 16),
          _CopyRow(label: t('Email'), value: email),
          const SizedBox(height: 10),
          _CopyRow(label: t('Password'), value: password),
          const SizedBox(height: 16),
          Text(
            t(
              'Hand these over in person. The password is shown only this '
              'once. You can give them a new one from this screen.',
            ),
            style: context.type.caption,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            t('Done'),
            style: context.type.label.copyWith(color: context.pal.accentInk),
          ),
        ),
      ],
    );
  }

  /// A new account with a personal email: where they sign in, and where the
  /// link went.
  Widget _linkSent(BuildContext context) {
    final to = personalEmail ?? '';
    return AlertDialog(
      title: Text(t('Account ready'), style: context.type.headline),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('{name} signs in with this address.', {'name': name}),
            style: context.type.bodySm,
          ),
          const SizedBox(height: 16),
          _CopyRow(label: t('Sign-in address'), value: email),
          const SizedBox(height: 16),
          Text(
            detail ??
                t(
                  'We emailed {to} a link to confirm it and set their '
                  'password. It works for three days.',
                  {'to': to},
                ),
            style: context.type.caption.copyWith(
              color: detail == null ? null : context.pal.warn,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            t('Done'),
            style: context.type.label.copyWith(color: context.pal.accentInk),
          ),
        ),
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppRadius.control,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(label, color: context.pal.muted),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: context.type.rowValue.copyWith(
                    fontFamily: 'monospace',
                    color: context.pal.onBackground,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t('Copy {label}', {'label': label}),
            icon: Icon(
              AppIcons.contentCopy,
              size: 18,
              color: context.pal.accentInk,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t('{label} copied.', {'label': label}))),
              );
            },
          ),
        ],
      ),
    );
  }
}
