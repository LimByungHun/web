import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sign_web/service/token_storage.dart';

const String baseUrl = 'http://10.101.170.12';

class UpdateUserApi {
  static Future<Map<String, dynamic>> updateUser({
    required String name,
    required String newPassword,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/user/update');
      final accessToken = await TokenStorage.getAccessToken() ?? '';
      final refreshToken = await TokenStorage.getRefreshToken() ?? '';

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Refresh-Token': refreshToken,
        },
        body: jsonEncode({'name': name, 'new_password': newPassword}),
      );

      final newAccessToken = response.headers['x-new-access-token'];
      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        await TokenStorage.setAccessToken(newAccessToken);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data;
      } else {
        return {'success': false};
      }
    } catch (e) {
      return {'success': false};
    }
  }
}
