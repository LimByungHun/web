import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web/service/token_storage.dart';

const String baseUrl = 'http://10.101.170.63';

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
}
