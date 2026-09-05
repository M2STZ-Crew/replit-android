import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/design.dart';
import '../../data/datasources/biometric_service.dart';

final biometricServiceProvider = Provider((ref) => BiometricService());

class BiometricGateScreen extends ConsumerStatefulWidget {
  const BiometricGateScreen({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends ConsumerState<BiometricGateScreen> {
  bool _authenticated = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final bio = ref.read(biometricServiceProvider);
    final available = await bio.isAvailable;

    if (!available) {
      setState(() {
        _authenticated = true;
        _checking = false;
      });
      return;
    }

    final success = await bio.authenticate();
    setState(() {
      _authenticated = success;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_authenticated) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IconWell(
                  tint: AppColors.accent,
                  icon: Icons.fingerprint_rounded,
                  size: 72,
                  glyph: 36,
                ),
                const SizedBox(height: 26),
                const Text('UNLOCK REPLIT', style: AppText.title),
                const SizedBox(height: 10),
                const Text(
                  'Verify your identity to continue. Hotlines still work '
                  'without unlocking.',
                  textAlign: TextAlign.center,
                  style: AppText.body,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 260,
                  child: AppButton(
                    'Authenticate',
                    icon: Icons.fingerprint_rounded,
                    onPressed: _checkBiometric,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
