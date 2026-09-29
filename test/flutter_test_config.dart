import 'dart:async';

import 'package:replit/api/live_hub.dart';
import 'package:replit/widgets/you_are_here.dart';

/// Runs before every test file.
///
/// flutter_test answers every HTTP request itself, and a WebSocket handshake
/// cannot survive that stand-in — it fails outside anything the app can catch.
/// So the app's one socket is replaced with one that connects and then says
/// nothing: no channel ever goes live, and every screen polls, exactly as it
/// does on a phone whose socket is down. Tests of the socket itself
/// (live_hub_test.dart) build their own [LiveHub], and screen tests that need
/// live messages hand the screen a fake feed.
///
/// Likewise there is no GPS or compass under test: every map's blue dot gets
/// streams that say nothing, and you_are_here_test.dart feeds its own.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LiveHub.instance = LiveHub(connect: (_, _) async => _SilentWire());
  MapLocationSource.positions = () => const Stream.empty();
  MapLocationSource.headings = () => const Stream.empty();
  await testMain();
}

class _SilentWire implements LiveWire {
  final StreamController<dynamic> _frames = StreamController();

  @override
  Stream<dynamic> get frames => _frames.stream;

  @override
  void send(String text) {}

  @override
  Future<void> close() => _frames.close();
}
