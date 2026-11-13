import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/report_queue.dart';
import '../api/session.dart';
import '../api/web_only.dart';
import '../theme.dart';
import 'call_screen.dart';
import 'coordinator/coordinator_shell.dart';
import 'login_screen.dart';
import '../models/active_report.dart';
import 'map_screen.dart';
import 'report_status_screen.dart';
import 'phone_verify_screen.dart';
import 'responder/responder_shell.dart';
import '../tutorial/lit_tutorial_state.dart';
import '../tutorial/practice.dart';
import '../widgets/staff_shell.dart';
import '../widgets/app_icons.dart';
import '../widgets/launch_mark.dart';
import '../widgets/loading.dart';
import '../i18n/i18n.dart';

/// Decides which home screen to show after authentication, based on the user's
/// role from GET /auth/me: response_team → the responder console; a
/// coordinator (sub-admin) of any organisation → the coordinator app (PRD v14
/// §4.6: there is no Observer tier, and no web console for them to go to);
/// everyone else → the citizen app — once their phone is verified.
///
/// The phone gate: the server refuses a resident account that has not verified
/// a mobile number, so the app shows the verification screen first rather than
/// a map full of errors. It asks the server (`phone_verification_required` on
/// /auth/me) instead of deciding for itself, so switching the gate off on the
/// server lets everyone through without a new build.
///
/// The citizen app now opens on the map, not the SOS dial. That is the v2
/// design's arrangement: residents open the app to see what is happening, and
/// the SOS is one tap away on a coral button that floats over the map — a
/// bigger, more findable target than a quarter of the tab bar.
class RoleGate extends StatefulWidget {
  const RoleGate({super.key, this.initialMe});

  /// The account as the splash already loaded it (GET /auth/me), so opening
  /// the app goes straight to home. Null right after signing in: then the
  /// account loads here, over the skeleton.
  final Map<String, dynamic>? initialMe;

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _me;
  String? _error;

  /// The account is taking a while: say why, and offer the hotlines.
  bool _slow = false;
  Timer? _slowTimer;

