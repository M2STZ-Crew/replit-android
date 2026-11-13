import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last answer to each of the screens' requests, for the account signed
/// in: what a screen shows the moment it opens, while it asks again.
///
/// 13 November 2026: "it is verified but after I've pressing the home and
/// going back to profile it is still fetching if it's verified or not ... I
/// want you to do caching in it ... do it to all screens as possible". Each
/// tab of the residents' app is its own route, made anew on every visit, so
/// every visit started empty: Profile drew a name from the email, 0%
/// verified and "Add your National ID" until the server answered. A moment,
/// but enough to read as wrong. Now [ApiClient] keeps each answer here as it
/// arrives, and each screen starts from it and refreshes behind it.
///
/// Kept in memory for the session. The account's own (who they are, their
/// verification, their alerts) is also kept on the phone, so the first
/// screen after the app starts has it too. It all belongs to one account:
/// another account starts empty, and signing out forgets it
/// (Session.setTokens, Session.restore, Session.clear).
class ApiCache {
  ApiCache._();

  static final ApiCache instance = ApiCache._();

  // What is kept: on the phone too (the account's own), or for the session.
  static const String me = 'me';
  static const String verification = 'verification';
  static const String notifications = 'notifications';
  static const String areas = 'areas';
  static const String evacuationSites = 'map.evacuation-sites';
  static const String myReports = 'reports.mine';
  static String area(String id) => 'area.$id';
  static String mapLayer(String layer) => 'map.$layer';

  static const String _prefix = 'api_cache.v1.';

  final Map<String, Object?> _memory = {};
  String? _owner;

  /// Bumped when something says the account's own data changed (its
  /// National ID was reviewed, say): a screen showing it asks again.
  final ValueNotifier<int> accountChanged = ValueNotifier(0);

  /// The account the cache belongs to (null: none signed in, or unknown).
  String? get owner => _owner;

  /// The last answer for [key], or null.
  T? peek<T>(String key) {
    final value = _memory[key];
    return value is T ? value : null;
  }

  /// Keeps [value] as the answer for [key]. [onPhone]: the account's own
  /// data, also written to the phone for the next start.
  void put(String key, Object? value, {bool onPhone = false}) {
    _memory[key] = value;
    final owner = _owner;
    if (onPhone && owner != null) unawaited(_write(owner, key, value));
  }

  /// The cache of the account [owner]: what the phone kept for it, unless it
  /// is the one already open. Another account's answers are dropped first,
  /// before anything is awaited.
  Future<void> open(String? owner) async {
    if (owner == _owner) return;
    _memory.clear();
    _owner = owner;
    if (owner == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final mine = '$_prefix$owner.';
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(mine)) continue;
        final raw = prefs.getString(key);
        final name = key.substring(mine.length);
        // A fresher answer may have come while the phone was read.
        if (raw == null || _owner != owner || _memory.containsKey(name)) {
          continue;
        }
        _memory[name] = jsonDecode(raw);
      }
    } catch (_) {
      // Nothing kept, or unreadable: the screens ask as before.
    }
  }

  /// Forgets everything (signing out): the session's answers and what the
  /// phone kept for the account.
  Future<void> clear() async {
    final owner = _owner;
    _memory.clear();
    _owner = null;
    if (owner == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final mine = '$_prefix$owner.';
      for (final key in prefs.getKeys().where((k) => k.startsWith(mine))) {
        await prefs.remove(key);
      }
    } catch (_) {
      // The keys go with the next sign in as this account's answers arrive.
    }
  }

  /// Says the account's own data changed; screens showing it ask again.
  void accountChangedNow() => accountChanged.value++;

  /// Empties the cache without touching the phone: a test starts clean.
  @visibleForTesting
  void reset() {
    _memory.clear();
    _owner = null;
  }

  Future<void> _write(String owner, String key, Object? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_owner != owner) return; // signed out, or someone else, meanwhile
      await prefs.setString('$_prefix$owner.$key', jsonEncode(value));
    } catch (_) {
      // Kept for the session only.
    }
  }
}
