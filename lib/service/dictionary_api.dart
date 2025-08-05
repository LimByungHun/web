import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

const String baseUrl = 'http://10.101.170.23';

class WordData {
  final List<String> words;
  final Map<String, int> wordIDMap;

  WordData({required this.words, required this.wordIDMap});
}

class DictionaryApi {
  static Future<WordData> fetchWords() async {
    String? accessToken = await TokenStorage.getAccessToken();
    String? refreshToken = await TokenStorage.getRefreshToken();

    if (accessToken == null || refreshToken == null) {
      throw Exception('토큰 없음');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/dictionary/words'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Refresh-Token': refreshToken,
      },
    );

    final newAccessToken = response.headers['x-new-access-token'];
    if (newAccessToken != null) {
      final storedUserID = await TokenStorage.getUserID();
      final storedNickName = await TokenStorage.getNickName();
      await TokenStorage.saveTokens(
        newAccessToken,
        refreshToken,
        '',
        userID: storedUserID!,
        nickname: storedNickName!,
      );
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<String> words = [];
      final Map<String, int> wordidMap = {};

      for (final item in data) {
        final word = item['word'] as String;
        final wid = item['wid'] as int;
        words.add(word);
        wordidMap[word] = wid;
      }

      return WordData(words: words, wordIDMap: wordidMap);
    } else {
      throw Exception('단어 요청 실패 (${response.statusCode})');
    }
  }
}
