import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'session.dart';

/// A live source of Track It Live snapshots for one incident.
///
/// An interface so the screen can be tested without a socket.
abstract class TrackingFeed {
  /// True while subscribed and receiving; false while connecting or down —
  /// the screen polls GET /areas/{id}/tracking for as long as it is false.
  ValueListenable<bool> get live;

  /// True once the server refused this account the channel (not its report).
  /// The feed then stops for good.
  ValueListenable<bool> get denied;

  /// Snapshot JSON, as the server pushes it.
  Stream<Map<String, dynamic>> get snapshots;

  void start();

  /// The app went to the background: close the socket, stop retrying.
  void pause();

  /// Back in the foreground.
  void resume();

  Future<void> dispose();
}

/// The backend's `/ws` socket, subscribed to `track:<areaId>`.
///
/// The server pushes a fresh snapshot after every responder fix and every
/// status change, so the resident sees the truck move within a second or two
/// of its phone reporting — where polling would add up to six more.
///
/// Built for bad signal. A dropped socket reconnects by itself, backing off
/// from 2 s to 30 s so a phone with no signal is not kept awake retrying; the
/// token is renewed before a retry in case it lapsed while the socket was
/// down; a protocol ping every 20 s notices a connection that died silently.
/// While the socket is down the screen polls instead, so nothing freezes.
class TrackingSocket implements TrackingFeed {
  TrackingSocket(this.areaId, {ApiClient? api}) : _api = api ?? ApiClient();

  final String areaId;
  final ApiClient _api;

  String get channel => 'track:$areaId';

  final ValueNotifier<bool> _live = ValueNotifier(false);
  final ValueNotifier<bool> _denied = ValueNotifier(false);
  final StreamController<Map<String, dynamic>> _snapshots =
      StreamController.broadcast();

  WebSocket? _ws;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  int _failures = 0;
  bool _running = false;
  bool _connecting = false;
  bool _disposed = false;

  @override
  ValueListenable<bool> get live => _live;

  @override
  ValueListenable<bool> get denied => _denied;

  @override
  Stream<Map<String, dynamic>> get snapshots => _snapshots.stream;

  /// ws:// or wss:// on the same host and path as the REST API.
  static Uri socketUri() {
    final base = Uri.parse(ApiConfig.baseUrl);
    final path = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '$path/ws',
    );
  }

  @override
  void start() {
    if (_disposed || _running || _denied.value) return;
    _running = true;
    unawaited(_connect());
  }

  @override
  void pause() {
    _running = false;
    _retry?.cancel();
    _close();
  }

  @override
  void resume() => start();

  Future<void> _connect() async {
    if (!_running || _disposed || _connecting || _ws != null) return;
    _connecting = true;
    try {
      if (_failures > 0) {
        // The access token may have run out while the socket was down; an
        // ordinary signed-in read renews it the same way every screen does.
        try {
          await _api.getMe();
        } catch (_) {}
      }
      final token = Session.instance.accessToken;
      if (token == null || token.isEmpty || !_running || _disposed) return;
      final ws = await WebSocket.connect(
        socketUri().toString(),
        headers: {'Authorization': 'Bearer $token'},
        customClient: HttpClient()
          ..connectionTimeout = const Duration(seconds: 15),
      );
      if (!_running || _disposed) {
        unawaited(ws.close());
        return;
      }
      ws.pingInterval = const Duration(seconds: 20);
      _ws = ws;
      _sub = ws.listen(
        _onFrame,
        onDone: _onClosed,
        onError: (Object _) => _onClosed(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRetry();
    } finally {
      _connecting = false;
    }
  }

  void _onFrame(dynamic data) {
    if (data is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    switch (decoded['type']) {
      case 'connected':
        _ws?.add(jsonEncode({'action': 'subscribe', 'channel': channel}));
      case 'subscribed':
        if (decoded['channel'] == channel) {
          _failures = 0;
          _live.value = true;
        }
      case 'tracking':
        final snapshot = decoded['snapshot'];
        if (snapshot is Map<String, dynamic>) _snapshots.add(snapshot);
      case 'error':
        // Before the subscription is confirmed, the only thing that can go
        // wrong is the subscription itself: this account may not follow this
        // incident. Retrying would only be refused again.
        if (!_live.value) {
          _denied.value = true;
          _running = false;
          _close();
        }
    }
  }

  void _onClosed() {
    _sub = null;
    _ws = null;
    if (_disposed) return;
    _live.value = false;
    if (_running && !_denied.value) _scheduleRetry();
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (!_running || _disposed) return;
    _failures++;
    final seconds = math.min(30, 1 << math.min(_failures, 5));
    _retry = Timer(Duration(seconds: seconds), () => unawaited(_connect()));
  }

  void _close() {
    final ws = _ws;
    final sub = _sub;
    _ws = null;
    _sub = null;
    if (!_disposed) _live.value = false;
    unawaited(sub?.cancel());
    if (ws != null) unawaited(ws.close());
  }

  @override
  Future<void> dispose() async {
    _running = false;
    _retry?.cancel();
    _close();
    _disposed = true;
    _live.dispose();
    _denied.dispose();
    await _snapshots.close();
  }
}
