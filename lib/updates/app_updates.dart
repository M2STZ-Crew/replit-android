import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../app_version.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/design.dart';
import '../widgets/sheet_grip.dart';
import '../i18n/i18n.dart';
import '../store_build.dart';

/// A newer build of RepLiT, published on the repository's GitHub releases.
/// A release's notes as the update sheet says them (v1.12.58; 20 Nov 2026:
/// "remove the 'merge pull request...'. we want to see only here is the
/// version and what are the new things"). GitHub's merge line, a release
/// title ("v1.12.57: ...": the sheet already says the version) and
/// co-author lines are left out, and "- " list marks become bullets. Null
/// when nothing is left.
String? cleanNotes(String raw) {
  final kept = <String>[];
  for (final line in raw.replaceAll('\r\n', '\n').split('\n')) {
    final l = line.trimRight();
    if (RegExp(r'^Merge pull request #\d+').hasMatch(l)) continue;
    if (RegExp(r'^Co-Authored-By:', caseSensitive: false).hasMatch(l)) continue;
    if (RegExp(r'^v?\d+\.\d+\.\d+: ').hasMatch(l)) continue;
    kept.add(l.startsWith('- ') ? '• ${l.substring(2)}' : l);
  }
  final text = kept.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return text.isEmpty ? null : text;
}

class AvailableRelease {
  const AvailableRelease({
    required this.version,
    required this.build,
    this.tag = '',
    this.apk = '',
    this.size = 0,
    this.sha256 = '',
    this.notes,
  });

  final String version;
  final int build;

  /// The release's tag ("android-v1.12.37") and the APK's file name in it
  /// ("RepLiT-1.12.37.apk"); releases before 1.12.37 carried the build
  /// number in both.
  final String tag;
  final String apk;

  /// The APK's size in bytes and its SHA-256, as CI measured them.
  final int size;
  final String sha256;
  final String? notes;

  /// "1.12.37": the version alone, the way Profile writes it.
  String get label => version;

  /// "72 MB".
  String get sizeLabel => '${(size / (1024 * 1024)).ceil()} MB';

  /// Where the APK downloads from, in the same releases as the manifest.
  Uri get apkUrl => Uri.parse(
    '${AppUpdates.releases}/download/${Uri.encodeComponent(tag)}/'
    '${Uri.encodeComponent(apk)}',
  );

  /// A release from its `latest.json`, or null when the file is not one this
  /// app can install: a part missing, or a name that is not a plain file name.
  static AvailableRelease? fromManifest(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    final build = json['build'];
    final tag = json['tag'];
    final apk = json['apk'];
    final size = json['size'];
    final sha256 = json['sha256'];
    final notes = json['notes'];
    final plain = RegExp(r'^[A-Za-z0-9._-]+$');
    if (version is! String ||
        build is! int ||
        tag is! String ||
        !plain.hasMatch(tag) ||
        apk is! String ||
        !plain.hasMatch(apk) ||
        !apk.endsWith('.apk') ||
        size is! int ||
        size <= 0 ||
        sha256 is! String ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sha256)) {
      return null;
    }
    return AvailableRelease(
      version: version,
      build: build,
      tag: tag,
      apk: apk,
      size: size,
      sha256: sha256.toLowerCase(),
      notes: notes is String ? cleanNotes(notes) : null,
    );
  }
}

/// What a check found.
sealed class UpdateCheck {
  const UpdateCheck();
}

class UpToDate extends UpdateCheck {
  const UpToDate();
}

class UpdateAvailable extends UpdateCheck {
  const UpdateAvailable(
    this.release, {
    this.downloaded = false,
    this.downloading = false,
  });
  final AvailableRelease release;

  /// The APK is already in the app's cache, whole, from an earlier download
  /// that was not installed: installing needs no second download.
  final bool downloaded;

  /// Android is downloading it already, in the background (v1.12.48): the
  /// sheet follows that download rather than starting another.
  final bool downloading;
}

