import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sign_web/service/token_storage.dart';

const String baseUrl = 'http://10.101.170.52';

class StudyApi {
  // 학습 코스 목록 불러오기
  static Future<List<Map<String, dynamic>>> StudyCourses() async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    if (accessToken == null) throw Exception("accessToken 없음");
    if (refreshToken == null) throw Exception("refreshToken 없음");

    final response = await http.get(
      Uri.parse('$baseUrl/study/list'),
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
      final List<dynamic> data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('코스 불러오기 실패: ${response.statusCode}');
    }
  }

  // 선택한 학습 코스 데이터 가져오기
  static Future<Map<String, dynamic>> fetchCourseDetail(
    String courseName,
  ) async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    if (accessToken == null) throw Exception("accessToken 없음");
    if (refreshToken == null) throw Exception("refreshToken 없음");

    final url = Uri.parse(
      '$baseUrl/study/course?course_name=${Uri.encodeComponent(courseName)}',
    );

    final response = await http.get(
      url,
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
      final json = jsonDecode(response.body);
      return {
        "sid": json["sid"],
        "title": json["title"],
        "words": List<Map<String, dynamic>>.from(json["words"]),
        "steps": List<Map<String, dynamic>>.from(json["steps"]),
      };
    } else {
      final msg = response.body.isNotEmpty ? response.body : 'No details';
      throw Exception('학습 코스 세부정보 요청 실패 (${response.statusCode}): $msg');
    }
  }

  // 학습 통계 가져오기
  static Future<
    ({
      List<DateTime> learnedDates,
      int streakDays,
      int learnedWordsCount,
      Map<int, List<int>> completedSteps,
    })
  >
  getStudyStats() async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    if (accessToken == null) throw Exception("accessToken 없음");
    if (refreshToken == null) throw Exception("refreshToken 없음");

    final url = Uri.parse('$baseUrl/study/stats');

    final response = await http.get(
      url,
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
      final dates = (data['learned_dates'] as List)
          .map((e) => DateTime.parse(e))
          .toList();
      final streak = data['streak_days'] as int;
      final count = data['learned_words_count'] as int;

      final Map<int, List<int>> completed = {};
      final completedRaw = data['completed_steps'] as Map<String, dynamic>;
      for (final entry in completedRaw.entries) {
        final sid = int.tryParse(entry.key);
        final steps = (entry.value as List).cast<int>();
        if (sid != null) {
          completed[sid] = steps;
        }
      }

      return (
        learnedDates: dates,
        streakDays: streak,
        learnedWordsCount: count,
        completedSteps: completed,
      );
    } else {
      throw Exception('학습 통계 조회 실패: ${response.statusCode}');
    }
  }

  // 전체 코스 기준 현재 학습 완료 퍼센트 가져오기
  static Future<double> getCompletionRate() async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    if (accessToken == null) throw Exception("accessToken 없음");
    if (refreshToken == null) throw Exception("refreshToken 없음");

    final url = Uri.parse('$baseUrl/study/completion_rate');

    final response = await http.get(
      url,
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
      final percent = data['completion_percent'];
      return percent.toDouble();
    } else {
      throw Exception('학습 완료율 조회 실패: ${response.statusCode}');
    }
  }

  // 학습 완료 저장
  static Future<void> completeStudy({
    required int sid,
    required int step,
  }) async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    if (accessToken == null) throw Exception("accessToken 없음");
    if (refreshToken == null) throw Exception("refreshToken 없음");

    final response = await http.post(
      Uri.parse('$baseUrl/study/complete'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Refresh-Token': refreshToken,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'sid': sid, 'step': step}),
    );

    final newAccessToken = response.headers['x-new-access-token'];
    if (newAccessToken != null && newAccessToken.isNotEmpty) {
      await TokenStorage.setAccessToken(newAccessToken);
    }

    if (response.statusCode != 200) {
      throw Exception('학습 완료 실패: ${response.statusCode} ${response.body}');
    }
  }

  static Future<Map<String, List<Map<String, dynamic>>>>
  getCompletedStep5Words() async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    if (accessToken == null) throw Exception("accessToken 없음");
    if (refreshToken == null) throw Exception("refreshToken 없음");

    final url = Uri.parse('$baseUrl/study/review_words');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Refresh-Token': refreshToken,
      },
    );

    final newAccessToken = response.headers['x-new-access-token'];
    if (newAccessToken != null && newAccessToken.isNotEmpty) {
      await TokenStorage.setAccessToken(newAccessToken);
    }

    final result = <String, List<Map<String, dynamic>>>{};

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      for (final item in data) {
        final course = item['course'] ?? '기타';
        result.putIfAbsent(course, () => []).add(item as Map<String, dynamic>);
      }
    } else {
      throw Exception('복습 단어 불러오기 실패: ${response.statusCode} ${response.body}');
    }

    return result;
  }
}
