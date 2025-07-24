import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sign_web/service/token_storage.dart';

const String baseUrl = 'http://10.101.170.168';

class TranslateApi {
  // 수어 -> 단어
  static Future<Map<String, dynamic>> signToText(
    String videoPath,
    String expectedWord,
  ) async {
    try {
      final accessToken = await TokenStorage.getAccessToken();
      final refreshToken = await TokenStorage.getRefreshToken();

      final uri = Uri.parse('$baseUrl/translate/sign_to_text');

      final request = http.MultipartRequest('POST', uri)
        ..fields['expected_word'] = expectedWord
        ..files.add(await http.MultipartFile.fromPath('file', videoPath))
        ..headers.addAll({
          'Authorization': 'Bearer $accessToken',
          'X-Refresh-Token': refreshToken ?? '',
        });

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      final newAccessToken = response.headers['x-new-access-token'];
      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        await TokenStorage.setAccessToken(newAccessToken);
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('서버 오류: ${response.body}');
      }
    } catch (e) {
      print('signToText 오류: $e');
      return {"error": true, "message": e.toString()};
    }
  }

  // 단어 -> 수어
  static Future<List<String>?> translate_word_to_video(String wordText) async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    final url = Uri.parse(
      "$baseUrl/translate/text_to_sign?word_text=$wordText",
    );

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

  static Future<String?> sendFrames(List<String> base64Frames) async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    if (accessToken == null) {
      print("Error: Access Token is missing. Cannot proceed with the request.");
      return null;
    }

    final url = Uri.parse("$baseUrl/translate/analyze_frames");

    print("--- 프레임 ${base64Frames.length}개 서버로 전송 시작...");

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Refresh-Token': refreshToken ?? '',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'frames': base64Frames}),
      );

      final newToken = response.headers['x-new-access-token'];
      if (newToken != null && newToken.isNotEmpty) {
        print("--- 새 액세스 토큰 수신 및 저장 완료.");
        await TokenStorage.setAccessToken(newToken);
      }

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print("--- 서버 프레임 분석 성공: ${result['status']}");
        return result['status'];
      } else {
        print("--- 서버 프레임 분석 실패: Status ${response.statusCode}");
        print("--- 서버 응답 본문: ${response.body}");
      }
    } catch (e) {
      print("--- 프레임 전송 중 예외 발생: $e");
    }

    return null;
  }

  static Future<Map<String, dynamic>?> translateLatest() async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    final url = Uri.parse("$baseUrl/translate/translate_latest");

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
        final result = jsonDecode(response.body);
        return {
          'korean': result['korean'],
          'english': result['english'],
          'japanese': result['japanese'],
          'chinese': result['chinese'],
        };
      } else {
        print("번역 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("요청 오류: $e");
    }

    return null;
  }
}
