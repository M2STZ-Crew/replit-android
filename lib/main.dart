import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'core/config/env.dart';
import 'core/constants/app_constants.dart';
import 'core/services/hive_service.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/notifications/presentation/providers/notification_provider.dart';
import 'features/notifications/presentation/providers/push_registration.dart';
import 'features/notifications/presentation/screens/notifications_screen.dart';
import 'features/reports/presentation/screens/my_reports_screen.dart';
import 'features/responder/presentation/screens/responder_home_screen.dart';
import 'features/reports/presentation/screens/sos_screen.dart';
import 'features/verification/presentation/screens/verification_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Startup is fallible — a missing .env or an unreachable Supabase project are
  // both normal on a fresh clone. Capture the failure and render it as a screen
  // the developer can read, instead of a red error box with no explanation.
  String? startupError;
  try {
    await dotenv.load(fileName: '.env');

    final missing = Env.missingKeys();
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing in .env: ${missing.join(', ')}.\n\n'
        'Copy .env.example to .env and fill in the values.',
      );
    }

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
    await HiveService.init();
    // Never fatal: PushService swallows a missing google-services.json and
    // reports isAvailable == false, leaving the in-app inbox working.
    await PushService.instance.init();
  } catch (error) {
    startupError = error.toString();
  }

  runApp(
    ProviderScope(
      child: RepLiTApp(startupError: startupError),
    ),
  );
}

class RepLiTApp extends StatelessWidget {
  const RepLiTApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: startupError != null
          ? _StartupErrorScreen(message: startupError!)
          : const _AuthGate(),
      // LoginScreen pushes '/register' by name. Without this the app throws
      // "Could not find a generator for route" the moment Register is tapped.
      // RegisterScreen pops back here on success and the gate takes over.
      routes: {
        '/register': (_) => const RegisterScreen(),
      },
    );
  }
}

/// Chooses the first screen from the current auth state.
///
/// Sign-in and sign-out both flow through Supabase's auth stream, which
/// AuthNotifier already listens to, so this rebuilds on its own — no manual
/// navigation after login is needed.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushRegistrarProvider); // keeps the FCM token registered
    final auth = ref.watch(authProvider);

    return switch (auth.status) {
      AuthStatus.initial || AuthStatus.loading => const _SplashScreen(),
      AuthStatus.unauthenticated => const LoginScreen(),
      // Route by role: a Response Team member gets the operational screen,
      // everyone else the citizen reporting flow. Sub-Admins verify from the
      // web console, so they see the citizen view here.
      AuthStatus.authenticated => switch (auth.user?.role) {
          UserRole.responseTeam => const ResponderShell(),
          _ => const HomeScreen(),
        },
    };
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Signed-in landing screen.
///
/// Placeholder until the SOS capture flow lands — it already reads the real
/// profile, so it doubles as proof that Supabase auth and the users table are
/// wired correctly end to end.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          _AlertsBell(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Signed in as ${user?.displayName ?? 'unknown'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Role: ${user?.role ?? '—'}'),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const VerificationScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(
                      'Verification: ${user?.verifiedPercent ?? 0}% '
                      '(${VerificationBadge.label(user?.badge ?? VerificationBadge.yellow)})',
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SosScreen()),
              ),
              icon: const Icon(Icons.local_fire_department),
              label: const Text('Report a fire'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const MyReportsScreen()),
              ),
              icon: const Icon(Icons.list_alt),
              label: const Text('My reports'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Bell with an unread count. The badge is what makes an alert noticeable when
/// push is unavailable — no google-services.json, or permission denied.
class _AlertsBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Alerts',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
            );
            ref.invalidate(unreadCountProvider);
          },
        ),
        if (unread > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Scaffold around the Response Team screen, so it shares the app bar, alerts
/// bell and sign-out with the citizen view.
class ResponderShell extends ConsumerWidget {
  const ResponderShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Response Team'),
        actions: [
          _AlertsBell(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${user?.displayName ?? 'Responder'} · '
                    '${AgencyType.label(user?.agencyType ?? '')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: ResponderHomeScreen()),
        ],
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.settings_outlined, size: 40),
              const SizedBox(height: 16),
              Text(
                "${AppConstants.appName} couldn't start",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(child: SelectableText(message)),
            ],
          ),
        ),
      ),
    );
  }
}
