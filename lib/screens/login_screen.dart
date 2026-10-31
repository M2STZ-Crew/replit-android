import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../models/ph_mobile.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'call_screen.dart';
import 'register_screen.dart';
import 'role_gate.dart';
import '../widgets/app_icons.dart';

/// "02 Sign in" from the REPLIT-OVERHAUL Figma.
///
/// Mobile number + password first: residents sign up with their number and
/// verify it by text, so it is what they remember. "Use email instead" is for
/// staff, whose accounts have no verified number, and for a resident who has
/// not verified theirs yet — the server accepts only a verified number. The
/// overhaul dropped v2's "Keep session active" box: a reporter who is signed
/// out at 2am is a reporter who cannot send, so the session is always kept.
/// The line that matters most stays — hotlines work while you are locked out —
/// and now it is a button: the same hotlines, with no account and no signal.
///
/// The server sleeps after a quiet spell and takes about half a minute to wake,
/// which is the delay people see at sign-in. So the screen starts waking it as
/// it opens, while they type, and says what is happening if they still wait.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.api});

  final ApiClient? api;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  /// Sign in has been spinning for a while: say why.
  bool _slow = false;
  Timer? _slowTimer;

  /// Signing in by email instead of by number.
  bool _byEmail = false;

  @override
  void initState() {
    super.initState();
    unawaited(_api.wakeServer());
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (_byEmail && email.isEmpty) {
      _showError('Please enter your email.');
      return;
    }
    if (!_byEmail && !looksLikePhMobile(phone)) {
      _showError('Enter your mobile number, like 0917 123 4567.');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter your password.');
      return;
    }
    setState(() => _loading = true);
    _slowTimer = Timer(ApiClient.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
    try {
      await _api.login(
        email: _byEmail ? email : null,
        phone: _byEmail ? null : phone,
        password: password,
      );
      await Session.instance.persist();
      unawaited(PushService.instance.syncForUser());
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const RoleGate()));
    } on ApiException catch (e) {
      _showError(
        e.statusCode == 401 && e.message == 'Invalid login credentials'
            ? (_byEmail
                  ? 'Wrong email or password.'
                  : 'Wrong mobile number or password. Not verified your '
                        'number yet? Use your email instead.')
            : e.message,
      );
    } on TimeoutException {
      _showError(
        'RepLiT did not answer in time. Check your signal and try again. '
        'Hotlines work without signing in.',
      );
    } catch (_) {
      _showError(
        'Could not reach RepLiT at ${ApiConfig.host}. Check your internet '
        'connection, then try again. If it keeps failing, install the latest '
        'version of the app.',
      );
    } finally {
      _slowTimer?.cancel();
      if (mounted) {
        setState(() {
          _loading = false;
          _slow = false;
        });
      }
    }
  }

  void _hotlines() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const CallScreen(guest: true)),
  );

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.pal.live),
    );
  }

  Future<void> _recoverDialog() async {
    final controller = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showAppDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('RESET PASSWORD', style: context.type.screenTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Enter your account email and we'll send a reset link.",
              style: context.type.body,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              style: context.type.input,
              decoration: const InputDecoration(hintText: 'you@email.com'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('CANCEL', style: TextStyle(color: context.pal.muted)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(controller.text.trim()),
            child: Text(
              'SEND LINK',
              style: TextStyle(
                color: context.pal.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    if (!email.contains('@') || !email.contains('.')) {
      _showError('Please enter a valid email address.');
      return;
    }
    try {
      final message = await _api.requestPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      _showError('Could not send the reset email. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        // The sign-up line sits at the foot, as in the frame, and the page
        // still scrolls when the keyboard or a large font scale takes the room.
        child: FootedScroll(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          content: [
            const SizedBox(height: 120),
            Text('WELCOME BACK', style: context.type.display),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 306,
                child: Text(
                  'Sign in so responders know who is reporting and '
                  'where to find you.',
                  style: context.type.body,
                ),
              ),
            ),
            const SizedBox(height: 42),
            LabeledField(
              key: ValueKey(_byEmail),
              label: _byEmail ? 'Email address' : 'Mobile number',
              builder: (focus) => _byEmail
                  ? TextField(
                      controller: _emailCtrl,
                      focusNode: focus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      style: context.type.input,
                      decoration: const InputDecoration(
                        hintText: 'you@email.com',
                      ),
                    )
                  : TextField(
                      controller: _phoneCtrl,
                      focusNode: focus,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: const [PhMobileFormatter()],
                      style: context.type.input,
                      decoration: const InputDecoration(
                        hintText: kPhMobileHint,
                      ),
                    ),
            ),
            const SizedBox(height: 15),
            LabeledField(
              label: 'Password',
              builder: (focus) => TextField(
                controller: _passwordCtrl,
                focusNode: focus,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                style: context.type.input,
                decoration: InputDecoration(
                  hintText: 'Your password',
                  suffixIcon: IconButton(
                    iconSize: 18,
                    color: context.pal.muted,
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    // The eye offers what a tap does: see it.
                    icon: Icon(
                      _obscure ? AppIcons.visibility : AppIcons.visibilityOff,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 11),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 4,
              children: [
                TextLink(
                  _byEmail ? 'Use mobile number' : 'Use email instead',
                  onTap: () => setState(() => _byEmail = !_byEmail),
                ),
                TextLink('Forgot password?', onTap: _recoverDialog),
              ],
            ),
            const SizedBox(height: 22),
            AppButton(
              'Sign in',
              height: 54,
              busy: _loading,
              onPressed: _loading ? null : _submit,
            ),
            if (_slow) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Still signing in. RepLiT can take up to a minute to wake '
                  'after a quiet spell.',
                  style: context.type.caption.copyWith(
                    color: context.pal.label,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            AppButton.secondary(
              'Emergency hotlines',
              icon: AppIcons.call,
              onPressed: _hotlines,
            ),
            const SizedBox(height: 16),
            Panel(
              radius: AppRadius.card,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Icon(
                    AppIcons.verifiedUser,
                    size: 18,
                    color: context.pal.accent,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Locked out or offline? Hotlines need no account and '
                      'no internet.',
                      style: context.type.caption.copyWith(
                        color: context.pal.label,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Wrap, not Row: the two halves of this line together are wider
          // than the screen at a large system font scale, and a sign-up link
          // that has run off the edge is a dead end for a new user.
          footer: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text('New to the barangay app?', style: context.type.detail),
              TextLink(
                'Create account',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
