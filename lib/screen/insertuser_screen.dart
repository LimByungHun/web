import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_web/service/signup_api.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

class InsertuserScreen extends StatefulWidget {
  const InsertuserScreen({super.key});

  @override
  State<InsertuserScreen> createState() => InsertuserScreenState();
}

class InsertuserScreenState extends State<InsertuserScreen> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController idController = TextEditingController();
  final TextEditingController pwController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isIDAvailable = false;
  bool isCheckingID = false;
  bool isRegistering = false;

  @override
  void dispose() {
    userController.dispose();
    idController.dispose();
    pwController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> checkDuplicateID() async {
    final id = userController.text.trim();
    if (id.isEmpty) {
      Fluttertoast.showToast(
        msg: '아이디를 입력해주세요',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => isCheckingID = true);

    final result = await checkID(id);
    final available = result['available'] == true;

    setState(() {
      isIDAvailable = available;
      isCheckingID = false;
    });

    Fluttertoast.showToast(
      msg: available ? '사용 가능한 아이디입니다.' : '이미 사용 중인 아이디입니다.',
      backgroundColor: available ? TablerColors.success : TablerColors.danger,
      textColor: Colors.white,
    );
  }

  Future<void> handleRegister() async {
    final id = userController.text.trim();
    final name = idController.text.trim();
    final pw = pwController.text.trim();
    final confirmPw = passwordController.text.trim();

    if (id.isEmpty || name.isEmpty || pw.isEmpty || confirmPw.isEmpty) {
      Fluttertoast.showToast(
        msg: '모든 필드를 입력해주세요.',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
      return;
    }

    if (pw != confirmPw) {
      Fluttertoast.showToast(
        msg: '비밀번호가 일치하지 않습니다.',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => isRegistering = true);

    final result = await registerUser(id: id, password: pw, name: name);

    setState(() => isRegistering = false);

    if (result['success'] == true) {
      Fluttertoast.showToast(
        msg: '회원가입이 완료되었습니다.',
        backgroundColor: TablerColors.success,
        textColor: Colors.white,
      );
      GoRouter.of(context).go('/');
    } else {
      Fluttertoast.showToast(
        msg: result['message'] ?? '회원가입 실패',
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
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 450),
              child: TablerCard(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 헤더
                    buildHeader(),
                    SizedBox(height: 32),

                    // 아이디 입력 및 중복확인
                    buildTextField(
                      controller: userController,
                      label: '아이디',
                      hintText: '사용할 아이디를 입력하세요',
                      prefixIcon: Icons.person_outline,
                    ),
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 120,
                        child: TablerButton(
                          text: isCheckingID ? '확인 중...' : '중복확인',
                          small: true,
                          outline: isIDAvailable,
                          type: isIDAvailable
                              ? TablerButtonType.success
                              : TablerButtonType.primary,
                          onPressed: isCheckingID ? null : checkDuplicateID,
                        ),
                      ),
                    ),

                    if (isIDAvailable) ...[
                      SizedBox(height: 24),
                      buildTextField(
                        controller: idController,
                        label: '닉네임',
                        hintText: '사용할 닉네임을 입력하세요',
                        prefixIcon: Icons.badge_outlined,
                      ),
                      SizedBox(height: 16),
                      buildTextField(
                        controller: pwController,
                        label: '비밀번호',
                        hintText: '비밀번호를 입력하세요',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                      ),
                      SizedBox(height: 16),
                      buildTextField(
                        controller: passwordController,
                        label: '비밀번호 확인',
                        hintText: '비밀번호를 다시 입력하세요',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                      ),

                      SizedBox(height: 32),

                      // 회원가입 버튼
                      SizedBox(
                        height: 48,
                        child: TablerButton(
                          text: isRegistering ? '가입 중...' : '회원가입',
                          icon: isRegistering ? null : Icons.person_add,
                          onPressed: isRegistering ? null : handleRegister,
                        ),
                      ),
                    ],

                    SizedBox(height: 24),

                    // 로그인 페이지로 이동
                    Center(
                      child: Column(
                        children: [
                          Text(
                            '이미 계정이 있으신가요?',
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
            color: TablerColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.person_add, color: TablerColors.success, size: 32),
        ),
        SizedBox(height: 16),
        Text(
          '회원가입',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: TablerColors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '새 계정을 만들어 수어 학습을 시작하세요',
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
