import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_web/service/reset_password_api.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

class PwrecoveryScreen extends StatefulWidget {
  const PwrecoveryScreen({super.key});

  @override
  State<PwrecoveryScreen> createState() => PwrecoveryScreenState();
}

class PwrecoveryScreenState extends State<PwrecoveryScreen> {
  final TextEditingController idcontrollor = TextEditingController();
  final TextEditingController pwcontrollor = TextEditingController();
  final TextEditingController passwordcontrollor = TextEditingController();

  bool isSearching = false;
  bool found = false;
  bool isChanging = false;

  @override
  void dispose() {
    idcontrollor.dispose();
    pwcontrollor.dispose();
    passwordcontrollor.dispose();
    super.dispose();
  }

  Future<void> handleSearch() async {
    final id = idcontrollor.text.trim();
    if (id.isEmpty) {
      Fluttertoast.showToast(
        msg: '아이디를 입력해주세요',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
      return;
    }
    setState(() => isSearching = true);
    try {
      final exists = await PasswordResetApi.checkUserIDExists(id);
      setState(() {
        found = exists;
        isSearching = false;
      });
      if (!exists) {
        Fluttertoast.showToast(
          msg: "존재하지 않는 아이디입니다.",
          backgroundColor: TablerColors.danger,
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: "계정을 찾았습니다. 새 비밀번호를 설정해주세요",
          backgroundColor: TablerColors.success,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      setState(() => isSearching = false);
      Fluttertoast.showToast(
        msg: "오류가 발생했습니다. 다시 시도해주세요.",
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
    }
  }

  Future<void> handlePasswordChange() async {
    final id = idcontrollor.text.trim();
    final newPw = pwcontrollor.text.trim();
    final confirmPw = passwordcontrollor.text.trim();

    if (newPw.isEmpty || confirmPw.isEmpty) {
      Fluttertoast.showToast(
        msg: "비밀번호를 모두 입력해주세요.",
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
      return;
    }

    if (newPw != confirmPw) {
      Fluttertoast.showToast(
        msg: "비밀번호가 일치하지 않습니다.",
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => isChanging = true);

    try {
      final success = await PasswordResetApi.resetPassword(
        userID: id,
        newPassword: newPw,
      );

      setState(() => isChanging = false);

      if (success && mounted) {
        Fluttertoast.showToast(
          msg: "비밀번호가 재설정되었습니다.",
          backgroundColor: TablerColors.success,
          textColor: Colors.white,
        );
        GoRouter.of(context).go('/');
      } else {
        Fluttertoast.showToast(
          msg: "비밀번호 재설정 실패",
          backgroundColor: TablerColors.danger,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      setState(() => isChanging = false);
      Fluttertoast.showToast(
        msg: "오류가 발생했습니다. 다시 시도해주세요.",
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
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 450),
              child: TablerCard(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildHeader(),
                    SizedBox(height: 32),

                    buildTextField(
                      controller: idcontrollor,
                      label: '아이디',
                      hintText: '계정의 아이디를 입력하세요',
                      prefixIcon: Icons.person_outline,
                      enabled: !found,
                    ),
                    SizedBox(height: 16),

                    if (!found) ...[
                      SizedBox(
                        height: 48,
                        child: TablerButton(
                          text: isSearching ? '검색 중...' : '계정 찾기',
                          icon: isSearching ? null : Icons.search,
                          onPressed: isSearching ? null : handleSearch,
                        ),
                      ),
                    ],

                    if (found) ...[
                      // 성공 메시지
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: TablerColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: TablerColors.success.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: TablerColors.success,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '계정을 찾았습니다! 새 비밀번호를 설정해주세요.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: TablerColors.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      buildTextField(
                        controller: pwcontrollor,
                        label: '새 비밀번호',
                        hintText: '새 비밀번호를 입력하세요',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                      ),
                      SizedBox(height: 16),
                      buildTextField(
                        controller: passwordcontrollor,
                        label: '비밀번호 확인',
                        hintText: '새 비밀번호를 다시 입력하세요',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                      ),

                      SizedBox(height: 24),

                      SizedBox(
                        height: 48,
                        child: TablerButton(
                          text: isChanging ? '변경 중...' : '비밀번호 변경',
                          icon: isChanging ? null : Icons.key,
                          onPressed: isChanging ? null : handlePasswordChange,
                        ),
                      ),
                    ],

                    SizedBox(height: 24),

                    // 로그인 페이지로 이동
                    Center(
                      child: Column(
                        children: [
                          Text(
                            '계정이 기억나셨나요?',
                            style: TextStyle(
                              fontSize: 14,
                              color: TablerColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => GoRouter.of(context).go('/'),
                            child: Text(
                              '로그인하기',
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

  Widget buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: TablerColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.lock_reset, color: TablerColors.warning, size: 32),
        ),
        SizedBox(height: 16),
        Text(
          '비밀번호 찾기',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: TablerColors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          found ? '새로운 비밀번호를 설정하세요' : '계정의 아이디를 입력하여 비밀번호를 재설정하세요',
          style: TextStyle(fontSize: 14, color: TablerColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: enabled
                ? TablerColors.textPrimary
                : TablerColors.textSecondary,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(
              prefixIcon,
              color: enabled
                  ? TablerColors.textSecondary
                  : TablerColors.textSecondary.withOpacity(0.5),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: TablerColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: TablerColors.border),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: TablerColors.border.withOpacity(0.5),
              ),
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
            fillColor: enabled ? Colors.white : TablerColors.background,
          ),
        ),
      ],
    );
  }
}
