import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = 'http://10.101.170.63';

class LoginResult {
  final bool success;
  final String? accessToken;
  final String? refreshToken;
  final String? expiresAt;
  final String? error;
  final String? nickname;
  final String? userID;

  LoginResult({
    required this.success,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.error,
    this.nickname,
    this.userID,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      success: json['success'] ?? false,
      userID: json['userID'],
      nickname: json['nickname'],
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      expiresAt: json['expires_at'],
      error: json['error'],
    );
  }
}

class LoginApi {
  static Future<LoginResult> login(String id, String password) async {
    final url = Uri.parse('$baseUrl/user/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'pw': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LoginResult.fromJson(data);
      } else {
        return LoginResult(success: false, error: '서버 오류');
      }
    } catch (e) {
      return LoginResult(success: false, error: '네트워크 오류');
    }
  }
}
