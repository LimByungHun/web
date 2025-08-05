import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:sign_web/service/token_storage.dart';

const String baseUrl = 'http://10.101.170.23';

class DeleteUserApi {
  static Future<bool> deleteUser({
    required String password,
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/delete_user');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Refresh-Token': refreshToken,
        },
        body: jsonEncode({'password': password}),
      );

      final newAccessToken = response.headers['x-new-access-token'];
      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        await TokenStorage.setAccessToken(newAccessToken);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final success = data['success'];

        return success;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('회원탈퇴 오류: $e');
      return false;
    }
  }
}
