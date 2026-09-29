import 'dart:async';

import 'package:flutter/foundation.dart';

import 'live_hub.dart';

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

  /// Stop following (the app went to the background, or the channel was
  /// refused).
  void pause();

  /// Follow again.
  void resume();

  Future<void> dispose();
}

/// `track:<areaId>` on the app's one socket ([LiveHub]).
///
/// The server pushes a fresh snapshot after every responder fix and every
/// status change, so the resident sees the truck move within a second or two
/// of its phone reporting — where polling would add up to six more.
class TrackingSocket implements TrackingFeed {
  TrackingSocket(this.areaId, {LiveHub? hub})
    : _feed = ChannelFeed('track:$areaId', hub: hub);

  final String areaId;
  final ChannelFeed _feed;

  String get channel => _feed.channel;

  /// ws:// or wss:// on the same host and path as the REST API.
  static Uri socketUri() => LiveHub.socketUri();

  @override
  ValueListenable<bool> get live => _feed.live;

  @override
  ValueListenable<bool> get denied => _feed.denied;

  @override
  Stream<Map<String, dynamic>> get snapshots => _feed.messages
      .where((m) => m['type'] == 'tracking' && m['snapshot'] is Map)
      .map((m) => m['snapshot'] as Map<String, dynamic>);

  @override
  void start() => _feed.start();

  @override
  void pause() => _feed.pause();

  @override
  void resume() => _feed.resume();

  @override
  Future<void> dispose() => _feed.dispose();
}
