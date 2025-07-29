import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sign_web/service/token_storage.dart';

const String baseUrl = 'http://10.101.170.12';

class BookmarkApi {
  // 북마크 추가
  static Future<bool> addBookmark({required int wid}) async {
    final url = Uri.parse("$baseUrl/bookmark/add");
    final accessToken = await TokenStorage.getAccessToken() ?? '';
    final refreshToken = await TokenStorage.getRefreshToken() ?? '';

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Refresh-Token': refreshToken,
      },
      body: jsonEncode({'wid': wid}),
    );

    final newToken = response.headers['x-new-access-token'];
    if (newToken != null && newToken.isNotEmpty) {
      await TokenStorage.setAccessToken(newToken);
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } else {
      print("addBookmark 실패: ${response.statusCode}");
      return false;
    }
  }

  // 북마크 삭제
  static Future<bool> removeBookmark({required int wid}) async {
    final url = Uri.parse("$baseUrl/bookmark/remove/$wid");
    final accessToken = await TokenStorage.getAccessToken() ?? '';
    final refreshToken = await TokenStorage.getRefreshToken() ?? '';

    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Refresh-Token': refreshToken,
      },
    );

    final newToken = response.headers['x-new-access-token'];
    if (newToken != null && newToken.isNotEmpty) {
      await TokenStorage.setAccessToken(newToken);
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } else {
      print("removeBookmark 실패: ${response.statusCode}");
      return false;
    }
  }

  // 북마크 보기
  static Future<Map<String, int>> loadBookmark() async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    if (accessToken == null) throw Exception("accessToken 없음");
    if (refreshToken == null) throw Exception("refreshToken 없음");

    final response = await http.get(
      Uri.parse("$baseUrl/bookmark/list"),
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
      final data = jsonDecode(response.body) as List<dynamic>;
      final Map<String, int> bookmarkedMap = {};
      for (final item in data) {
        bookmarkedMap[item['word']] = item['wid'];
      }
      return bookmarkedMap;
    } else {
      throw Exception("북마크 리스트 요청 실패: ${response.statusCode}");
    }
  }
}
