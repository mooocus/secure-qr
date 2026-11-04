
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class QrService {
  // Android emulator -> FastAPI on development PC
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<String> requestSignedQR(
    String roomId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User is not logged in');
    }

    final firebaseToken = await user.getIdToken();

    final response = await http.post(
      Uri.parse('$baseUrl/qr/issue'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $firebaseToken',
      },
      body: jsonEncode({
        'room_id': roomId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'QR request failed (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body);
    return data['token'] as String;
  }
}
