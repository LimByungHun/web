import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:sign_web/service/token_storage.dart';

const String baseUrl = 'http://10.101.170.142';

class PasswordResetApi {
  // userID 존재 여부 확인
  static Future<bool> checkUserIDExists(String userID) async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    if (accessToken == null || refreshToken == null) {
      throw Exception("토큰 없음");
    }

    final response = await http.get(
      Uri.parse("$baseUrl/user/check_id?id=$userID"),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Refresh-Token': refreshToken,
      },
    );

    final newAccessToken = response.headers['x-new-access-token'];
    if (newAccessToken != null && newAccessToken.isNotEmpty) {
      await TokenStorage.setAccessToken(newAccessToken);
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return !data['available'];
    } else {
      throw Exception("ID 존재 확인 실패: ${response.statusCode}");
    }
  }

  // 비밀번호 재설정
  static Future<bool> resetPassword({
    required String userID,
    required String newPassword,
  }) async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    if (accessToken == null || refreshToken == null) {
      throw Exception("토큰 없음");
    }

    final response = await http.put(
      Uri.parse('$baseUrl/user/reset_password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Refresh-Token': refreshToken,
      },
      body: jsonEncode({'user_id': userID, 'new_password': newPassword}),
    );

    final newAccessToken = response.headers['x-new-access-token'];
    if (newAccessToken != null && newAccessToken.isNotEmpty) {
      await TokenStorage.setAccessToken(newAccessToken);
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } else {
      Fluttertoast.showToast(msg: '비밀번호 재설정 실패');
      // print("비밀번호 재설정 실패: ${response.statusCode}");
      return false;
    }
  }
}
