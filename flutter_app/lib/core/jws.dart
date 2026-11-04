// Minimal ES256 (ECDSA P-256 + SHA-256) helpers for compact JWS tokens.
//
// Pure Dart (no Flutter / plugins) so the same code can be reused by the
// scanner app and covered by unit tests.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// The NIST P-256 curve used by ES256.
final ECDomainParameters p256 = ECCurve_secp256r1();

// ---------------------------------------------------------------------------
// Encoding helpers
// ---------------------------------------------------------------------------

String b64url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List b64urlDecode(String input) {
  final padded = input.padRight(input.length + (4 - input.length % 4) % 4, '=');
  return base64Url.decode(padded);
}

String b64urlJson(Map<String, dynamic> json) =>
    b64url(utf8.encode(jsonEncode(json)));

Map<String, dynamic> b64urlJsonDecode(String part) =>
    jsonDecode(utf8.decode(b64urlDecode(part))) as Map<String, dynamic>;

Uint8List bigIntToBytes(BigInt value, int length) {
  final out = Uint8List(length);
  var v = value;
  for (var i = length - 1; i >= 0; i--) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  return out;
}

BigInt bytesToBigInt(List<int> bytes) {
  var result = BigInt.zero;
  for (final b in bytes) {
    result = (result << 8) | BigInt.from(b);
  }
  return result;
}

Uint8List sha256(List<int> data) =>
    SHA256Digest().process(Uint8List.fromList(data));

/// Cryptographically secure random identifier (used for JTIs, salts, IDs).
String randomId([int bytes = 16]) {
  final rnd = Random.secure();
  return b64url(List<int>.generate(bytes, (_) => rnd.nextInt(256)));
}

SecureRandom _secureRandom() {
  final rnd = Random.secure();
  final seed = Uint8List.fromList(List<int>.generate(32, (_) => rnd.nextInt(256)));
  return FortunaRandom()..seed(KeyParameter(seed));
}

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

/// A P-256 key pair. [d] is the private scalar, ([x], [y]) the public point.
class EcKeyPair {
  EcKeyPair(this.d, this.x, this.y);

  final BigInt d;
  final BigInt x;
  final BigInt y;

  factory EcKeyPair.generate() {
    final generator = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(p256), _secureRandom()));
    final pair = generator.generateKeyPair();
    final privateKey = pair.privateKey;
    final publicKey = pair.publicKey;
    return EcKeyPair(
      privateKey.d!,
      publicKey.Q!.x!.toBigInteger()!,
      publicKey.Q!.y!.toBigInteger()!,
    );
  }

  /// Public key as a JSON Web Key (safe to share).
  Map<String, String> get publicJwk => {
        'kty': 'EC',
        'crv': 'P-256',
        'x': b64url(bigIntToBytes(x, 32)),
        'y': b64url(bigIntToBytes(y, 32)),
      };

  /// Short key id derived from the public key.
  String get kid => b64url(sha256([...bigIntToBytes(x, 32), ...bigIntToBytes(y, 32)]).sublist(0, 8));

  Map<String, String> toStorage() => {
        'd': d.toRadixString(16),
        'x': x.toRadixString(16),
        'y': y.toRadixString(16),
      };

  factory EcKeyPair.fromStorage(Map<String, dynamic> json) => EcKeyPair(
        BigInt.parse(json['d'] as String, radix: 16),
        BigInt.parse(json['x'] as String, radix: 16),
        BigInt.parse(json['y'] as String, radix: 16),
      );
}

// ---------------------------------------------------------------------------
// JWS sign / verify
// ---------------------------------------------------------------------------

/// Signs [payload] and returns a compact JWS: header.payload.signature
String signJws({
  required Map<String, dynamic> header,
  required Map<String, dynamic> payload,
  required EcKeyPair key,
}) {
  final signingInput = '${b64urlJson({...header, 'alg': 'ES256'})}.${b64urlJson(payload)}';
  // Deterministic ECDSA (RFC 6979) – no extra randomness needed when signing.
  final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
    ..init(true, PrivateKeyParameter<ECPrivateKey>(ECPrivateKey(key.d, p256)));
  final sig = signer.generateSignature(Uint8List.fromList(utf8.encode(signingInput))) as ECSignature;
  final raw = [...bigIntToBytes(sig.r, 32), ...bigIntToBytes(sig.s, 32)];
  return '$signingInput.${b64url(raw)}';
}

/// A JWS split into its parts (signature NOT yet verified).
class DecodedJws {
  DecodedJws._(this.header, this.payload, this._parts);

  final Map<String, dynamic> header;
  final Map<String, dynamic> payload;
  final List<String> _parts;

  /// Throws [FormatException] if the token is not a well-formed JWS.
  factory DecodedJws.parse(String token) {
    final parts = token.trim().split('.');
    if (parts.length != 3) throw const FormatException('Not a compact JWS');
    try {
      return DecodedJws._(b64urlJsonDecode(parts[0]), b64urlJsonDecode(parts[1]), parts);
    } catch (_) {
      throw const FormatException('Invalid JWS encoding');
    }
  }

  /// Verifies the ES256 signature with the given public JWK.
  bool verifyWith(Map<String, dynamic> jwk) {
    try {
      if (header['alg'] != 'ES256') return false; // reject alg=none etc.
      if (jwk['kty'] != 'EC' || jwk['crv'] != 'P-256') return false;
      final sig = b64urlDecode(_parts[2]);
      if (sig.length != 64) return false;
      final q = p256.curve.createPoint(
        bytesToBigInt(b64urlDecode(jwk['x'] as String)),
        bytesToBigInt(b64urlDecode(jwk['y'] as String)),
      );
      final verifier = ECDSASigner(SHA256Digest())
        ..init(false, PublicKeyParameter<ECPublicKey>(ECPublicKey(q, p256)));
      return verifier.verifySignature(
        Uint8List.fromList(utf8.encode('${_parts[0]}.${_parts[1]}')),
        ECSignature(bytesToBigInt(sig.sublist(0, 32)), bytesToBigInt(sig.sublist(32))),
      );
    } catch (_) {
      return false;
    }
  }
}
