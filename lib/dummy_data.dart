// 테스트용 더미데이터
final Set<DateTime> learnedDates = {
  DateTime.now().subtract(const Duration(days: 3)),
  DateTime.now().subtract(const Duration(days: 2)),
  DateTime.now(), //.subtract(const Duration(days: 1)), // 어제
};

final Set<DateTime> rawDates = learnedDates
    .map((d) => DateTime(d.year, d.month, d.day))
    .toSet();
