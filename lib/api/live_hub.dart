import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'session.dart';

/// One socket to the backend's `/ws` for the whole app, carrying every live
/// channel any open screen follows.
///
/// The map follows `map:areas`; Track It Live, opened over it, follows
/// `track:<areaId>`. Both ride this one connection instead of opening one each:
/// one handshake, one keep-alive ping, one thing to reconnect.
///
/// Built for bad signal. A dropped socket reconnects by itself, backing off
/// from 2 s to 30 s so a phone with no signal is not kept awake retrying; the
/// token is renewed before a retry in case it lapsed while the socket was down;
/// a protocol ping every 20 s notices a connection that died silently. In the
/// background the socket is closed — nobody is looking — and every channel is
/// subscribed again on the way back.
///
/// While a channel is not [LiveChannel.live], the screen following it polls
/// instead, so nothing freezes when the socket cannot connect.
class LiveHub with WidgetsBindingObserver {
  LiveHub({ApiClient? api, WireConnector? connect})
    : _api = api ?? ApiClient(),
      _connect = connect ?? _connectIo;

  /// The app's one hub. Replaceable in tests.
  static LiveHub instance = LiveHub();

  final ApiClient _api;
  final WireConnector _connect;
  final Map<String, LiveChannel> _channels = {};

  LiveWire? _wire;
  StreamSubscription<dynamic>? _frames;
  Timer? _retry;
  int _failures = 0;
  bool _greeted = false;
  bool _connecting = false;
  bool _background = false;
  bool _observing = false;

  /// Whether the socket is open now.
  bool get connected => _wire != null;

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

  /// Follow [name]. Every call is one holder; [LiveSubscription.cancel] ends
  /// it, and the last holder to leave unsubscribes.
  LiveSubscription subscribe(String name) {
    final channel = _channels.putIfAbsent(name, () => LiveChannel._(name));
    channel._holders++;
    if (channel._holders == 1 && _greeted) _subscribeOn(channel);
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    unawaited(_open());
    return LiveSubscription._(this, channel);
  }

  void _release(LiveChannel channel) {
    channel._holders--;
    if (channel._holders > 0) return;
    _channels.remove(channel.name);
    if (_greeted && !channel._denied.value) {
      _send({'action': 'unsubscribe', 'channel': channel.name});
    }
    channel._close();
    if (_channels.isEmpty) {
      _retry?.cancel();
      _closeWire();
      if (_observing) {
        WidgetsBinding.instance.removeObserver(this);
        _observing = false;
      }
    }
  }

  void _subscribeOn(LiveChannel channel) {
    if (!channel._denied.value) {
      _send({'action': 'subscribe', 'channel': channel.name});
    }
  }

  void _send(Map<String, dynamic> message) {
    try {
      _wire?.send(jsonEncode(message));
    } catch (_) {
      // The socket is going down; the reconnect subscribes again.
    }
  }

  Future<void> _open() async {
    if (_channels.isEmpty || _background || _connecting || _wire != null) {
      return;
    }
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
      if (token == null || token.isEmpty) return;
      if (_channels.isEmpty || _background) return;
      final wire = await _connect(socketUri(), token);
      if (_channels.isEmpty || _background) {
        unawaited(wire.close());
        return;
      }
      _wire = wire;
      _greeted = false;
      _frames = wire.frames.listen(
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
        _greeted = true;
        _channels.values.forEach(_subscribeOn);
      case 'subscribed':
        final channel = _channels[decoded['channel']];
        if (channel != null) {
          _failures = 0;
          channel._live.value = true;
        }
      case 'error':
        // Before a channel is confirmed, the only thing that can go wrong
        // with it is the subscription itself: this account may not follow it.
        // Asking again on every reconnect would only be refused again.
        final channel = _channels[_channelOf(decoded)];
        if (channel != null && !channel._live.value) {
          channel._denied.value = true;
        }
      case 'ping' || 'pong' || 'unsubscribed':
        break;
      default:
        _channels[_channelOf(decoded)]?._messages.add(decoded);
    }
  }

  /// Which channel a frame belongs to: the server names it. Tracking frames
  /// and refusals from a server older than that are recognised by content.
  static String? _channelOf(Map<String, dynamic> frame) {
    final named = frame['channel'];
    if (named is String) return named;
    final snapshot = frame['snapshot'];
    if (frame['type'] == 'tracking' && snapshot is Map) {
      return 'track:${snapshot['area_id']}';
    }
    final text = frame['message'];
    const refused = 'Not allowed to subscribe to ';
    if (text is String && text.startsWith(refused)) {
      final rest = text.substring(refused.length);
      return rest.endsWith('.') ? rest.substring(0, rest.length - 1) : rest;
    }
    return null;
  }

