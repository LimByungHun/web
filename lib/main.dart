import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:web/model/course_model.dart';
import 'package:web/screen/home_screen.dart';
import 'package:web/screen/login_screen.dart';
import 'package:web/service/auto_login_api.dart';
import 'package:web/service/token_storage.dart';

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

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '수어 학습 앱',
      debugShowCheckedModeBanner: false,
      locale: Locale('ko', 'KR'),
      supportedLocales: [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: isLoggedIn ? HomeScreen() : LoginScreen(),
    );
  }
}
