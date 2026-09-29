import 'dart:async';

import 'live_hub.dart';

/// Re-reads a staff screen the moment the server says something changed.
///
/// Staff screens poll; with this they also listen. One person's Verify,
/// Respond or Reject reaches every other open screen within a second instead
/// of on the next poll, so a responder does not tap Respond on an incident a
/// coordinator has just rejected. The poll stays as the fallback — a dropped
/// socket costs freshness, never correctness — and the server re-checks every
/// action anyway, so a button pressed on a stale screen gets a clear refusal.
///
/// Rides the app's one socket ([LiveHub]); the server only lets a user follow
/// channels their agency may see.
class LiveRefresh {
  LiveRefresh(
    List<String> channels,
    this.onChange, {
    this.ignore = const {'responder_location', 'ping', 'pong'},
  }) : _feeds = [for (final c in channels) feedFor(c)];

  /// How a channel is followed. Replaceable in tests.
  static LiveFeed Function(String channel) feedFor = ChannelFeed.new;

  final void Function() onChange;

  /// Message types that change nothing a screen reloads for. A responder's GPS
  /// fix arrives every few seconds; reloading the whole screen for each one
  /// would cost more than it shows — the map's own poll picks positions up.
  final Set<String> ignore;

  final List<LiveFeed> _feeds;
  final List<StreamSubscription<Map<String, dynamic>>> _subs = [];
  Timer? _settle;

  void start() {
    for (final feed in _feeds) {
      _subs.add(feed.messages.listen(_onMessage));
      feed.start();
    }
  }

  void _onMessage(Map<String, dynamic> message) {
    if (ignore.contains(message['type'])) return;
    // Several screens' worth of events can land together (a status change is
    // sent to the incident and to every agency); read once for the burst.
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 250), onChange);
  }

  Future<void> dispose() async {
    _settle?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    for (final feed in _feeds) {
      await feed.dispose();
    }
  }
}

/// The channel a feed or dashboard follows: the user's agency. BFP and Fire
/// Volunteers hear each other's incidents — the server sends to both.
List<String> agencyChannels(String? agency) =>
    agency == null || agency.isEmpty ? const [] : ['agency:$agency'];

/// The channel one incident's screen follows.
String incidentChannel(String incidentId) => 'incident:$incidentId';
