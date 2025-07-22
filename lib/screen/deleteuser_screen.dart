import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sign_web/main.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/service/delete_user_api.dart';
import 'package:sign_web/service/token_storage.dart';

class DeleteUserScreen extends StatefulWidget {
  const DeleteUserScreen({super.key});

  @override
  State<DeleteUserScreen> createState() => _DeleteUserScreenState();
}

class _DeleteUserScreenState extends State<DeleteUserScreen> {
  final TextEditingController pwController = TextEditingController();
  bool isLoading = false;

  void handleDelete() async {
    setState(() => isLoading = true);

    final accessToken = await TokenStorage.getAccessToken() ?? '';
    final refreshToken = await TokenStorage.getRefreshToken() ?? '';

    final success = await DeleteUserApi.deleteUser(
      password: pwController.text,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    setState(() => isLoading = false);

    if (success) {
      await TokenStorage.clearTokens();
      final courseModel = context.read<CourseModel>();
      await courseModel.clearSelectedCourse();
      Fluttertoast.showToast(msg: "회원 탈퇴가 완료되었습니다.");

      loginState.value = false;
      if (mounted) {
        GoRouter.of(context).go('/');
      }
    } else {
      Fluttertoast.showToast(msg: "비밀번호가 일치하지 않거나 오류가 발생했습니다.");
    }
  }

  @override
  void dispose() {
    pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("회원탈퇴")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("정말 탈퇴하시겠습니까?\n비밀번호를 입력해주세요."),
            SizedBox(height: 20),
            TextField(
              controller: pwController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "비밀번호",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: handleDelete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: Text("회원탈퇴", style: TextStyle(color: Colors.white)),
                  ),
          ],
        ),
      ),
    );
  }
}