  void _onClosed() {
    _frames = null;
    _wire = null;
    _greeted = false;
    for (final channel in _channels.values) {
      channel._live.value = false;
    }
    if (_channels.isNotEmpty && !_background) _scheduleRetry();
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (_channels.isEmpty || _background) return;
    _failures++;
    final seconds = math.min(30, 1 << math.min(_failures, 5));
    _retry = Timer(Duration(seconds: seconds), () => unawaited(_open()));
  }

  void _closeWire() {
    final frames = _frames;
    final wire = _wire;
    _frames = null;
    _wire = null;
    _greeted = false;
    unawaited(frames?.cancel());
    if (wire != null) unawaited(wire.close());
    for (final channel in _channels.values) {
      channel._live.value = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _background = true;
      _retry?.cancel();
      _closeWire();
    } else if (state == AppLifecycleState.resumed && _background) {
      _background = false;
      _failures = 0;
      unawaited(_open());
    }
  }
}

/// One channel's state, shared by every holder of it.
class LiveChannel {
  LiveChannel._(this.name);

  final String name;
  final ValueNotifier<bool> _live = ValueNotifier(false);
  final ValueNotifier<bool> _denied = ValueNotifier(false);
  final StreamController<Map<String, dynamic>> _messages =
      StreamController.broadcast();
  int _holders = 0;

  /// Subscribed and receiving.
  ValueListenable<bool> get live => _live;

  /// The server refused this account the channel.
  ValueListenable<bool> get denied => _denied;

  Stream<Map<String, dynamic>> get messages => _messages.stream;

  void _close() {
    _live.dispose();
    _denied.dispose();
    unawaited(_messages.close());
  }
}

/// A screen's hold on a channel.
class LiveSubscription {
  LiveSubscription._(this._hub, this.channel);

  final LiveHub _hub;
  final LiveChannel channel;
  bool _cancelled = false;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _hub._release(channel);
  }
}

/// A screen's view of one channel, the same object for the screen's whole
/// life: [pause] and [resume] swap the subscription underneath while the
/// screen's listeners stay attached here.
abstract class LiveFeed {
  ValueListenable<bool> get live;
  ValueListenable<bool> get denied;
  Stream<Map<String, dynamic>> get messages;
  void start();
  void pause();
  void resume();
  Future<void> dispose();
}

/// [LiveFeed] over the [LiveHub].
class ChannelFeed implements LiveFeed {
  ChannelFeed(this.channel, {LiveHub? hub}) : _hub = hub ?? LiveHub.instance;

  final String channel;
  final LiveHub _hub;

  final ValueNotifier<bool> _live = ValueNotifier(false);
  final ValueNotifier<bool> _denied = ValueNotifier(false);
  final StreamController<Map<String, dynamic>> _messages =
      StreamController.broadcast();
  LiveSubscription? _sub;
  StreamSubscription<Map<String, dynamic>>? _relay;
  bool _disposed = false;

  @override
  ValueListenable<bool> get live => _live;

  @override
  ValueListenable<bool> get denied => _denied;

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  void start() {
    if (_sub != null || _disposed || _denied.value) return;
    final sub = _hub.subscribe(channel);
    _sub = sub;
    sub.channel.live.addListener(_sync);
    sub.channel.denied.addListener(_sync);
    _relay = sub.channel.messages.listen(_messages.add);
    _sync();
  }

  void _sync() {
    final channel = _sub?.channel;
    if (channel == null || _disposed) return;
    _live.value = channel.live.value;
    if (channel.denied.value) _denied.value = true;
  }

  @override
  void pause() {
    final sub = _sub;
    if (sub == null) return;
    _sub = null;
    sub.channel.live.removeListener(_sync);
    sub.channel.denied.removeListener(_sync);
    unawaited(_relay?.cancel());
    _relay = null;
    sub.cancel();
    if (!_disposed) _live.value = false;
  }

  @override
  void resume() => start();

  @override
  Future<void> dispose() async {
    pause();
    _disposed = true;
    _live.dispose();
    _denied.dispose();
    await _messages.close();
  }
}

/// The two ends of one socket, as the hub uses them: dart:io's WebSocket in
/// the app, a fake in tests.
abstract class LiveWire {
  Stream<dynamic> get frames;
  void send(String text);
  Future<void> close();
}

typedef WireConnector = Future<LiveWire> Function(Uri uri, String token);

Future<LiveWire> _connectIo(Uri uri, String token) async {
  final ws = await WebSocket.connect(
    uri.toString(),
    headers: {'Authorization': 'Bearer $token'},
    customClient: HttpClient()..connectionTimeout = const Duration(seconds: 15),
  );
  ws.pingInterval = const Duration(seconds: 20);
  return _IoWire(ws);
}

class _IoWire implements LiveWire {
  _IoWire(this._ws);

  final WebSocket _ws;

  @override
  Stream<dynamic> get frames => _ws;

  @override
  void send(String text) => _ws.add(text);

  @override
  Future<void> close() => _ws.close();
}
