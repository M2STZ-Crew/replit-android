import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../api/web_only.dart';
import '../models/phone_numbers.dart';
import '../models/ph_mobile.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'call_screen.dart';
import 'register_screen.dart';
import 'role_gate.dart';
import '../widgets/app_icons.dart';
import '../i18n/i18n.dart';

/// "02 Sign in" from the REPLIT-OVERHAUL Figma.
///
/// Email + password first (WHAT'S NEXT, 2.2): every account has an email, and
/// mobile numbers wait for an SMS provider. Until then "Use mobile number" is
/// greyed out, "Coming soon"; with [PhoneNumbers.open] it switches to a
/// verified number, the only kind the server accepts. The overhaul dropped
/// v2's "Keep session active" box: a reporter who is signed out at 2am is a
/// reporter who cannot send, so the session is always kept.
/// The line that matters most stays — hotlines work while you are locked out —
/// and now it is a button: the same hotlines, with no account and no signal.
///
/// The server sleeps after a quiet spell and takes about half a minute to wake,
/// which is the delay people see at sign-in. So the screen starts waking it as
/// it opens, while they type, and says what is happening if they still wait.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.api, this.openLink, this.notice});

  final ApiClient? api;

  /// Said as the screen opens: why the person is back here (an Admin
  /// account, which signs in on the web: WebOnly).
  final String? notice;

  /// Opens a page in the phone's browser; a test's stand-in.
  final Future<bool> Function(Uri uri)? openLink;

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

  /// Signing in by email, the first way; by number once [PhoneNumbers.open].
  bool _byEmail = true;

  @override
  void initState() {
    super.initState();
    unawaited(_api.wakeServer());
    final notice = widget.notice;
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showError(notice, long: true);
      });
    }
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
      // An Admin works in the web console, not here: refused before its
      // session is kept or its phone registered for pushes (WebOnly).
      Map<String, dynamic>? me;
      try {
        me = await _api.getMe().timeout(ApiClient.signInTimeout);
      } catch (_) {
        // RoleGate loads the account again, and refuses an Admin there.
      }
      if (WebOnly.account(me)) {
        await WebOnly.signOut(_api);
        _showError(WebOnly.message, long: true);
        return;
      }
      if (me != null) {
        // The account's language, as the console or another phone left it.
        await LanguageChoice.adopt(me['language']);
      }
      await Session.instance.persist();
      unawaited(PushService.instance.syncForUser());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RoleGate(initialMe: me)),
      );
    } on ApiException catch (e) {
      _showError(
        e.statusCode == 401 && e.message == 'Invalid login credentials'
            ? (_byEmail
                  ? t('Wrong email or password.')
                  : t(
                      'Wrong mobile number or password. Not verified your '
                      'number yet? Use your email instead.',
                    ))
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

  /// "Want to be an affiliate?": the Admin console's public affiliation
  /// form, in the phone's browser (8 November).
  Future<void> _registerAffiliate() async {
    final url = Uri.parse(ApiConfig.affiliateRegisterUrl);
    var opened = false;
    try {
      opened = await (widget.openLink ?? _openInBrowser)(url);
    } catch (_) {
      // No browser to hand it to: say where it is instead.
    }
    if (!opened && mounted) {
      _showError(
        t('Could not open the page. Visit {url}.', {
          'url': '${url.host}${url.path}',
        }),
      );
    }
  }

  static Future<bool> _openInBrowser(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// [long]: a message to read and act on (an Admin sent to the web),
  /// shown for longer than a typing mistake.
  void _showError(String message, {bool long = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.pal.live,
        duration: long
            ? const Duration(seconds: 10)
            : const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _recoverDialog() async {
    final controller = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showAppDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(t('RESET PASSWORD'), style: context.type.screenTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(
                "Enter the email you sign in with, or a staff account's "
                "personal email, and we'll send a reset link.",
              ),
              style: context.type.body,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              style: context.type.input,
              decoration: InputDecoration(hintText: t('you@email.com')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              t('CANCEL'),
              style: TextStyle(color: context.pal.muted),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(controller.text.trim()),
            child: Text(
              t('SEND LINK'),
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
        // The sign-up lines sit at the foot, as in the frame. The room above
        // the title gives way first on a shorter screen or with a larger
        // font, so the page fits without scrolling (8 November); it scrolls
        // only when the keyboard or a very large font leaves no room.
        child: FootedScroll(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          gap: 16,
          // With room to spare the title sits 120 down, as in the frame.
          topRoom: 104,
          content: [
            const SizedBox(height: 16),
            Text(t('WELCOME BACK'), style: context.type.display),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 306,
                child: Text(
                  t(
                    'Sign in so responders know who is reporting and '
                    'where to find you.',
                  ),
                  style: context.type.body,
                ),
              ),
            ),
            const SizedBox(height: 32),
            LabeledField(
              key: ValueKey(_byEmail),
              label: _byEmail ? t('Email address') : t('Mobile number'),
              builder: (focus) => _byEmail
                  ? TextField(
                      controller: _emailCtrl,
                      focusNode: focus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      style: context.type.input,
                      decoration: InputDecoration(hintText: t('you@email.com')),
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
              label: t('Password'),
              builder: (focus) => TextField(
                controller: _passwordCtrl,
                focusNode: focus,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                style: context.type.input,
                decoration: InputDecoration(
                  hintText: t('Your password'),
                  suffixIcon: IconButton(
                    iconSize: 18,
                    color: context.pal.muted,
                    tooltip: _obscure ? t('Show password') : t('Hide password'),
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
                if (PhoneNumbers.open)
                  TextLink(
                    _byEmail ? t('Use mobile number') : t('Use email instead'),
                    onTap: () => setState(() => _byEmail = !_byEmail),
                  )
                else
                  const _MobileComingSoon(),
                TextLink(t('Forgot password?'), onTap: _recoverDialog),
              ],
            ),
            const SizedBox(height: 18),
            AppButton(
              t('Sign in'),
              height: 54,
              busy: _loading,
              onPressed: _loading ? null : _submit,
            ),
            if (_slow) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  t(
                    'Still signing in. RepLiT can take up to a minute to wake '
                    'after a quiet spell.',
                  ),
                  style: context.type.caption.copyWith(
                    color: context.pal.label,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            AppButton.secondary(
              t('Emergency hotlines'),
              icon: AppIcons.call,
              onPressed: _hotlines,
            ),
            const SizedBox(height: 12),
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
                      t(
                        'Locked out or offline? Hotlines need no account and '
                        'no internet.',
                      ),
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
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(t('New to the app?'), style: context.type.detail),
                  TextLink(
                    t('Create account').toUpperCase(),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                  ),
                ],
              ),
              // An organisation applies to join in the Admin console.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    t('Want to be an affiliate?'),
                    style: context.type.detail,
                  ),
                  TextLink(
                    t('Register here').toUpperCase(),
                    onTap: _registerAffiliate,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Use mobile number", greyed out, with "Coming soon": where the way to
/// sign in by number goes once SMS is settled ([PhoneNumbers]).
class _MobileComingSoon extends StatelessWidget {
  const _MobileComingSoon();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: t('Use mobile number'),
      hint: t('Coming soon'),
      enabled: false,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          // Wrap: at a large font scale the tag goes under the words
          // rather than off the edge.
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                t('Use mobile number'),
                style: context.type.label.copyWith(color: context.pal.muted),
              ),
              const ComingSoon(),
            ],
          ),
        ),
      ),
    );
  }
}
