import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:web/service/token_storage.dart';
import 'package:web/service/user_update_api.dart';
import 'package:web/widget/textbox_widget.dart';

class UpdateUserScreen extends StatefulWidget {
  const UpdateUserScreen({super.key});

  @override
  State<UpdateUserScreen> createState() => _UpdateUserScreenState();
}

class _UpdateUserScreenState extends State<UpdateUserScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController pwController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNickName();
  }

  void _loadNickName() async {
    final nickname = await TokenStorage.getNickName();
    if (nickname != null) {
      setState(() {
        nameController.text = nickname;
      });
    }
  }

  void handleUpdate() async {
    final result = await UpdateUserApi.updateUser(
      name: nameController.text.trim(),
      newPassword: pwController.text.trim(),
    );

    if (result["success"] == true) {
      await TokenStorage.setNickName(result["nickname"]);
      Fluttertoast.showToast(msg: "회원 정보 수정 완료");
      if (mounted) Navigator.pop(context);
    } else {
      Fluttertoast.showToast(msg: "변경 사항이 없습니다");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("회원 정보 수정")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Textbox(controller: nameController, hintText: "새 닉네임"),
            const SizedBox(height: 16),
            Textbox(
              controller: pwController,
              hintText: "새 비밀번호",
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: handleUpdate, child: const Text("수정하기")),
          ],
        ),
      ),
    );
  }
}
