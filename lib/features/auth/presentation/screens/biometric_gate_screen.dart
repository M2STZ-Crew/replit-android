import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fingerprint, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text(
              'Authentication Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Please verify your identity to continue'),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _checkBiometric,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Authenticate'),
            ),
          ],
        ),
      ),
    );
  }
}
