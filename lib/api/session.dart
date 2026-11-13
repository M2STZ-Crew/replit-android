import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_cache.dart';

/// Holds the current auth tokens in memory, with optional persistence
/// ("keep session active").
///
/// v1.12.42: it also opens the account's cache of answers ([ApiCache]) when
/// the tokens are set or restored, and forgets it on [clear].
class Session {
  Session._();
  static final Session instance = Session._();

  String? accessToken;
  String? refreshToken;
  String? email;

  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;

  /// Whose the tokens are: the access token's subject (the account's id),
  /// or the email when the token cannot be read. What [ApiCache] keeps its
  /// answers under.
  String? get owner {
    final token = accessToken;
    if (token != null) {
      final parts = token.split('.');
      if (parts.length == 3) {
        try {
          final payload = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])),
          );
          final sub = (jsonDecode(payload) as Map<String, dynamic>)['sub'];
          if (sub is String && sub.isNotEmpty) return sub;
        } catch (_) {
          // Not a token this can read: the email stands in.
        }
      }
    }
    final mail = email;
    return (mail != null && mail.isNotEmpty) ? mail : null;
  }

  void setTokens({
    required String accessToken,
    String? refreshToken,
    String? email,
  }) {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.email = email;
    // The account's cache: another account's answers go at once.
    unawaited(ApiCache.instance.open(owner));
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken ?? '');
    await prefs.setString('refresh_token', refreshToken ?? '');
    await prefs.setString('email', email ?? '');
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null && token.isNotEmpty) {
      accessToken = token;
      refreshToken = prefs.getString('refresh_token');
      email = prefs.getString('email');
      // What the phone kept for this account, before the first screen.
      await ApiCache.instance.open(owner);
    }
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    email = null;
    // Signing out forgets the account's answers too.
    await ApiCache.instance.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('email');
  }
}
