import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';

/// App v1.12.36 (12 November 2026), with backend v1.12.28: someone of an
/// organisation the central hub suspended or revoked is told why, where
/// their account would have loaded.
void main() {
  Future<ApiException> refusal(String code) async {
    SharedPreferences.setMockInitialValues({'access_token': 't'});
    await Session.instance.restore();
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'error': code, 'message': 'in English'}),
          403,
        ),
      ),
    );
    try {
      await api.getMe();
    } on ApiException catch (e) {
      return e;
    } finally {
      await Session.instance.clear();
    }
    fail('no refusal');
  }

  test('a suspended organisation is said in the app\'s words', () async {
    final e = await refusal('organization_suspended');
    expect(frozenOrganization(e), isTrue);
    expect(e.message, contains('suspended'));
    expect(e.message, contains('Barangay 76'));
  });

  test('a revoked one too', () async {
    final e = await refusal('organization_revoked');
    expect(frozenOrganization(e), isTrue);
    expect(e.message, contains('removed from RepLiT'));
  });

  test('anything else is not taken for it', () async {
    final e = await refusal('forbidden');
    expect(frozenOrganization(e), isFalse);
    expect(frozenOrganization(Exception('offline')), isFalse);
  });
}
