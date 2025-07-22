import 'package:go_router/go_router.dart';
import 'package:sign_web/main.dart';
import 'package:sign_web/screen/bookmark_screen.dart';
import 'package:sign_web/screen/dictionary_screen.dart';
import 'package:sign_web/screen/home_screen.dart';
import 'package:sign_web/screen/insertuser_screen.dart';
import 'package:sign_web/screen/login_screen.dart';
import 'package:sign_web/screen/pwrecovery_screen.dart';
import 'package:sign_web/screen/studycource_screen.dart';
import 'package:sign_web/screen/translate_screen.dart';
import 'package:sign_web/screen/study_screen.dart';
import 'package:sign_web/screen/studycalender_screen.dart';
import 'package:sign_web/screen/user_screen.dart';
import 'package:sign_web/widget/alllist_widget.dart';

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
        path: '/course',
        builder: (context, state) => const StudycourceScreen(),
      ),
      GoRoute(
        path: '/translate',
        builder: (context, state) => const TranslateScreen(),
      ),
      GoRoute(path: '/bookmark', builder: (context, state) => const Bookmark()),

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
