import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:web/screen/login_screen.dart';
import 'package:web/service/signup_api.dart';
import 'package:web/widget/button_widget.dart';
import 'package:web/widget/textbox_widget.dart';

class InsertuserScreen extends StatefulWidget {
  const InsertuserScreen({super.key});

  @override
  State<InsertuserScreen> createState() => InsertuserScreenState();
}

class InsertuserScreenState extends State<InsertuserScreen> {
  final TextEditingController usercontroller = TextEditingController();
  final TextEditingController idcontroller = TextEditingController();
  final TextEditingController pwcontroller = TextEditingController();
  final TextEditingController passwordcontroller = TextEditingController();

  bool isIDAvailable = false;

  @override
  void dispose() {
    usercontroller.dispose();
    idcontroller.dispose();
    pwcontroller.dispose();
    passwordcontroller.dispose();
    super.dispose();
  }

  Future<void> checkDuplicateID() async {
    final id = usercontroller.text.trim();
    if (id.isEmpty) {
      Fluttertoast.showToast(
        msg: '아이디를 입력해주세요',
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }
    final result = await checkID(id);
    final available = result['available'] == true;

    setState(() {
      isIDAvailable = available;
    });

    Fluttertoast.showToast(
      msg: available ? '사용 가능한 아이디입니다.' : '이미 사용 중인 아이디입니다.',
      gravity: ToastGravity.BOTTOM,
      backgroundColor: available ? Colors.green : Colors.red,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 80,
        title: Text(
          '회원가입',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Textbox(controller: usercontroller, hintText: '닉네임을 입력하세요'),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 100,
                    child: ButtonWidget(
                      text: '중복확인',
                      onTap: checkDuplicateID,
                      selected: !isIDAvailable,
                    ),
                  ),
                ),

                if (isIDAvailable) ...{
                  Textbox(controller: idcontroller, hintText: '아이디를 입력하세요'),
                  Textbox(controller: pwcontroller, hintText: '비밀번호를 입력하세요'),
                  Textbox(
                    controller: passwordcontroller,
                    hintText: '비밀번호 확인',
                    obscureText: true,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 100,
                      child: ButtonWidget(
                        text: '회원가입',
                        onTap: () async {
                          final id = usercontroller.text.trim();
                          final name = idcontroller.text.trim();
                          final pw = pwcontroller.text.trim();
                          final confirmPw = passwordcontroller.text.trim();

                          if (id.isEmpty ||
                              name.isEmpty ||
                              pw.isEmpty ||
                              confirmPw.isEmpty) {
                            Fluttertoast.showToast(
                              msg: '닉네임 또는 비밀번호를 입력하지 않았습니다.',
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                            );
                            return;
                          }
                          if (pw != confirmPw) {
                            Fluttertoast.showToast(
                              msg: '비밀번호가 일치하지 않습니다.',
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                            );
                            return;
                          }

                          final result = await registerUser(
                            id: id,
                            password: pw,
                            name: name,
                          );

                          if (result['success'] == true) {
                            Fluttertoast.showToast(
                              msg: '회원가입이 완료되었습니다.',
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.green,
                              textColor: Colors.white,
                            );
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(),
                              ),
                            );
                          } else {
                            Fluttertoast.showToast(
                              msg: result['message'] ?? '회원가입 실패',
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                            );
                          }
                        },
                        selected: true,
                      ),
                    ),
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
