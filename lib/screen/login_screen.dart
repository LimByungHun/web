import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_web/main.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/service/login_api.dart';
import 'package:sign_web/service/study_api.dart';
import 'package:sign_web/service/token_storage.dart';
import 'package:sign_web/widget/button_widget.dart';
import 'package:sign_web/widget/textbox_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController idController = TextEditingController();
  final TextEditingController pwController = TextEditingController();

  @override
  void dispose() {
    idController.dispose();
    pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      '제목',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // 아이디, 비밀번호 입력
                  Textbox(controller: idController, hintText: '아이디'),
                  Textbox(
                    controller: pwController,
                    hintText: '비밀번호',
                    obscureText: true,
                  ),

                  const SizedBox(height: 16),

                  // 로그인 & 회원가입 버튼
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 120,
                          child: ButtonWidget(
                            text: '로그인',
                            onTap: () async {
                              final id = idController.text.trim();
                              final pw = pwController.text.trim();
                              final result = await LoginApi.login(id, pw);

                              if (!mounted) return;

                              if (result.success &&
                                  result.accessToken != null &&
                                  result.refreshToken != null &&
                                  result.expiresAt != null) {
                                await TokenStorage.clearTokens();
                                await TokenStorage.saveTokens(
                                  result.accessToken!,
                                  result.refreshToken!,
                                  result.expiresAt!,
                                  userID: result.userID!,
                                  nickname: result.nickname!,
                                );
                                loginState.value = true;

                                if (!mounted) return;

                                final prefs =
                                    await SharedPreferences.getInstance();
                                final lastCourse = prefs.getString(
                                  'selectedCourse',
                                );

                                if (lastCourse != null) {
                                  try {
                                    final courseInfo =
                                        await StudyApi.fetchCourseDetail(
                                          lastCourse,
                                        );

                                    context.read<CourseModel>().selectCourse(
                                      course: lastCourse,
                                      sid: courseInfo['sid'],
                                      words: courseInfo['words'],
                                      steps: courseInfo['steps'],
                                    );
                                  } catch (e) {
                                    print('[ERROR] 자동 복원 실패: $e');
                                  }
                                }
                                // context.read<CourseModel>().loadFromPrefs();
                                GoRouter.of(context).go('/home');
                              } else {
                                Fluttertoast.showToast(
                                  msg:
                                      result.error ??
                                      '가입하지 않은 회원이거나 비밀번호가 일치하지 않습니다.',
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                );
                              }
                            },
                            selected: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: ButtonWidget(
                            text: '회원가입',
                            onTap: () {
                              context.push('/insert');
                            },
                            selected: false,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text('비밀번호를 잊어버리셨나요?'),
                  GestureDetector(
                    onTap: () {
                      context.push('/pwrecovery');
                    },
                    child: const Text(
                      '비밀번호 찾기',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
