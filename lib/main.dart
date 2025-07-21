import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/screen/dictionary_screen.dart';
import 'package:sign_web/screen/home_screen.dart';
import 'package:sign_web/screen/insertuser_screen.dart';
import 'package:sign_web/screen/login_screen.dart';
import 'package:sign_web/screen/pwrecovery_screen.dart';
import 'package:sign_web/service/auto_login_api.dart';
import 'package:sign_web/service/token_storage.dart';
import 'package:sign_web/screen/study_screen.dart';
import 'package:sign_web/screen/studycalender_screen.dart';
import 'package:sign_web/screen/user_screen.dart';
import 'package:sign_web/widget/new_widget/alllist_widget.dart';

final ValueNotifier<bool> loginState = ValueNotifier(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final refreshToken = await TokenStorage.getRefreshToken();
  print('[DEBUG] refreshToken 존재, 자동 로그인 시도');
  if (refreshToken != null && refreshToken.isNotEmpty) {
    final result = await AutoLoginApi.autoLogin(refreshToken);
    if (result == true) {
      print('[DEBUG] 자동 로그인 성공 → 상태 갱신');
      loginState.value = true;
    } else {
      print('[DEBUG] 자동 로그인 실패 또는 응답 없음');
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => CourseModel()..loadFromPrefs(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = createRouter();

    return MaterialApp.router(
      title: '수어 학습 앱',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: loginState,
    redirect: (_, state) {
      final isLoggedIn = loginState.value;
      final isLoggingIn = state.fullPath == '/';
      if (!isLoggedIn && !isLoggingIn) return '/';
      if (isLoggedIn && isLoggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/insert',
        builder: (context, state) => const InsertuserScreen(),
      ),
      GoRoute(
        path: '/pwrecovery',
        builder: (context, state) => const PwrecoveryScreen(),
      ),
      GoRoute(
        path: '/dictionary',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return Dictionary(
            words: extra?['words'] ?? [],
            wordIdMap: extra?['wordIdMap'] ?? {},
            userID: extra?['userID'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const StudycalenderScreen(),
      ),
      GoRoute(
        path: '/study',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final course = extra['course'] as String? ?? '';
          final day = extra['day'] as int? ?? 1;

          return StudyScreen(course: course, day: day);
        },
      ),
      GoRoute(path: '/user', builder: (context, state) => const UserScreen()),
      GoRoute(
        path: '/review_all',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final courseWordsMap =
              extra?['courseWordsMap']
                  as Map<String, List<Map<String, dynamic>>>? ??
              {};
          return AlllistWidget(
            title: '복습 문제 전체 보기',
            courseWordsMap: courseWordsMap,
          );
        },
      ),
    ],
  );
}
