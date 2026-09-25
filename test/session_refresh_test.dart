import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An access token lasts about an hour, so an app left alone overnight wakes up
/// with a dead one. It used to stay dead: the request failed, the stored token
/// was never renewed or cleared, and every retry re-sent it. The only way back
/// in was to clear the app's data from Android settings.
///
/// These drive the exact sequence — a 401, then whatever the client does next.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Session.instance.setTokens(
      accessToken: 'expired-token',
      refreshToken: 'refresh-token',
      email: 'someone@example.com',
    );
  });

  String tokens(String access) => jsonEncode({
    'access_token': access,
    'refresh_token': 'rotated-refresh-token',
    'token_type': 'bearer',
    'user_id': '00000000-0000-0000-0000-000000000001',
    'email': 'someone@example.com',
  });

  const profile = {'id': 'u1', 'role': 'general_user', 'full_name': 'Ana'};

  test('an expired token is renewed and the request replayed', () async {
    final seen = <String>[];
    final api = ApiClient(
      client: MockClient((req) async {
        seen.add('${req.method} ${req.url.path}');
        if (req.url.path.endsWith('/auth/refresh')) {
          return http.Response(tokens('fresh-token'), 200);
        }
        // /auth/me: reject the stale token, accept the renewed one.
        final auth = req.headers['Authorization'];
        return auth == 'Bearer fresh-token'
            ? http.Response(jsonEncode(profile), 200)
            : http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
      }),
    );

    final me = await api.getMe();

    expect(me['full_name'], 'Ana');
    expect(seen, ['GET /auth/me', 'POST /auth/refresh', 'GET /auth/me']);
    // The renewed token is kept, so the next launch does not start over.
    expect(Session.instance.accessToken, 'fresh-token');
    expect(Session.instance.refreshToken, 'rotated-refresh-token');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), 'fresh-token');
  });

  test('a dead refresh token clears the session instead of keeping it', () async {
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return http.Response(jsonEncode({'message': 'Invalid'}), 401);
        }
        return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
      }),
    );

    await expectLater(api.getMe(), throwsA(isA<SessionExpiredException>()));

    // Leaving dead credentials on the device is what made this stick: the app
    // looked signed in, every call failed, and clearing app data was the only fix.
    expect(Session.instance.isAuthenticated, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), isNull);
  });

  test('no refresh token at all is not retried, just ended', () async {
    Session.instance.setTokens(accessToken: 'expired-token');
    var refreshes = 0;
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) refreshes++;
        return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
      }),
    );

    await expectLater(api.getMe(), throwsA(isA<SessionExpiredException>()));
    expect(refreshes, 0);
  });

  test('concurrent calls share one refresh, because the token rotates', () async {
    // Supabase retires a refresh token the moment it is used, so two parallel
    // refreshes would race and the loser would present a retired token.
    var refreshes = 0;
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(tokens('fresh-token'), 200);
        }
        return req.headers['Authorization'] == 'Bearer fresh-token'
            ? http.Response(jsonEncode(profile), 200)
            : http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
      }),
    );

    await Future.wait([api.getMe(), api.getMe(), api.getMe()]);

    expect(refreshes, 1);
  });

  _wrongServerTests();

  test('a server error is not mistaken for an expired session', () async {
    var refreshes = 0;
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) refreshes++;
        return http.Response(jsonEncode({'message': 'Server error'}), 500);
      }),
    );

    await expectLater(api.getMe(), throwsA(isA<ApiException>()));
    // A 500 or a dropped connection must leave the session alone: signing the
    // user out because the backend was briefly down would be its own bug.
    expect(refreshes, 0);
    expect(Session.instance.isAuthenticated, isTrue);
  });
}

/// A build carries its backend address, baked in at compile time. One shipped
/// pointing at `onrender.co` instead of `onrender.com` — someone else's domain,
/// which answers with a redirect to a page of HTML. The app then tried to read
/// that HTML as JSON, threw a FormatException nobody caught by type, and every
/// screen reported it as "could not reach the server". The cause was invisible
/// to the person holding the phone and to anyone helping them.
void _wrongServerTests() {
  group('pointed at the wrong server', () {
    test('an HTML reply says the address is wrong, and names it', () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response('<html><body>Redirecting to another site</body></html>', 200),
        ),
      );

      await expectLater(
        api.getMe(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            allOf(contains('did not reply with RepLiT data'), contains('install')),
          ),
        ),
      );
    });

    test('an empty body is still fine, since some endpoints return none', () async {
      final api = ApiClient(client: MockClient((_) async => http.Response('', 200)));
      expect(await api.getMe(), isEmpty);
    });
  });
}
