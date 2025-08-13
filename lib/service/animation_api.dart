import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sign_web/service/token_storage.dart';

const String baseUrl = 'http://10.101.170.52';

class AnimationApi {
  static Future<List<String>?> loadAnimation(String wordText) async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    final url = Uri.parse("$baseUrl/animation?word_text=$wordText");

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Refresh-Token': refreshToken ?? '',
        },
      );

      final newToken = response.headers['x-new-access-token'];
      if (newToken != null && newToken.isNotEmpty) {
        await TokenStorage.setAccessToken(newToken);
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final frameList = (data['frames'] as List<dynamic>)
            .map((e) => e as String)
            .toList();

        return frameList;
      } else {
        debugPrint("프레임 요청 실패: ${response.statusCode} ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("프레임 요청 중 오류 발생: $e");
      return null;
    }
  }
}
