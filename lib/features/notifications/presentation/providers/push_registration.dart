import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/push_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/notification_api.dart';
import 'notification_provider.dart';

/// Keeps this device's FCM token registered with the backend for as long as
/// someone is signed in.
///
/// Registration is per-user: POST /devices attaches the token to the caller's
/// account, so it can only happen after authentication, and it must happen again
/// if a different user signs in on the same handset.
class PushRegistrar {
  PushRegistrar(this._ref) {
    _authSub = _ref.listen<AuthState2>(
      authProvider,
      (previous, next) {
        if (next.isAuthenticated && previous?.user?.id != next.user?.id) {
          unawaited(_register());
        }
      },
      fireImmediately: true,
    );

    // FCM rotates tokens periodically and after a reinstall. Without
    // re-registering, pushes silently stop arriving — the backend keeps a token
    // that no longer routes anywhere.
    _tokenSub = PushService.instance.onTokenRefresh.listen((_) {
      if (_ref.read(authProvider).isAuthenticated) unawaited(_register());
    });

    // A foreground alert does not raise a system notification, so refresh the
    // inbox and badge to make it visible where the user can act on it.
    _messageSub = PushService.instance.onMessage.listen((_) {
      _ref
        ..invalidate(notificationsProvider)
        ..invalidate(unreadCountProvider);
    });
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState2> _authSub;
  late final StreamSubscription<String> _tokenSub;
  late final StreamSubscription<dynamic> _messageSub;

  Future<void> _register() async {
    final token = await PushService.instance.token();
    if (token == null) return; // push unavailable; inbox still works

    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'web',
    };

    final result = await _ref.read(notificationApiProvider).registerDevice(
          fcmToken: token,
          platform: platform,
          deviceName: _deviceName(),
        );
    result.when(
      success: (_) => debugPrint('Push token registered'),
      // Not fatal: the user simply gets no push until the next attempt.
      failure: (error) => debugPrint('Push registration failed: ${error.message}'),
    );
  }

  String? _deviceName() {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _authSub.close();
    _tokenSub.cancel();
    _messageSub.cancel();
  }
}

/// Instantiated once at app start; kept alive for the process lifetime.
final pushRegistrarProvider = Provider<PushRegistrar>((ref) {
  final registrar = PushRegistrar(ref);
  ref.onDispose(registrar.dispose);
  return registrar;
});
