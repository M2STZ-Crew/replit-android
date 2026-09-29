import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/live_hub.dart';
import 'package:replit/api/session.dart';

/// One end of a socket the test plays the server on.
class FakeWire implements LiveWire {
  final StreamController<dynamic> _frames = StreamController();
  final List<Map<String, dynamic>> sent = [];
  bool closed = false;

  @override
  Stream<dynamic> get frames => _frames.stream;

  @override
  void send(String text) => sent.add(jsonDecode(text) as Map<String, dynamic>);

  @override
  Future<void> close() async => closed = true;

  void server(Map<String, dynamic> frame) => _frames.add(jsonEncode(frame));

  /// The connection drops.
  void drop() => _frames.close();

  List<String> subscribed() => [
    for (final m in sent)
      if (m['action'] == 'subscribe') '${m['channel']}',
  ];
}

/// The app's one socket: every channel on it, sorted to the right screen,
/// kept up through bad signal, and closed when nothing needs it.
void main() {
  late List<FakeWire> wires;
  late LiveHub hub;
  late List<(Uri, String)> seen;
  final held = <LiveSubscription>[];

  LiveSubscription follow(String channel) {
    final sub = hub.subscribe(channel);
    held.add(sub);
    return sub;
  }

  setUp(() {
    wires = [];
    seen = [];
    Session.instance.accessToken = 'token';
    hub = LiveHub(
      api: ApiClient(client: MockClient((_) async => http.Response('{}', 200))),
      connect: (uri, token) async {
        // Recorded, not asserted here: an expect inside the hub's own
        // reconnect would run in the middle of a pump.
        seen.add((uri, token));
        final wire = FakeWire();
        wires.add(wire);
        return wire;
      },
    );
  });

  tearDown(() {
    for (final sub in held) {
      sub.cancel();
    }
    held.clear();
    Session.instance.accessToken = null;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('two screens share one socket', (tester) async {
    final map = follow('map:areas');
    final track = follow('track:a1');
    await settle(tester);
    expect(wires, hasLength(1));
    expect(seen.single.$1.path, endsWith('/ws'));
    expect(seen.single.$2, 'token', reason: 'signed in as the session');

    wires.single.server({'type': 'connected'});
    await settle(tester);
    expect(wires.single.subscribed(), ['map:areas', 'track:a1']);

    map.cancel();
    track.cancel();
  });

  testWidgets('each frame reaches only its own channel', (tester) async {
    final map = follow('map:areas');
    final track = follow('track:a1');
    final onMap = <Map<String, dynamic>>[];
    final onTrack = <Map<String, dynamic>>[];
    map.channel.messages.listen(onMap.add);
    track.channel.messages.listen(onTrack.add);
    await settle(tester);

    final wire = wires.single..server({'type': 'connected'});
    wire.server({
      'type': 'area',
      'channel': 'map:areas',
      'area': {'id': 'x'},
    });
    // A tracking frame from a server that does not name the channel yet.
    wire.server({
      'type': 'tracking',
      'snapshot': {'area_id': 'a1'},
    });
    await settle(tester);

    expect([for (final m in onMap) m['type']], ['area']);
    expect([for (final m in onTrack) m['type']], ['tracking']);
    map.cancel();
    track.cancel();
  });

  testWidgets('a dropped socket comes back and subscribes again', (
    tester,
  ) async {
    final map = follow('map:areas');
    await settle(tester);
    wires.single
      ..server({'type': 'connected'})
      ..server({'type': 'subscribed', 'channel': 'map:areas'});
    await settle(tester);
    expect(map.channel.live.value, isTrue);

    wires.single.drop();
    await settle(tester);
    expect(map.channel.live.value, isFalse, reason: 'the map polls meanwhile');

    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(wires, hasLength(2), reason: 'reconnected after the backoff');
    wires.last.server({'type': 'connected'});
    await settle(tester);
    expect(wires.last.subscribed(), ['map:areas']);
    map.cancel();
  });

  testWidgets('a refused channel is not asked for again', (tester) async {
    final map = follow('map:areas');
    final track = follow('track:a1');
    await settle(tester);
    wires.single
      ..server({'type': 'connected'})
      ..server({
        'type': 'error',
        'channel': 'track:a1',
        'message': 'Not allowed to subscribe to track:a1.',
      });
    await settle(tester);
    expect(track.channel.denied.value, isTrue);
    expect(map.channel.denied.value, isFalse);

    wires.single.drop();
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    wires.last.server({'type': 'connected'});
    await settle(tester);
    expect(wires.last.subscribed(), ['map:areas']);
    map.cancel();
    track.cancel();
  });

  testWidgets('the last screen to leave closes the socket', (tester) async {
    final map = follow('map:areas');
    final track = follow('track:a1');
    await settle(tester);
    final wire = wires.single..server({'type': 'connected'});
    await settle(tester);

    track.cancel();
    expect(wire.sent.last, {'action': 'unsubscribe', 'channel': 'track:a1'});
    expect(wire.closed, isFalse, reason: 'the map still follows');

    map.cancel();
    expect(wire.closed, isTrue);
    expect(hub.connected, isFalse);
  });

  testWidgets('closed in the background, back on return', (tester) async {
    final map = follow('map:areas');
    await settle(tester);
    wires.single.server({'type': 'connected'});
    await settle(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(tester);
    expect(wires.single.closed, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(wires, hasLength(2));
    wires.last.server({'type': 'connected'});
    await settle(tester);
    expect(wires.last.subscribed(), ['map:areas']);
    map.cancel();
  });

  testWidgets('signed out: no socket at all', (tester) async {
    Session.instance.accessToken = null;
    final map = follow('map:areas');
    await settle(tester);
    expect(wires, isEmpty);
    map.cancel();
  });
}
