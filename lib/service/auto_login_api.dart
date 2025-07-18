import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://10.101.170.63';

class AutoLoginApi {
  static Future<bool> autoLogin(String refreshToken) async {
    try {
      final url = Uri.parse('$baseUrl/user/auto_login');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final success = data['success'];
        return success == true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
