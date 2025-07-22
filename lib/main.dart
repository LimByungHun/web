import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/router/router.dart';
import 'package:sign_web/service/auto_login_api.dart';
import 'package:sign_web/service/token_storage.dart';

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
