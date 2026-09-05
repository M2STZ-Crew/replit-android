import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'core/config/env.dart';
import 'core/constants/app_constants.dart';
import 'core/services/hive_service.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/design.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/notifications/presentation/providers/push_registration.dart';
import 'features/responder/presentation/screens/responder_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlay);

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

  runApp(ProviderScope(child: RepLiTApp(startupError: startupError)));
}

class RepLiTApp extends StatelessWidget {
  const RepLiTApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.dark,
      // The design is a dark system end to end; there is no light variant of it,
      // so the app pins the theme rather than following the device.
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: startupError != null
          ? _StartupErrorScreen(message: startupError!)
          : const _AuthGate(),
      // LoginScreen pushes '/register' by name. Without this the app throws
      // "Could not find a generator for route" the moment Register is tapped.
      // RegisterScreen pops back here on success and the gate takes over.
      routes: {'/register': (_) => const RegisterScreen()},
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
      AuthStatus.initial || AuthStatus.loading => const SplashScreen(),
      AuthStatus.unauthenticated => const LoginScreen(),
      // Route by role: a Response Team member gets the operational screen,
      // everyone else the citizen app. Sub-Admins verify from the web console,
      // so they see the citizen view here.
      AuthStatus.authenticated => switch (auth.user?.role) {
        UserRole.responseTeam => const ResponderShell(),
        _ => const AppShell(),
      },
    };
  }
}

/// The splash from the hand-off: a breathing halo behind the mark while the
/// session is resolved. This and the SOS button are the only two places the
/// design allows glow.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.16),
            radius: 0.8,
            colors: [Color(0x1CFF9066), Color(0x00131313)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              AnimatedBuilder(
                animation: _breathe,
                builder: (context, child) => Transform.scale(
                  scale: 1 + _breathe.value * 0.06,
                  child: Opacity(opacity: 0.92 + _breathe.value * 0.08, child: child),
                ),
                child: Image.asset(Art.mark, width: 112, height: 112),
              ),
              const SizedBox(height: 34),
              Image.asset(Art.wordmark, width: 186, fit: BoxFit.contain),
              const Spacer(flex: 2),
              SizedBox(
                width: 106,
                height: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const LinearProgressIndicator(minHeight: 3),
                ),
              ),
              const SizedBox(height: 18),
              const Eyebrow('Connecting to Pasay City', color: AppColors.muted),
              const Spacer(),
              Text(
                AppConstants.appTagline.toUpperCase(),
                style: AppText.tag.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: AppColors.faint,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
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
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 60),
            const IconWell(
              tint: AppColors.live,
              icon: Icons.settings_outlined,
              size: 52,
              glyph: 24,
            ),
            const SizedBox(height: 20),
            Text(
              "${AppConstants.appName} COULDN'T START",
              style: AppText.title,
            ),
            const SizedBox(height: 16),
            Panel(
              color: AppColors.surfaceDim,
              child: SelectableText(
                message,
                style: AppText.meta.copyWith(
                  fontSize: 12,
                  height: 17 / 12,
                  color: AppColors.textSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
