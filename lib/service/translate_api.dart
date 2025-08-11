import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sign_web/service/token_storage.dart';

const String baseUrl = 'http://10.101.170.52';

class TranslateApi {
  // 수어 -> 단어
  static Future<Map<String, dynamic>> signToText(
    html.MediaStream mediaStream,
    String expectedWord,
  ) async {
    try {
      final accessToken = await TokenStorage.getAccessToken();
      final refreshToken = await TokenStorage.getRefreshToken();

      final frames = await captureFramesFromStream(mediaStream);

      if (frames.isEmpty) {
        return {"error": true, "message": "프레임 캡처 실패"};
      }

      final uri = Uri.parse('$baseUrl/translate/sign_to_text_frames');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Refresh-Token': refreshToken ?? '',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'frames': frames, 'expected_word': expectedWord}),
      );

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
      print('signToTextWeb 오류: $e');
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

    print("프레임 ${base64Frames.length}개 서버로 전송 시작...");

    // 대용량 본문으로 인한 실패를 줄이기 위해 프레임을 청크로 쪼개서 전송
    const int chunkSize = 12; // 한 요청당 최대 프레임 수
    String? finalStatus;

    for (int start = 0; start < base64Frames.length; start += chunkSize) {
      final slice = base64Frames.sublist(
        start,
        (start + chunkSize > base64Frames.length)
            ? base64Frames.length
            : start + chunkSize,
      );

      final status = await _postAnalyzeFrames(
        url,
        accessToken,
        refreshToken,
        slice,
      );

      if (status != null) {
        finalStatus = status; // 마지막 성공 상태를 유지
      } else {
        print("청크 전송 실패: index $start/${base64Frames.length}");
      }
    }

    return finalStatus;
  }

  static Future<String?> _postAnalyzeFrames(
    Uri url,
    String accessToken,
    String? refreshToken,
    List<String> frames,
  ) async {
    // 간단한 재시도(백오프)
    const List<Duration> delays = [
      Duration(milliseconds: 0),
      Duration(milliseconds: 600),
      Duration(milliseconds: 1200),
    ];

    for (int attempt = 0; attempt < delays.length; attempt++) {
      if (delays[attempt].inMilliseconds > 0) {
        await Future.delayed(delays[attempt]);
      }

      try {
        final response = await http
            .post(
              url,
              headers: {
                'Authorization': 'Bearer $accessToken',
                'X-Refresh-Token': refreshToken ?? '',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'frames': frames}),
            )
            .timeout(const Duration(seconds: 12));

        final newToken = response.headers['x-new-access-token'];
        if (newToken != null && newToken.isNotEmpty) {
          await TokenStorage.setAccessToken(newToken);
        }

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          return result['status'];
        } else {
          print("서버 프레임 분석 실패(${response.statusCode}): ${response.body}");
        }
      } on http.ClientException catch (e) {
        print("네트워크 예외(ClientException): $e");
        // CORS/mixed-content나 네트워크 단절 가능성. 재시도.
      } on Exception catch (e) {
        if (e is TimeoutException) {
          print("요청 타임아웃 – 재시도합니다 (attempt ${attempt + 1})");
        } else {
          print("예외 발생: $e");
        }
      }
    }

    return null;
  }

  static Future<List<String>> captureFramesFromStream(
    html.MediaStream stream,
  ) async {
    final List<String> base64Frames = [];

    try {
      final video = html.VideoElement()
        ..srcObject = stream
        ..autoplay = true
        ..muted = true;

      final canvas = html.CanvasElement();
      final ctx = canvas.context2D;

      await video.onLoadedData.first;

      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;

      for (int i = 0; i < 15; i++) {
        ctx.drawImageScaled(video, 0, 0, canvas.width!, canvas.height!);

        final dataUrl = canvas.toDataUrl('image/jpeg', 0.8);
        final base64Data = dataUrl.split(',')[1];
        base64Frames.add(base64Data);

        await Future.delayed(Duration(milliseconds: 200));
      }

      stream.getTracks().forEach((track) => track.stop());
    } catch (e) {
      print('프레임 캡처 오류: $e');
    }

    return base64Frames;
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
          'english': result['english']['text'] ?? '',
          'japanese': result['japanese']['text'] ?? '',
          'chinese': result['chinese']['text'] ?? '',
        };
      } else {
        print("번역 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("요청 오류: $e");
    }

    return null;
  }

  static Future<Map<String, dynamic>?> translateLatest2() async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    final url = Uri.parse("$baseUrl/study/translate_latest");

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
        return {'korean': result['korean']};
      } else {
        print("번역 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("요청 오류: $e");
    }

    return null;
  }

  // 메타 데이터로 접근(테스트해봐야함.)
  static Future<String?> sendFramesRealtimeMode(
    List<String> base64Frames,
  ) async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    if (accessToken == null) {
      print("Error: Access Token is missing. Cannot proceed with the request.");
      return null;
    }

    // 기존 URL에 실시간 모드 파라미터 추가
    final url = Uri.parse(
      "$baseUrl/translate/analyze_frames?mode=realtime&fps=5",
    );

    print("실시간 모드로 프레임 ${base64Frames.length}개 서버 전송 시작...");

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Refresh-Token': refreshToken ?? '',
          'Content-Type': 'application/json',
          // 실시간 모드 관련 헤더 추가
          'X-Capture-FPS': '5',
          'X-Realtime-Mode': 'true',
          'X-Client-Type': 'flutter_web',
        },
        body: jsonEncode({
          'frames': base64Frames,
          // 기존 데이터에 메타데이터 추가
          'capture_interval_ms': 200,
          'realtime': true,
          'expected_playback_fps': 5,
        }),
      );

      final newToken = response.headers['x-new-access-token'];
      if (newToken != null && newToken.isNotEmpty) {
        print("새 액세스 토큰 수신 및 저장 완료.");
        await TokenStorage.setAccessToken(newToken);
      }

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print("실시간 모드 서버 분석 성공: ${result['status']}");
        return result['status'];
      } else {
        print("실시간 모드 서버 분석 실패: Status ${response.statusCode}");
        print("서버 응답 본문: ${response.body}");
      }
    } catch (e) {
      print("실시간 모드 프레임 전송 중 예외 발생: $e");
    }

    return null;
  }
}
