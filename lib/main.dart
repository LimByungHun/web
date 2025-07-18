import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/screen/home_screen.dart';
import 'package:sign_web/screen/login_screen.dart';
import 'package:sign_web/service/auto_login_api.dart';
import 'package:sign_web/service/token_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final refreshToken = await TokenStorage.getRefreshToken();
  bool isLoggedIn = false;

  if (refreshToken != null && refreshToken.isNotEmpty) {
    final result = await AutoLoginApi.autoLogin(refreshToken);
    isLoggedIn = result == true;
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => CourseModel()..loadFromPrefs(),
      child: MyApp(isLoggedIn: isLoggedIn),
    ),
  );
}

// 라우터 정의 (로그인 여부에 따라 초기경로 변경)
GoRouter createRouter(bool isLoggedIn) {
  return GoRouter(
    initialLocation: isLoggedIn ? '/home' : '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    ],
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final router = createRouter(isLoggedIn);

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
