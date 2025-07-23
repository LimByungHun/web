import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_web/main.dart';
import 'package:sign_web/screen/updateuser_screen.dart';
import 'package:sign_web/service/logout_api.dart';
import 'package:sign_web/service/token_storage.dart';
import 'package:sign_web/widget/button_widget.dart';
import 'package:sign_web/widget/check_widget.dart';
import 'package:sign_web/widget/sidebar_widget.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => UserScreenState();
}

class UserScreenState extends State<UserScreen> {
  String nickname = '';
  int selectedIndex = -11;
  static double maxContentWidth = 600;

  @override
  void initState() {
    super.initState();
    getnickname();
  }

  void getnickname() async {
    final loadnickname = await TokenStorage.getNickName();
    setState(() {
      nickname = loadnickname ?? 'noname';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(initialIndex: 6),
            VerticalDivider(width: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        SizedBox(height: 40),

                        //아이콘 + 이름
                        Icon(Icons.person, color: Colors.purple, size: 120),
                        SizedBox(height: 16),
                        Text(
                          nickname,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 32),

                        SizedBox(
                          width: 250,
                          child: ButtonWidget(
                            text: '회원 정보 수정',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const UpdateUserScreen(),
                                ),
                              );
                            },
                            selected: selectedIndex == 0,
                          ),
                        ),
                        SizedBox(
                          width: 250,
                          child: ButtonWidget(
                            text: '로그아웃',
                            onTap: () {
                              setState(() => selectedIndex = 1);
                              showDialog(
                                context: context,
                                builder: (_) => Check(
                                  title: '로그아웃',
                                  content: '로그아웃 하시겠습니까?',
                                  onConfirm: () async {
                                    final refreshToken =
                                        await TokenStorage.getRefreshToken();

                                    if (refreshToken == null ||
                                        refreshToken.isEmpty) {
                                      print('토큰오류 (유효하지 않은 토큰)');
                                      return;
                                    }
                                    final success = await LogoutApi.logout(
                                      refreshToken,
                                    );

                                    if (success) {
                                      await TokenStorage.clearTokens(); // 토큰 삭제
                                      Fluttertoast.showToast(
                                        msg: "로그아웃 되었습니다.",
                                        gravity: ToastGravity.BOTTOM,
                                        backgroundColor: Colors.green,
                                        textColor: Colors.white,
                                      );
                                      loginState.value = false;
                                      GoRouter.of(context).go('/');
                                    } else {
                                      Fluttertoast.showToast(
                                        msg: "로그아웃 실패",
                                        gravity: ToastGravity.BOTTOM,
                                        backgroundColor: Colors.red,
                                        textColor: Colors.white,
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                            selected: selectedIndex == 1,
                          ),
                        ),
                        Spacer(),
                        SizedBox(
                          width: 250,
                          child: ButtonWidget(
                            text: '회원 탈퇴',
                            textStyle: TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                              fontWeight: FontWeight.normal,
                            ),
                            onTap: () {
                              setState(() => selectedIndex = 2);
                              showDialog(
                                context: context,
                                builder: (_) => Check(
                                  title: '회원탈퇴',
                                  content: '정말 탈퇴하시겠습니까?\n 탈퇴시 모든 데이터가 삭제됩니다.',
                                  confirmText: '탈퇴',
                                  onConfirm: () {
                                    Future.microtask(
                                      () => context.push('/delete'),
                                    );
                                  },
                                ),
                                barrierDismissible: false,
                                useRootNavigator: true,
                              );
                            },
                            selected: selectedIndex == 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
