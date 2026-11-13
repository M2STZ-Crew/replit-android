import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// App v1.12.41, with backend v1.12.32 (13 November 2026: "the "new update"
/// push notification doesn't work on my android phone"). The backend told
/// phones of a release at its next check, 10 minutes apart, and by then the
/// phone had updated from the banner. The release workflow now asks the
/// backend to check as soon as the release is published
/// (POST /app-updates/check), so "New Update!" goes within seconds.
void main() {
  final workflow = File(
    '.github/workflows/android-release.yml',
  ).readAsStringSync();
  const ask = 'Tell phones on an older version ("New Update!")';

  /// One step of the job: from its `- name:` to the next step's.
  String step(String name) {
    final start = workflow.indexOf('- name: $name');
    expect(start, isNonNegative, reason: 'no step "$name"');
    final next = workflow.indexOf('\n      - name: ', start + 1);
    return workflow.substring(start, next < 0 ? workflow.length : next);
  }

  test('the release asks for "New Update!" once it is published', () {
    final publish = workflow.indexOf(
      '- name: Publish on GitHub Releases',
    );
    expect(publish, isNonNegative);
    expect(workflow.indexOf('- name: $ask'), greaterThan(publish));

    final body = step(ask);
    expect(body, contains(r'url="${REPLIT_API_BASE%/}/app-updates/check"'));
    expect(body, contains(r'-X POST "$url"'));
    // Asked again until the backend names the version just published:
    // GitHub can name the new release a moment late.
    expect(body, contains(r'if [ "$found" = "$version" ]'));
    expect(body, contains('sleep 15'));
  });

  test('the ask never fails the release, and sends nothing', () {
    final body = step(ask);
    // The backend's own check, every 2 minutes, is there if it cannot be
    // reached.
    expect(body, contains('continue-on-error: true'));
    // The backend reads the release from GitHub; the ask carries no data
    // and no secret.
    expect(body, isNot(contains('secrets.')));
    expect(body, isNot(contains(' -d ')));
    expect(body, isNot(contains('--data')));
  });
}