/// Where Android's background download of an update is (v1.12.48).
enum UpdateDownloadState {
  /// Downloading: the person may leave RepLiT, and it carries on.
  background,

  /// Waiting for a connection, to carry on where it stopped.
  waiting,
}

class UpdateCheckFailed extends UpdateCheck {
  const UpdateCheckFailed(this.code);

  /// Why, as one of the codes [AppUpdates.explain] knows.
  final String code;
}

/// Whether [version] ("1.12.31") is later than [than] ("1.12.30"), number by
/// number; false when either is not a version (an iPhone's, read too early).
bool isNewerVersion(String version, {required String than}) {
  List<int>? numbers(String v) {
    final core = v.trim().split('+').first.split('-').first;
    if (core.isEmpty) return null;
    final parts = [for (final p in core.split('.')) int.tryParse(p)];
    return parts.contains(null) ? null : parts.cast<int>();
  }

  final a = numbers(version);
  final b = numbers(than);
  if (a == null || b == null) return false;
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// An install that did not go through, and why.
class UpdateInstallFailed implements Exception {
  const UpdateInstallFailed(this.code);
  final String code;
}

/// "Check for updates", Android only (the 5 November issue list, 2.4, and
/// issue 3 after it): for anyone, with no Firebase tester invitation.
///
/// Every Android build CI makes is also published on the repository's GitHub
/// releases, with a `latest.json` beside the APK (version, build number, size,
/// SHA-256, notes). This reads the newest one's `latest.json` — a plain file
/// download, not GitHub's rate-limited API, so phones sharing a carrier's
/// address do not use up each other's checks — and compares its build number
/// with this one's. Installing hands the APK's download to Android's
/// DownloadManager (v1.12.48, 17 Nov 2026: "add the background downloading
/// when updating, because it can be interrupted"): it carries on with RepLiT
/// in the background or closed, shows its progress in the notification shade,
/// and picks up after a lost connection; when it is done, a notification
/// opens this sheet. Without a DownloadManager, the app downloads it itself,
/// as before. MainActivity then checks the APK against the SHA-256 and opens
/// Android's installer, which asks the first time to allow installs from
/// RepLiT.
///
/// iPhones are sideloaded (docs/ios-sideload.md), and nothing installed that
/// way can update itself, so the row is not drawn there.
abstract final class AppUpdates {
  static const MethodChannel _channel = MethodChannel('replit/updates');

  /// The releases CI publishes to.
  static const String releases = String.fromEnvironment(
    'UPDATES_RELEASES',
    defaultValue: 'https://github.com/M2STZ-Crew/replit-android/releases',
  );

  static const Map<String, String> _headers = {
    'User-Agent': 'RepLiT-Android',
    'Accept': 'application/json, application/octet-stream',
  };

  /// Whether this phone can check: Android.
  static bool get supported =>
      supportedOverride ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @visibleForTesting
  static bool? supportedOverride;

  /// Whether this phone is told of a newer release ("There's a new update!"):
  /// Android, which installs it, and an iPhone, which is only told.
  static bool get canTell =>
      supported || (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  @visibleForTesting
  static Future<UpdateCheck> Function()? checkOverride;

  @visibleForTesting
  static Future<void> Function(ValueChanged<double?> onProgress)?
  installOverride;

  /// For tests: the HTTP client, and the version installed.
  @visibleForTesting
  static http.Client Function()? clientOverride;
  @visibleForTesting
  static String? installedVersionOverride;

  /// What the last [check] found, for [install].
  static AvailableRelease? _found;

  static http.Client _client() => clientOverride?.call() ?? http.Client();

  /// Look for a newer release. Never throws.
  static Future<UpdateCheck> check() async {
    final stand = checkOverride;
    if (stand != null) return stand();
    final client = _client();
    try {
      final response = await client
          .get(
            Uri.parse('$releases/latest/download/latest.json'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20));
      // No release published yet: what is installed is the newest there is.
      if (response.statusCode == 404) return const UpToDate();
      if (response.statusCode != 200) {
        return UpdateCheckFailed('HTTP_${response.statusCode}');
      }
      final release = AvailableRelease.fromManifest(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
      if (release == null) return const UpdateCheckFailed('BAD_RELEASE');
      // The version decides, on both phones (12 Nov 2026: "remove the build
      // number. it is just the version of app will be remain seen in any
      // platforms"): a rebuild of the version installed is not offered, as
      // it would read "1.12.37 is ready" on 1.12.37.
      final installed = installedVersionOverride ?? AppVersion.version;
      final newer =
          installed.isEmpty || isNewerVersion(release.version, than: installed);
      if (!supported) {
        // An iPhone: nothing to download.
        return newer ? UpdateAvailable(release) : const UpToDate();
      }
      if (!newer) {
        // Installed already: an APK still waiting in the cache, or still
        // downloading, is not needed any more.
        await _cancelBackground();
        await _clearDownloads();
        return const UpToDate();
      }
      _found = release;
      // Android may be downloading it already, from an earlier tap: the sheet
      // follows that download rather than clearing it away.
      if (await _runningFor(release) != null) {
        return UpdateAvailable(release, downloading: true);
      }
      return UpdateAvailable(release, downloaded: await _keepOnly(release));
    } on FormatException catch (_) {
      return const UpdateCheckFailed('BAD_RELEASE');
    } on TimeoutException catch (_) {
      return const UpdateCheckFailed('NETWORK_FAILURE');
    } on SocketException catch (_) {
      return const UpdateCheckFailed('NETWORK_FAILURE');
    } on http.ClientException catch (_) {
      return const UpdateCheckFailed('NETWORK_FAILURE');
    } finally {
      client.close();
    }
  }

  /// Hand the release the last [check] found to Android's installer,
  /// downloading it first unless a whole copy is already waiting — so
  /// calling this again after the install dialog was closed reopens it at
  /// once. [onProgress] hears the share downloaded, 0 to 1, or null when the
  /// size is not known yet. [onState] hears where Android's background
  /// download is; while [watching] says yes, this follows it, and when it
  /// says no (the sheet closed), this returns and Android carries on alone.
  /// Throws [UpdateInstallFailed].
  static Future<void> install(
    ValueChanged<double?> onProgress, {
    ValueChanged<UpdateDownloadState>? onState,
    bool Function()? watching,
  }) async {
    final stand = installOverride;
    if (stand != null) return stand(onProgress);
    final release = _found;
    if (release == null) {
      throw const UpdateInstallFailed('UPDATE_NOT_AVAILABLE');
    }
    final client = _client();
    File? apk;
    File? part;
    try {
      final dir = await _downloads();
      apk = File('${dir.path}${Platform.pathSeparator}${release.apk}');
      // Android's download already under way, from an earlier tap; else a
      // whole copy waiting; else a new download, by Android when it can.
      final running = await _runningFor(release);
      final whole = running == null && await _keepOnly(release);
      final background =
          running ?? (whole ? null : await _startInBackground(release));
      if (whole) {
        onProgress(1);
      } else if (background != null) {
        final done = await _watch(
          background,
          release,
          onProgress,
          onState,
          watching,
        );
        // The sheet closed: Android carries on, and says when it is done.
        if (done == null) return;
        apk = done;
      } else {
        // Written beside its final name and renamed once whole, so a file
        // with the final name is always a complete download.
        part = File('${apk.path}.part');
        final request = http.Request('GET', release.apkUrl)
          ..headers.addAll(_headers);
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw const UpdateInstallFailed('DOWNLOAD_FAILURE');
        }
        onProgress(0);
        final sink = part.openWrite();
        var received = 0;
        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 30),
          )) {
            sink.add(chunk);
            received += chunk.length;
            onProgress((received / release.size).clamp(0.0, 1.0));
          }
        } finally {
          await sink.close();
        }
        if (received != release.size) {
          throw const UpdateInstallFailed('DOWNLOAD_FAILURE');
        }
        await part.rename(apk.path);
        part = null;
      }
      // Android lets only the app in front open the installer: a download
      // that finished with RepLiT behind others waits for it to come back.
      await _inFront();
      // Kept after the hand-off: if the install dialog is closed, the same
      // file opens it again.
      await _channel.invokeMethod<bool>('install', {
        'path': apk.path,
        'sha256': release.sha256,
      });
    } on UpdateInstallFailed {
      rethrow;
    } on PlatformException catch (e) {
      // A copy that does not match the release is no use to anyone; the next
      // try downloads it afresh. (MainActivity deletes it too.)
      if (e.code == 'CORRUPT') {
        await _cancelBackground();
        await _delete(apk);
      }
      throw UpdateInstallFailed(e.code);
    } on MissingPluginException catch (_) {
      throw const UpdateInstallFailed('UNAVAILABLE');
    } on TimeoutException catch (_) {
      throw const UpdateInstallFailed('DOWNLOAD_FAILURE');
    } on SocketException catch (_) {
      throw const UpdateInstallFailed('DOWNLOAD_FAILURE');
    } on http.ClientException catch (_) {
      throw const UpdateInstallFailed('DOWNLOAD_FAILURE');
    } on FileSystemException catch (_) {
      throw const UpdateInstallFailed('DOWNLOAD_FAILURE');
    } finally {
      client.close();
      // A half-finished download is no use to anyone.
      await _delete(part);
    }
  }

  static Future<void> _delete(File? file) async {
    try {
      await file?.delete();
    } on FileSystemException catch (_) {}
  }

  /// How often the sheet asks Android how far its download is.
  @visibleForTesting
  static Duration pollEvery = const Duration(milliseconds: 500);

  /// Hand [release]'s download to Android's DownloadManager: its id, or null
  /// when this phone or build cannot (then the app downloads it itself).
  static Future<int?> _startInBackground(AvailableRelease release) async {
    try {
      return await _channel.invokeMethod<int>('startDownload', {
        'url': release.apkUrl.toString(),
        'file': release.apk,
        // In the notification shade while it downloads.
        'title': t('RepLiT {v}', {'v': release.label}),
        'description': t('Downloading the update'),
        // The notification once it is done, in the person's language and
        // their "New Update!" channel.
        'readyTitle': t('The update is downloaded'),
        'readyText': t('Tap to install RepLiT {v}.', {'v': release.label}),
        'channel': LanguageChoice.tagalog
            ? 'app_update_tl_v1'
            : 'app_update_en_v1',
      });
    } on Object catch (_) {
      return null;
    }
  }

  /// Android's download of [release], while it is under way (queued,
  /// downloading or waiting for a connection). One for another release, or
  /// one that failed, is cancelled; a finished one is left for [_keepOnly].
  static Future<int?> _runningFor(AvailableRelease release) async {
    try {
      final pending = await _channel.invokeMapMethod<String, Object?>(
        'pendingDownload',
      );
      final id = (pending?['id'] as num?)?.toInt();
      if (pending == null || id == null) return null;
      final status = await _status(id);
      if (pending['file'] != release.apk ||
          status == null ||
          status.state == 'failed') {
        await _cancelBackground();
        return null;
      }
      return status.state == 'successful' ? null : id;
    } on Object catch (_) {
      // No DownloadManager to ask (an iPhone, a test): nothing under way.
      return null;
    }
  }

  /// Follow Android's download [id] of [release] until it is whole, and
  /// return the file; null when [watching] says the sheet has gone.
  static Future<File?> _watch(
    int id,
    AvailableRelease release,
    ValueChanged<double?> onProgress,
    ValueChanged<UpdateDownloadState>? onState,
    bool Function()? watching,
  ) async {
    while (true) {
      final status = await _status(id);
      if (status == null || status.state == 'failed') {
        await _cancelBackground();
        throw const UpdateInstallFailed('DOWNLOAD_FAILURE');
      }
      if (status.state == 'successful') {
        final path = status.path;
        final file = path == null ? null : File(path);
        if (file == null ||
            !await file.exists() ||
            await file.length() != release.size) {
          await _cancelBackground();
          throw const UpdateInstallFailed('DOWNLOAD_FAILURE');
        }
        onProgress(1);
        return file;
      }
      onState?.call(
        status.state == 'paused'
            ? UpdateDownloadState.waiting
            : UpdateDownloadState.background,
      );
      onProgress(
        status.total > 0 ? (status.bytes / status.total).clamp(0.0, 1.0) : null,
      );
      if (watching != null && !watching()) return null;
      await Future<void>.delayed(pollEvery);
    }
  }

  /// Where Android's download [id] is: queued (`pending`), `running`,
  /// `paused` (waiting for a connection), `successful` or `failed`; null when
  /// Android no longer has it (cancelled from the notification shade).
  static Future<({String state, int bytes, int total, String? path})?> _status(
    int id,
  ) async {
    final s = await _channel.invokeMapMethod<String, Object?>(
      'downloadStatus',
      {'id': id},
    );
    if (s == null) return null;
    return (
      state: s['status'] as String? ?? 'failed',
      bytes: (s['bytes'] as num?)?.toInt() ?? 0,
      total: (s['total'] as num?)?.toInt() ?? 0,
      path: s['path'] as String?,
    );
  }

  /// Stop Android's download, if there is one, and forget it. Never throws.
  static Future<void> _cancelBackground() async {
    try {
      await _channel.invokeMethod<void>('cancelDownload');
    } on Object catch (_) {}
  }

  /// Wait until RepLiT is in front.
  static Future<void> _inFront() async {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) return;
    final back = Completer<void>();
    final listener = AppLifecycleListener(
      onResume: () {
        if (!back.isCompleted) back.complete();
      },
    );
    try {
      await back.future;
    } finally {
      listener.dispose();
    }
  }

  /// Opens "Check for updates" when the "downloaded" notification is tapped
  /// (main.dart sets it).
  static VoidCallback? onOpenRequested;

  /// Listen for that notification's tap: with RepLiT running, MainActivity
  /// says so at once; one that started RepLiT is asked for once it runs.
  static Future<void> listenForOpen() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments == 'updates') {
        onOpenRequested?.call();
      }
    });
    try {
      final open = await _channel.invokeMethod<String>('takeOpen');
      if (open != 'updates') return;
      // Let the splash route home first, as a tapped alert does.
      await Future<void>.delayed(const Duration(milliseconds: 1700));
      onOpenRequested?.call();
    } on Object catch (_) {
      // Not Android, or an older MainActivity: nothing to open.
    }
  }

  /// Clear out every download except a whole copy of [release]'s APK, and
  /// say whether that copy is there. Never throws.
  static Future<bool> _keepOnly(AvailableRelease release) async {
    try {
      final dir = await _downloads();
      var whole = false;
      await for (final entry in dir.list()) {
        if (entry is! File) continue;
        final name = entry.uri.pathSegments.last;
        if (name == release.apk && await entry.length() == release.size) {
          whole = true;
        } else {
          await entry.delete();
        }
      }
      return whole;
    } on Object catch (_) {
      return false;
    }
  }

  /// cache/updates, the one folder MainActivity's installer hand-off reads.
  static Future<Directory> _downloads() async {
    final path = await _channel.invokeMethod<String>('updatesDir');
    if (path == null) throw const UpdateInstallFailed('UNAVAILABLE');
    return Directory(path);
  }

  /// One update waits at a time; an APK from an earlier install goes.
  static Future<void> _clearDownloads() async {
    try {
      final dir = await _downloads();
      await for (final old in dir.list()) {
        if (old is File) await old.delete();
      }
    } on Object catch (_) {
      // Nothing to clear, or no platform to ask (tests): fine either way.
    }
  }

  /// What a failure means for the person holding the phone.
  static String explain(String code) => switch (code) {
    'NETWORK_FAILURE' => t('No connection. Check your internet and try again.'),
    'DOWNLOAD_FAILURE' => t(
      "The download didn't finish. Check your connection and try again.",
    ),
    'CORRUPT' => t('The download was damaged on the way. Try again.'),
    'BAD_RELEASE' => t(
      "The newest release can't be read. Please tell the RepLiT team.",
    ),
    'UNAVAILABLE' || 'NOT_IMPLEMENTED' => t(
      "This build can't install updates. Ask the RepLiT team for the "
      'newest one.',
    ),
    'INSTALLATION_FAILURE' => t(
      "Android couldn't open the installer. Try again in a little while.",
    ),
    'UPDATE_NOT_AVAILABLE' => t('You already have the newest version.'),
    _ => t("Couldn't check for updates. Try again in a little while."),
  };
}

