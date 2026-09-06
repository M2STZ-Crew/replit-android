import 'package:shared_preferences/shared_preferences.dart';

/// Holds the current auth tokens in memory, with optional persistence
/// ("keep session active").
class Session {
  Session._();
  static final Session instance = Session._();

  String? accessToken;
  String? refreshToken;
  String? email;

  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;

  void setTokens({required String accessToken, String? refreshToken, String? email}) {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.email = email;
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
    }
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('email');
  }
}