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
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController idController = TextEditingController();
  final TextEditingController pwController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    idController.dispose();
    pwController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    setState(() => isLoading = true);

    final id = idController.text.trim();
    final pw = pwController.text.trim();

    if (id.isEmpty || pw.isEmpty) {
      setState(() => isLoading = false);
      Fluttertoast.showToast(
        msg: '아이디와 비밀번호를 입력해주세요',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
      return;
    }

    final result = await LoginApi.login(id, pw);

    setState(() => isLoading = false);

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

      final prefs = await SharedPreferences.getInstance();
      final lastCourse = prefs.getString('selectedCourse');

      if (lastCourse != null) {
        try {
          final courseInfo = await StudyApi.fetchCourseDetail(lastCourse);
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

      GoRouter.of(context).go('/home');
    } else {
      Fluttertoast.showToast(
        msg: result.error ?? '가입하지 않은 회원이거나 비밀번호가 일치하지 않습니다.',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablerColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: TablerCard(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 로고 영역
                    Container(
                      alignment: Alignment.center,
                      margin: EdgeInsets.only(bottom: 32),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: TablerColors.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.sign_language,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '수어 학습 앱',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: TablerColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '로그인하여 학습을 시작하세요',
                            style: TextStyle(
                              fontSize: 14,
                              color: TablerColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 입력 필드들
                    buildTextField(
                      controller: idController,
                      label: '아이디',
                      hintText: '아이디를 입력하세요',
                      prefixIcon: Icons.person_outline,
                    ),
                    SizedBox(height: 16),
                    buildTextField(
                      controller: pwController,
                      label: '비밀번호',
                      hintText: '비밀번호를 입력하세요',
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                    ),

                    SizedBox(height: 24),

                    // 로그인 버튼
                    SizedBox(
                      height: 48,
                      child: TablerButton(
                        text: isLoading ? '로그인 중...' : '로그인',
                        icon: isLoading ? null : Icons.login,
                        onPressed: isLoading ? null : handleLogin,
                      ),
                    ),

                    SizedBox(height: 16),

                    // 회원가입 버튼
                    SizedBox(
                      height: 48,
                      child: TablerButton(
                        text: '회원가입',
                        icon: Icons.person_add_outlined,
                        outline: true,
                        onPressed: () => context.push('/insert'),
                      ),
                    ),

                    SizedBox(height: 24),

                    // 비밀번호 찾기
                    Center(
                      child: Column(
                        children: [
                          Text(
                            '비밀번호를 잊어버리셨나요?',
                            style: TextStyle(
                              fontSize: 14,
                              color: TablerColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => context.push('/pwrecovery'),
                            child: Text(
                              '비밀번호 찾기',
                              style: TextStyle(
                                fontSize: 14,
                                color: TablerColors.primary,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: TablerColors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(prefixIcon, color: TablerColors.textSecondary),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: TablerColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: TablerColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: TablerColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: TablerColors.danger),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
