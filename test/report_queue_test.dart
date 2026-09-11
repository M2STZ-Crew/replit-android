import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/map_cache.dart';
import 'package:replit/api/report_queue.dart';

/// The offline report queue ("05 Map — offline queue"). A report is an
/// emergency call in another form: the queue must not lose one, and must not
/// send one twice — a duplicate counts one resident as two corroborating
/// reporters.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final queue = ReportQueue.instance;
  late Directory dir;

  // What the fake server has been asked, and what it will answer.
  late List<http.BaseRequest> seen;
  late List<Map<String, dynamic>> mine;
  late http.Response Function() submitReply;
  late bool reachable;

  ApiClient api() => ApiClient(
    client: MockClient((req) async {
      seen.add(req);
      if (!reachable) throw http.ClientException('no route to host');
      if (req.url.path.endsWith('/reports/mine')) {
        return http.Response(jsonEncode(mine), 200);
      }
      if (req.url.path.endsWith('/reports/submit')) return submitReply();
      return http.Response('{}', 404);
    }),
  );

  int submits() =>
      seen.where((r) => r.url.path.endsWith('/reports/submit')).length;

  Future<QueuedReport> enqueueOne({double lat = 14.5378}) => queue.enqueue(
    lat: lat,
    lng: 121.0014,
    accuracyM: 6,
    agencies: const ['fire_volunteer'],
    notes: 'smoke from the second floor',
    photoBytes: const [0xFF, 0xD8, 0xFF, 0xD9],
  );

  setUp(() {
    // The "salamat" cue is switched off: the plugin has no platform here.
    SharedPreferences.setMockInitialValues({'sound.report_sent': false});
    dir = Directory.systemTemp.createTempSync('report_queue_test');
    seen = [];
    mine = [];
    reachable = true;
    submitReply = () => http.Response(
      jsonEncode({'id': 'r1', 'area_id': 'a1', 'area_designation': 'Area 1.2'}),
      201,
    );
    queue.reset();
    queue.configureForTest(api: api(), dir: dir);
  });

  tearDown(() {
    queue.reset();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('a queued report keeps its photo on the phone and waits', () async {
    final r = await enqueueOne();
    expect(queue.pending.value, hasLength(1));
    expect(queue.offline.value, isTrue);
    expect(File(r.photoPath).readAsBytesSync(), [0xFF, 0xD8, 0xFF, 0xD9]);
  });

  test(
    'when the signal returns it sends, and cleans up after itself',
    () async {
      final r = await enqueueOne();
      final delivered = queue.delivered.first;

      expect(await queue.flush(), 1);
      expect(submits(), 1);
      expect(queue.pending.value, isEmpty);
      expect(queue.offline.value, isFalse);
      expect(File(r.photoPath).existsSync(), isFalse);
      expect((await delivered).id, r.id);
    },
  );

  test('a report that already landed is not sent a second time', () async {
    // The first attempt reached the server; only its reply was lost.
    final r = await enqueueOne();
    mine = [
      {
        'id': 'r1',
        'device_lat': r.lat,
        'device_lng': r.lng,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    ];

    expect(await queue.flush(), 1);
    expect(submits(), 0, reason: 'a resend would double-count the reporter');
    expect(queue.pending.value, isEmpty);
  });

  test(
    'a neighbour a few metres away is not mistaken for this report',
    () async {
      await enqueueOne(lat: 14.5378);
      mine = [
        {
          'device_lat': 14.53781,
          'device_lng': 121.0014,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      ];
      await queue.flush();
      expect(submits(), 1);
    },
  );

  test('with still no signal it keeps the report and says offline', () async {
    await enqueueOne();
    reachable = false;

    expect(await queue.flush(), 0);
    expect(queue.pending.value, hasLength(1));
    expect(queue.offline.value, isTrue);
  });

  test('a server error is not a refusal: the report waits for later', () async {
    await enqueueOne();
    submitReply = () => http.Response('{"detail":"try later"}', 503);

    await queue.flush();
    expect(queue.pending.value, hasLength(1));
    expect(queue.offline.value, isFalse, reason: 'the server did answer');
  });

  test('a report the server refuses is dropped, and says why', () async {
    await enqueueOne();
    submitReply = () =>
        http.Response('{"detail":"Photo must be JPEG or PNG."}', 400);

    await queue.flush();
    expect(queue.pending.value, isEmpty, reason: 'resending gets the same no');
    expect(queue.lastRejection.value, isNotNull);
  });

  test('a queued report survives the app being closed', () async {
    final r = await enqueueOne();
    queue.reset(); // as if the process died
    queue.configureForTest(api: api(), dir: dir);

    await queue.load();
    expect(queue.pending.value.single.id, r.id);
    expect(queue.pending.value.single.agencies, ['fire_volunteer']);
  });

  test('one whose photo is gone is not kept pretending to wait', () async {
    final r = await enqueueOne();
    File(r.photoPath).deleteSync();
    queue.reset();
    queue.configureForTest(api: api(), dir: dir);

    await queue.load();
    expect(queue.pending.value, isEmpty);
  });

  group('map cache', () {
    test('each layer keeps its own age, and the oldest is reported', () async {
      SharedPreferences.setMockInitialValues({
        'map_cache_v1_hydrants': '[]',
        'map_cache_v1_hydrants_at': DateTime.now()
            .subtract(const Duration(days: 3))
            .toUtc()
            .toIso8601String(),
      });
      await MapCache.instance.put('evac', const [
        {'name': 'Pasay Sports Complex'},
      ]);

      final saved = await MapCache.instance.savedAt();
      expect(
        DateTime.now().difference(saved!).inDays,
        3,
        reason: 'fresh shelters must not make old hydrants look fresh',
      );
      final stale = await MapCache.instance.stale();
      expect(stale, contains('hydrants'));
      expect(stale, isNot(contains('evac')));
      expect(stale, contains('water'), reason: 'never saved');
      expect(await MapCache.instance.get('evac'), hasLength(1));
    });
  });
}