  /// An Admin's account is being signed out of the app (WebOnly).
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _me = widget.initialMe;
    if (_me == null) {
      _load();
    } else {
      _warm(_me!);
    }
  }

  /// A resident's verification, read now and kept (ApiCache), so Profile
  /// opens with it the first time too (v1.12.42).
  void _warm(Map<String, dynamic> me) {
    final role = me['role'];
    if (role == 'response_team' || role == 'sub_admin' || WebOnly.account(me)) {
      return;
    }
    unawaited(_api.getVerificationStatus().then((_) {}, onError: (_) {}));
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _slow = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(ApiClient.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
    try {
      final me = await _api.getMe().timeout(ApiClient.signInTimeout);
      // The account's language, as the console or another phone left it.
      await LanguageChoice.adopt(me['language']);
      if (mounted) setState(() => _me = me);
      _warm(me);
    } on SessionExpiredException {
      // The stored session was too old to renew. The client has already cleared
      // it, so send the user to sign in rather than showing an error whose only
      // button re-sends the same dead token.
      await _signInAgain();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = frozenOrganization(e)
            ? (e as ApiException).message
            : t('Could not load your account.'),
      );
    } finally {
      _slowTimer?.cancel();
    }
  }

  /// No account yet, and maybe no signal: the hotlines need neither.
  Widget _hotlinesLink() => TextButton(
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CallScreen(guest: true)),
    ),
    child: Text(
      t('Emergency hotlines'),
      style: TextStyle(color: context.pal.accent, fontWeight: FontWeight.w700),
    ),
  );

  /// An Admin account: sign it out and say where it works (WebOnly).
  Future<void> _leaveForWeb() async {
    await WebOnly.signOut(_api);
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(notice: WebOnly.message)),
      (route) => false,
    );
  }

  /// Drop whatever is stored and start again at the login screen.
  ///
  /// Also offered on an ordinary failure, so a resident is never cornered on
  /// this screen. Before this, an unrecoverable state here could only be
  /// escaped by clearing the app's data from Android settings — which is not
  /// something to ask of someone with a fire to report.
  Future<void> _signInAgain() async {
    await Session.instance.clear();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _shell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.cloudOff, color: context.pal.muted, size: 40),
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: context.pal.muted)),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _load,
              child: Text(
                t('Retry'),
                style: TextStyle(
                  color: context.pal.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: _signInAgain,
              child: Text(
                t('Sign in again'),
                style: TextStyle(color: context.pal.muted),
              ),
            ),
            _hotlinesLink(),
          ],
        ),
      );
    }
    final me = _me;
    if (me == null) {
      return _shell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Where the home screen's rows will be, while the account loads.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: const LoadingInline(),
              ),
            ),
            if (_slow) ...[
              const SizedBox(height: 18),
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    t(
                      'Still connecting. RepLiT can take up to a minute to wake '
                      'after a quiet spell.',
                    ),
                    textAlign: TextAlign.center,
                    style: context.type.caption.copyWith(
                      color: context.pal.label,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _hotlinesLink(),
            ],
          ],
        ),
      );
    }
    if (WebOnly.account(me)) {
      // Never the residents' app for an Admin: off to the web console.
      if (!_leaving) {
        _leaving = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _leaveForWeb());
      }
      return _shell(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: const LoadingInline(),
          ),
        ),
      );
    }
    final role = me['role'] as String?;
    // Responders work from the Responder app (REPLIT (MAIN) 07): Duty, Map,
    // RUN, Alerts, Profile, on the same bar and disc as every role.
    if (role == 'response_team') {
      StaffAccount.current = me;
      return ResponderShell(me: me);
    }
    if (role == 'sub_admin') {
      StaffAccount.current = me;
      // Every organisation's coordinators work from the Coordinator
      // Experience (REPLIT (MAIN) 06): Queue, Map, LIVE, Codes, Profile — a
      // PNP Coordinator's is C01P. What each may do there is the server's
      // (CoordinatorPowers); BFP's alarm requests sit under Profile and on
      // LIVE's alarm level.
      return CoordinatorShell(me: me);
    }
    if (me['phone_verification_required'] == true) {
      return PhoneVerifyScreen(
        gate: true,
        initialPhone: (me['mobile'] as String?) ?? (me['phone'] as String?),
        onVerified: () {
          setState(() => _me = null);
          _load();
        },
      );
    }
    return const _CitizenEntry();
  }

  Widget _shell({required Widget child}) {
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LaunchMark.image(context, semanticLabel: 'RepLiT'),
              const SizedBox(height: 28),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// The resident's way in: the map, always the first frame. Over it, their
/// report in progress if they have one, and otherwise, once, the LIT
/// tutorial (12 November 2026, in place of the old tour, which came before
/// the map).
class _CitizenEntry extends StatelessWidget {
  const _CitizenEntry();

  @override
  Widget build(BuildContext context) => const _ResumeReport(child: MapScreen());
}

/// Opens the resident's report in progress over the map, if they have one.
///
/// Over the map rather than instead of it, so Back from the report is the map
/// — the app's home — and not the end of the app.
///
/// With none, it offers the LIT tutorial: once for each Citizen account
/// (those who saw the old tour too), and only on an idle home — never over a
/// report in progress, one waiting to send, or anything open over the map.
class _ResumeReport extends StatefulWidget {
  const _ResumeReport({required this.child});

  final Widget child;

  @override
  State<_ResumeReport> createState() => _ResumeReportState();
}

class _ResumeReportState extends State<_ResumeReport> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // The phone's record, or the server's for a report this phone lost
      // track of — a reinstall, cleared data, a second phone.
      final report =
          ActiveReportStore.mine ?? await ActiveReportStore.recover();
      if (!mounted) return;
      if (report != null) {
        if (!ReportStatusScreen.isShowing) {
          ReportStatusScreen.open(context, report);
        }
        return;
      }
      await _offerTutorial();
    });
  }

  Future<void> _offerTutorial() async {
    final account = Session.instance.email;
    if (account == null || !await LitTutorial.shouldOffer(account)) return;
    if (!mounted) return;
    final idle =
        ActiveReportStore.mine == null &&
        ReportQueue.instance.pending.value.isEmpty &&
        !ReportStatusScreen.isShowing &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (idle) await LitPractice.open(context, account: account);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
