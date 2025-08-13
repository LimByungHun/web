import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sign_web/model/calendar_model.dart';
import 'package:sign_web/service/token_storage.dart';

const String baseUrl = 'http://10.101.170.52';

class CalendarApi {
  static Future<
    ({Set<DateTime> learnedDates, int streakDays, int bestStreakDays})
  >
  fetchLearnedDates() async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    final response = await http.get(
      Uri.parse('$baseUrl/study/calendar'),
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
      final jsonData = json.decode(response.body);
      final List<dynamic> dateList = jsonData['records'];
      final int streakDays = jsonData['streak_days'];
      final int bestStreakDays = jsonData['best_streak'];

      final dates = dateList.map<DateTime>((dateStr) {
        final parts = dateStr.split('-');
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }).toSet();

      return (
        learnedDates: dates,
        streakDays: streakDays,
        bestStreakDays: bestStreakDays,
      );
    } else {
      throw Exception('학습 날짜 불러오기 실패: ${response.statusCode}');
    }
  }

  static Future<({String date, List<DayRecordItem> items})> fetchDayRecords(
    DateTime selectedDate,
  ) async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    final String dateStr = _formatYmd(selectedDate);
    final uri = Uri.parse('$baseUrl/study/records/day?date_str=$dateStr');

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Refresh-Token': refreshToken ?? '',
      },
    );

    // 액세스 토큰 갱신 처리
    final newToken = response.headers['x-new-access-token'];
    if (newToken != null && newToken.isNotEmpty) {
      await TokenStorage.setAccessToken(newToken);
    }

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final String date = jsonData['date'] as String? ?? dateStr;
      final List<dynamic> rawItems =
          jsonData['items'] as List<dynamic>? ?? const [];

      final items = rawItems
          .map((e) => DayRecordItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);

      return (date: date, items: items);
    } else {
      throw Exception('날짜별 학습 기록 불러오기 실패: ${response.statusCode}');
    }
  }

  static String _formatYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
