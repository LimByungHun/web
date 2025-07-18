import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sign_web/service/token_storage.dart';

const String baseUrl = 'http://10.101.168.10';

class WordDetailApi {
  static Future<Map<String, dynamic>> fetch({required int wid}) async {
    final accessToken = await TokenStorage.getAccessToken() ?? '';
    final refreshToken = await TokenStorage.getRefreshToken() ?? '';

    final uri = Uri.parse('$baseUrl/dictionary/words/detail?wid=$wid');

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Refresh-Token': refreshToken,
        'Content-Type': 'application/json',
      },
    );

    final newAccessToken = response.headers['x-new-access-token'];
    if (newAccessToken != null && newAccessToken.isNotEmpty) {
      await TokenStorage.setAccessToken(newAccessToken);
    }

    if (response.statusCode != 200) {
      throw Exception('단어 상세 정보를 불러오는 데 실패했습니다. (${response.statusCode})');
    }

    final jsonData = json.decode(response.body);
    return {
      "word": jsonData['word'] ?? '',
      "pos": jsonData['pos'] ?? '',
      "definition": jsonData['definition'] ?? '',
      "from": jsonData['from'] ?? '',
    };
  }
}
