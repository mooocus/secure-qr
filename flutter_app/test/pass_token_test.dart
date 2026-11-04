
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_app/core/pass_token.dart';

String makeTestJwt(Map<String, dynamic> payload) {
  final header = {
    'alg': 'ES256',
    'typ': 'facility-access+jwt',
    'kid': 'test-key'
  };

  String encode(Map<String, dynamic> value) {
    return base64Url
        .encode(utf8.encode(jsonEncode(value)))
        .replaceAll('=', '');
  }

  return '${encode(header)}.${encode(payload)}.test-signature';
}

void main() {
  group('Backend-issued JWT display model', () {

    test('JWT contains expected expiration', () {
      final now = nowSeconds();

      final jwt = makeTestJwt({
        'sub': 'test-user',
        'jti': 'unique-token-123',
        'iat': now,
        'exp': now + 30,
      });

      final expiry = peekExpiry(jwt);

      expect(expiry, now + 30);
    });

    test('Different tokens contain different JTIs', () {
      final now = nowSeconds();

      final jwt1 = makeTestJwt({
        'sub': 'test-user',
        'jti': 'token-001',
        'iat': now,
        'exp': now + 30,
      });

      final jwt2 = makeTestJwt({
        'sub': 'test-user',
        'jti': 'token-002',
        'iat': now,
        'exp': now + 30,
      });

      expect(jwt1, isNot(jwt2));
    });

    test('Expired JWT returns past expiration', () {
      final now = nowSeconds();

      final jwt = makeTestJwt({
        'sub': 'test-user',
        'jti': 'expired-token',
        'iat': now - 60,
        'exp': now - 30,
      });

      final expiry = peekExpiry(jwt);

      expect(expiry, lessThan(now));
    });

    test('Malformed JWT returns no expiry', () {
      final expiry = peekExpiry(
        'not-a-valid-jwt',
      );

      expect(expiry, isNull);
    });

    test('PassToken stores backend-issued JWT', () {
      final now = nowSeconds();

      final pass = PassToken(
        token: 'backend-signed-jwt',
        jti: 'jti-001',
        issuedAt: now,
        expiresAt: now + 30,
      );

      expect(pass.token, 'backend-signed-jwt');
      expect(pass.jti, 'jti-001');
      expect(pass.issuedAt, now);
      expect(pass.expiresAt, now + 30);
    });

    test('JWT lifetime is 30 seconds', () {
      expect(passValiditySeconds, 30);
    });
  });
}

int? peekExpiry(String jwt) {
  try {
    final parts = jwt.split('.');

    if (parts.length != 3) {
      return null;
    }

    final payloadJson = utf8.decode(
      base64Url.decode(
        base64Url.normalize(parts[1]),
      ),
    );

    final payload =
        jsonDecode(payloadJson) as Map<String, dynamic>;

    final exp = payload['exp'];

    if (exp is int) {
      return exp;
    }

    return null;
  } catch (_) {
    return null;
  }
}