/// Open the "Check for updates" sheet; it checks at once. A Google Play copy
/// (v1.12.44) opens its Play Store page instead: Play updates it.
Future<void> showUpdateSheet(BuildContext context) {
  if (StoreBuild.play) return StoreBuild.openPlayListing();
  return _showUpdateSheet(context);
}

Future<void> _showUpdateSheet(BuildContext context) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: context.pal.surfaceSolid,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
  ),
  builder: (_) => const SafeArea(child: UpdateSheet()),
);

/// The sheet: checking, then up to date, a newer build to install, or why
/// it could not tell.
class UpdateSheet extends StatefulWidget {
  const UpdateSheet({super.key});

  /// Whether the sheet is open: the "downloaded" notification's tap does not
  /// open a second one over it.
  static bool isShowing = false;

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

enum _Stage { checking, upToDate, available, installing, installed, failed }

class _UpdateSheetState extends State<UpdateSheet> {
  _Stage _stage = _Stage.checking;
  AvailableRelease? _release;
  String? _problem;
  double? _progress;

  /// A whole copy of [_release] is waiting in the cache, so installing only
  /// opens Android's installer.
  bool _downloaded = false;

  /// Where Android's background download is, once it has it; null while the
  /// app downloads it itself.
  UpdateDownloadState? _background;

