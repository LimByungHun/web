import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/router/router.dart';
import 'package:sign_web/service/auto_login_api.dart';
import 'package:sign_web/service/token_storage.dart';
import 'package:sign_web/theme/tabler_theme.dart';

final ValueNotifier<bool> loginState = ValueNotifier(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final refreshToken = await TokenStorage.getRefreshToken();

  if (refreshToken != null && refreshToken.isNotEmpty) {
    final result = await AutoLoginApi.autoLogin(refreshToken);
    if (result == true) {
      loginState.value = true;
    } else {
      debugPrint("자동 로그인 실패");
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
      title: '수어 술술',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: TablerTheme.lightTheme,
      routerConfig: router,
    );
  }
}
