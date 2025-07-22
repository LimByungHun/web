import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourseModel with ChangeNotifier {
  String? _selectedCourse;
  int _sid = 0;
  List<Map<String, dynamic>> _words = [];
  List<Map<String, dynamic>> _steps = [];
  int _currentDay = 1;
  int _totalDays = 1;
  Map<int, List<int>> _completedSteps = {};

  String? get selectedCourse => _selectedCourse;
  int get sid => _sid;
  List<Map<String, dynamic>> get words => _words;
  List<Map<String, dynamic>> get steps => _steps;
  int get currentDay => _currentDay;
  int get totalDays => _totalDays;
  Map<int, List<int>> get completedSteps => _completedSteps;

  bool get isStepCompleted => _currentDay > _totalDays;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedCourse = prefs.getString('selectedCourse');
    _sid = prefs.getInt('sid') ?? 0;
    _words = List<Map<String, dynamic>>.from(
      jsonDecode(prefs.getString('words') ?? '[]'),
    );
    _steps = List<Map<String, dynamic>>.from(
      jsonDecode(prefs.getString('steps') ?? '[]'),
    );
    _currentDay = prefs.getInt('currentDay') ?? 1;
    _totalDays = prefs.getInt('totalDays') ?? 1;

    // 완료된 스텝 정보도 불러오기 (없으면 빈 맵)
    final completed = prefs.getString('completedSteps');
    _completedSteps = completed != null
        ? Map<int, List<int>>.from(
            jsonDecode(completed).map(
              (key, value) => MapEntry(int.parse(key), List<int>.from(value)),
            ),
          )
        : {};

    assignSidToWords();
    notifyListeners();
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedCourse != null) {
      await prefs.setString('selectedCourse', _selectedCourse!);
      await prefs.setInt('sid', _sid);
      await prefs.setString('words', jsonEncode(_words));
      await prefs.setString('steps', jsonEncode(_steps));
      await prefs.setInt('currentDay', _currentDay);
      await prefs.setInt('totalDays', _totalDays);
      await prefs.setString(
        'completedSteps',
        jsonEncode(
          _completedSteps.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    }
  }

  void selectCourse({
    required String course,
    required int sid,
    required List<Map<String, dynamic>> words,
    required List<Map<String, dynamic>> steps,
  }) {
    _selectedCourse = course;
    _sid = sid;
    _words = words.map((word) {
      return {...word, 'sid': sid, 'course': course};
    }).toList();

    _steps = steps.map((step) {
      return {...step, 'sid': sid, 'course': course};
    }).toList();

    _totalDays = steps.length;
    _currentDay = getNextUncompletedStep() ?? 1;
    saveToPrefs();
    notifyListeners();
  }

  void setCompletedSteps(Map<int, List<int>> data) {
    _completedSteps = data;
    _currentDay = getNextUncompletedStep() ?? 1;
    saveToPrefs();
    notifyListeners();
  }

  int? getNextUncompletedStep() {
    final completed = _completedSteps[_sid] ?? [];
    for (final step in _steps) {
      final s = step['step'];
      if (s is int && !completed.contains(s)) {
        return s;
      }
    }
    return null; // 모두 완료됨
  }

  void completeOneDay() {
    if (_currentDay <= _totalDays) {
      _completedSteps[_sid] = [...?_completedSteps[_sid], _currentDay];
      _currentDay = getNextUncompletedStep() ?? _totalDays + 1;
      saveToPrefs();
      notifyListeners();
    }
  }

  void resetProgress() {
    _currentDay = 1;
    _completedSteps[_sid] = [];
    saveToPrefs();
    notifyListeners();
  }

  void updateCompletedSteps(Map<int, List<int>> data) {
    _completedSteps = data;

    // 현재 선택된 코스가 있으면 해당 SID 기준으로 currentDay 계산
    if (_sid != 0 && _completedSteps.containsKey(_sid)) {
      _currentDay = getNextUncompletedStep() ?? _totalDays + 1;
    } else {
      _currentDay = 1;
    }

    saveToPrefs();
    notifyListeners();
  }

  void assignSidToWords() {
    for (final step in _steps) {
      final sid = step['sid'] ?? _sid;
      final stepNumber = int.tryParse(step['step'].toString());

      for (final word in _words) {
        final wordStep = int.tryParse(word['step'].toString());

        if (wordStep != null && stepNumber != null && wordStep == stepNumber) {
          word['sid'] ??= sid;
          word['course'] ??= _selectedCourse;
          print("SID 할당: ${word['word']} → $sid, course: ${word['course']}");
        }
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> getCompletedCourseStep5Words() {
    final result = <String, List<Map<String, dynamic>>>{};

    final groupedByCourse = <String, List<Map<String, dynamic>>>{};
    for (final word in _words) {
      if (word['step'] == 5 && word['sid'] != null) {
        final course = word['course'] ?? '기타';
        groupedByCourse.putIfAbsent(course, () => []).add(word);
      }
    }

    groupedByCourse.forEach((courseName, words) {
      result[courseName] = words;
    });

    return result;
  }

  void debugWords() {
    print('단어 목록: ');
    for (final w in _words) {
      print(
        '→ sid: ${w['sid']}, step: ${w['step']}, word: ${w['word']}, course: ${w['course']}}',
      );
    }

    print('스텝 목록: ');
    for (final s in _steps) {
      print('→ step: ${s['step']}, sid: ${s['sid']}, name: ${s['step_name']}');
    }

    print('sid: $_sid');
  }

  Future<void> clearSelectedCourse() async {
    _selectedCourse = null;
    _sid = 0;
    _words = [];
    _steps = [];
    _currentDay = 1;
    _totalDays = 1;
    _completedSteps = {};

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selectedCourse');
    await prefs.remove('sid');
    await prefs.remove('words');
    await prefs.remove('steps');
    await prefs.remove('currentDay');
    await prefs.remove('totalDays');
    await prefs.remove('completedSteps');

    notifyListeners();
  }
}