  @override
  void initState() {
    super.initState();
    UpdateSheet.isShowing = true;
    unawaited(_check());
  }

  @override
  void dispose() {
    UpdateSheet.isShowing = false;
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _stage = _Stage.checking;
      _problem = null;
    });
    final found = await AppUpdates.check();
    if (!mounted) return;
    setState(() {
      switch (found) {
        case UpToDate():
          _stage = _Stage.upToDate;
        case UpdateAvailable(:final release, :final downloaded):
          _release = release;
          _downloaded = downloaded;
          _stage = _Stage.available;
        case UpdateCheckFailed(:final code):
          _problem = AppUpdates.explain(code);
          _stage = _Stage.failed;
      }
    });
    // Already downloading in the background: show how far it is.
    if (found case UpdateAvailable(downloading: true)) unawaited(_install());
  }

  Future<void> _install() async {
    setState(() {
      _stage = _Stage.installing;
      _progress = _downloaded ? 1 : null;
      _background = null;
    });
    try {
      await AppUpdates.install(
        (p) {
          if (mounted) setState(() => _progress = p);
        },
        onState: (state) {
          if (mounted && state != _background) {
            setState(() => _background = state);
          }
        },
        watching: () => mounted,
      );
      // The file stays in the cache after the hand-off, for "Open the
      // installer again".
      if (mounted) {
        setState(() {
          _downloaded = true;
          _stage = _Stage.installed;
        });
      }
    } on UpdateInstallFailed catch (e) {
      if (!mounted) return;
      setState(() {
        // Anything but a refused copy is still there to try again with.
        if (e.code == 'CORRUPT') _downloaded = false;
        _problem = AppUpdates.explain(e.code);
        _stage = _Stage.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final installed = AppVersion.label;
    final release = _release;
    return FrozenHandleSheet(
      children: [
        Text(t('CHECK FOR UPDATES'), style: context.type.title),
        if (installed.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            t('Installed: version {v}', {'v': installed}),
            style: context.type.caption.copyWith(color: pal.label),
          ),
        ],
        const SizedBox(height: 18),
        ...switch (_stage) {
          _Stage.checking => [
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),
            Text(t('Looking for a newer version…'), style: context.type.body),
          ],
          _Stage.upToDate => [
            _Status(
              icon: AppIcons.checkCircle,
              tint: pal.ok,
              text: t('You have the latest version.'),
            ),
          ],
          _Stage.available => [
            _Status(
              icon: AppIcons.download,
              tint: pal.accent,
              text: _downloaded
                  ? t('Version {v} is downloaded and ready to install.', {
                      'v': release!.label,
                    })
                  : t('Version {v} is ready.', {'v': release!.label}),
            ),
            if (release.size > 0 && !_downloaded) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(
                  t('Download: {size}. Wi-Fi is best.', {
                    'size': release.sizeLabel,
                  }),
                  style: context.type.caption.copyWith(color: pal.label),
                ),
              ),
            ],
            if ((release.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                release.notes!,
                maxLines: 12,
                overflow: TextOverflow.ellipsis,
                style: context.type.bodySm.copyWith(color: pal.textSoft),
              ),
            ],
            const SizedBox(height: 20),
            AppButton(
              _downloaded ? t('Install') : t('Download and install'),
              icon: AppIcons.download,
              onPressed: _install,
            ),
          ],
          _Stage.installing => [
            LinearProgressIndicator(value: _progress, minHeight: 3),
            const SizedBox(height: 12),
            Text(
              _downloaded
                  ? t('Opening the installer…')
                  : _background == UpdateDownloadState.waiting
                  ? t('Waiting for a connection…')
                  : _progress == null
                  ? t('Downloading…')
                  : t('Downloading… {n}%', {'n': (_progress! * 100).round()}),
              style: context.type.body,
            ),
            const SizedBox(height: 6),
            Text(
              _background != null && !_downloaded
                  // Android has the download: leaving does not stop it.
                  ? t(
                      'You can leave RepLiT. The download carries on, its '
                      'progress is in your notifications, and RepLiT tells '
                      'you when it is ready to install.',
                    )
                  : t(
                      'Android will ask you to confirm the install. The first '
                      'time, it also asks you to allow installs from RepLiT.',
                    ),
              style: context.type.caption.copyWith(color: pal.label),
            ),
          ],
          _Stage.installed => [
            _Status(
              icon: AppIcons.checkCircle,
              tint: pal.ok,
              text: t(
                'Downloaded. Finish the install in the window Android '
                'opened.',
              ),
            ),
            const SizedBox(height: 20),
            // Closed the install window, or tapped Cancel: the same download
            // opens it again.
            AppButton.secondary(
              t('Open the installer again'),
              icon: AppIcons.openInNew,
              onPressed: _install,
            ),
          ],
          _Stage.failed => [
            _Status(
              icon: AppIcons.error,
              tint: pal.live,
              text: _problem ?? AppUpdates.explain(''),
            ),
            const SizedBox(height: 20),
            AppButton.secondary(
              t('Try again'),
              icon: AppIcons.refresh,
              onPressed: _release != null ? _install : _check,
            ),
          ],
        },
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.tint, required this.text});

  final IconData icon;
  final Color tint;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: tint),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: context.type.body)),
      ],
    );
  }
}
