import 'dart:convert';

/// Issuer-signed, short-lived QR credential. This code only parses JWT claims;
/// cryptographic verification belongs to the trusted verifier/backend.
const int passValiditySeconds = 30;
const int defaultClockSkewSeconds = 2;

int nowSeconds() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

class PassToken {
  const PassToken({
    required this.token,
    required this.jti,
    required this.issuedAt,
    required this.expiresAt,
  });

  final String token;
  final String jti;
  final int issuedAt;
  final int expiresAt;

  factory PassToken.fromBackendJwt(String token) {
    if (token.length > 4096) {
      throw const FormatException('JWT too large');
    }
    final parts = token.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
      throw const FormatException('Invalid JWT structure');
    }
    final payloadJson = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final payload = jsonDecode(payloadJson);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid JWT payload');
    }
    final jti = payload['jti'];
    final iat = payload['iat'];
    final exp = payload['exp'];
    final nbf = payload['nbf'];
    if (jti is! String || jti.isEmpty || iat is! int || exp is! int || nbf is! int) {
      throw const FormatException('Invalid JWT claims');
    }
    if (exp - iat != passValiditySeconds || nbf > iat || exp <= nowSeconds()) {
      throw const FormatException('Expired or invalid JWT lifetime');
    }
    if (payload['token_use'] != 'facility_access') {
      throw const FormatException('Unexpected token type');
    }
    return PassToken(token: token, jti: jti, issuedAt: iat, expiresAt: exp);
  }
}
