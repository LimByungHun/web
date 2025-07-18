import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sign_web/screen/home_screen.dart';
import 'package:sign_web/screen/insertuser_screen.dart';
import 'package:sign_web/screen/pwrecovery_screen.dart';
import 'package:sign_web/service/login_api.dart';
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
            padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      '제목',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  /*로그인 비밀번호 텍스트 박스*/
                  Textbox(controller: idController, hintText: '아이디'),
                  Textbox(
                    controller: pwController,
                    hintText: '비밀번호',
                    obscureText: true,
                  ),

                  /*로그인, 회원가입 버튼*/
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
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HomeScreen(),
                                  ),
                                );
                              } else {
                                if (!mounted) return;
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
                        SizedBox(
                          width: 120,
                          child: ButtonWidget(
                            text: '회원가입',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InsertuserScreen(),
                                ),
                              );
                            },
                            selected: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  /* 여기에 자동 로그인 추가 하면 될듯?*/
                  Text('비밀번호를 잊어버리셨나요?'),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PwrecoveryScreen()),
                      );
                    },
                    child: Text(
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
