import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sign_web/service/token_storage.dart';
import 'package:sign_web/service/user_update_api.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

class UpdateUserScreen extends StatefulWidget {
  const UpdateUserScreen({super.key});

  @override
  State<UpdateUserScreen> createState() => _UpdateUserScreenState();
}

class _UpdateUserScreenState extends State<UpdateUserScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController currentPwController = TextEditingController();
  final TextEditingController pwController = TextEditingController();
  final TextEditingController confirmPwController = TextEditingController();

  bool isLoading = false;
  bool isLoadingProfile = true;
  String? originalNickname;

  @override
  void initState() {
    super.initState();
    loadUserInfo();
  }

  @override
  void dispose() {
    nameController.dispose();
    currentPwController.dispose();
    pwController.dispose();
    confirmPwController.dispose();
    super.dispose();
  }

  Future<void> loadUserInfo() async {
    try {
      final nickname = await TokenStorage.getNickName();
      if (nickname != null) {
        setState(() {
          originalNickname = nickname;
          nameController.text = nickname;
          isLoadingProfile = false;
        });
      } else {
        setState(() => isLoadingProfile = false);
        Fluttertoast.showToast(
          msg: '사용자 정보를 불러올 수 없습니다',
          backgroundColor: TablerColors.danger,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      setState(() => isLoadingProfile = false);
      Fluttertoast.showToast(
        msg: '사용자 정보 로딩 중 오류가 발생했습니다',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
    }
  }

  Future<void> handleUpdate() async {
    final name = nameController.text.trim();
    final currentPassword = currentPwController.text.trim();
    final newPassword = pwController.text.trim();
    final confirmPassword = confirmPwController.text.trim();

    // 입력 검증
    if (name.isEmpty) {
      Fluttertoast.showToast(
        msg: '닉네임을 입력해주세요',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
      return;
    }

    // 변경사항 확인
    bool hasNameChange = name != originalNickname;
    bool hasPasswordChange = newPassword.isNotEmpty;

    if (!hasNameChange && !hasPasswordChange) {
      Fluttertoast.showToast(
        msg: '변경된 내용이 없습니다',
        backgroundColor: TablerColors.warning,
        textColor: Colors.white,
      );
      return;
    }

    // 비밀번호 변경시 현재 비밀번호 확인 필수
    if (hasPasswordChange && currentPassword.isEmpty) {
      Fluttertoast.showToast(
        msg: '비밀번호를 변경하려면 현재 비밀번호를 입력해주세요',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
      return;
    }

    // 새 비밀번호 확인 검증
    if (hasPasswordChange && newPassword != confirmPassword) {
      Fluttertoast.showToast(
        msg: '새 비밀번호가 일치하지 않습니다',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
      return;
    }

    // 새 비밀번호와 현재 비밀번호가 같은지 확인
    if (hasPasswordChange && currentPassword == newPassword) {
      Fluttertoast.showToast(
        msg: '새 비밀번호는 현재 비밀번호와 달라야 합니다',
        backgroundColor: TablerColors.warning,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await UpdateUserApi.updateUser(
        name: name,
        newPassword: newPassword,
      );

      setState(() => isLoading = false);

      if (result["success"] == true) {
        // 성공시 로컬 저장소 업데이트
        if (hasNameChange) {
          await TokenStorage.setNickName(name);
          setState(() => originalNickname = name);
        }

        // 비밀번호 필드 초기화
        currentPwController.clear();
        pwController.clear();
        confirmPwController.clear();

        Fluttertoast.showToast(
          msg: "회원 정보가 성공적으로 수정되었습니다",
          backgroundColor: TablerColors.success,
          textColor: Colors.white,
        );

        // 잠시 후 화면 닫기
        await Future.delayed(Duration(milliseconds: 1500));
        if (mounted) Navigator.pop(context, true);
      } else {
        String errorMessage = "정보 수정에 실패했습니다";
        if (result["message"] != null) {
          errorMessage = result["message"];
        } else if (result["error"] == "invalid_password") {
          errorMessage = "현재 비밀번호가 일치하지 않습니다";
        }

        Fluttertoast.showToast(
          msg: errorMessage,
          backgroundColor: TablerColors.danger,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      Fluttertoast.showToast(
        msg: "서버 오류가 발생했습니다. 다시 시도해주세요",
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
    }
  }

  bool hasChanges() {
    final name = nameController.text.trim();
    final newPassword = pwController.text.trim();

    return (name != originalNickname) || newPassword.isNotEmpty;
  }

  bool isChangingPassword() {
    return pwController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablerColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '회원 정보 수정',
          style: TextStyle(
            color: TablerColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: TablerColors.textPrimary),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 500),
              child: isLoadingProfile ? buildLoadingState() : buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLoadingState() {
    return TablerCard(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: TablerColors.primary),
          SizedBox(height: 16),
          Text(
            '사용자 정보를 불러오는 중...',
            style: TextStyle(fontSize: 16, color: TablerColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget buildContent() {
    return Column(
      children: [buildFormCard(), SizedBox(height: 24), buildActionButtons()],
    );
  }

  Widget buildFormCard() {
    return TablerCard(
      title: '정보 수정',
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 닉네임 변경 섹션
          buildSectionTitle('기본 정보'),
          SizedBox(height: 16),
          buildTextField(
            controller: nameController,
            label: '닉네임',
            hintText: '새 닉네임을 입력하세요',
            prefixIcon: Icons.person_outline,
            isRequired: true,
          ),

          SizedBox(height: 32),

          // 비밀번호 변경 섹션
          buildSectionTitle('비밀번호 변경'),
          SizedBox(height: 8),

          // 현재 비밀번호 (새 비밀번호 입력시에만 표시)
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            height: isChangingPassword() ? null : 0,
            child: isChangingPassword()
                ? Column(
                    children: [
                      buildTextField(
                        controller: currentPwController,
                        label: '현재 비밀번호',
                        hintText: '현재 비밀번호를 입력하세요',
                        prefixIcon: Icons.lock,
                        obscureText: true,
                        isRequired: true,
                      ),
                      SizedBox(height: 16),
                    ],
                  )
                : SizedBox(),
          ),

          buildTextField(
            controller: pwController,
            label: '새 비밀번호',
            hintText: '새 비밀번호를 입력하세요',
            prefixIcon: Icons.lock_outline,
            obscureText: true,
          ),
          SizedBox(height: 16),

          // 새 비밀번호 확인 (새 비밀번호 입력시에만 표시)
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            height: isChangingPassword() ? null : 0,
            child: isChangingPassword()
                ? Column(
                    children: [
                      buildTextField(
                        controller: confirmPwController,
                        label: '새 비밀번호 확인',
                        hintText: '새 비밀번호를 다시 입력하세요',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        isRequired: true,
                      ),
                      SizedBox(height: 16),
                    ],
                  )
                : SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: TablerColors.textPrimary,
      ),
    );
  }

  Widget buildInfoBox(String message, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: TablerColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: TablerColors.textPrimary,
              ),
            ),
            if (isRequired) ...[
              SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(fontSize: 14, color: TablerColors.danger),
              ),
            ],
          ],
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: (_) => setState(() {}), // 변경사항 감지를 위해
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

  Widget buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TablerButton(
            text: isLoading ? '저장 중...' : '변경사항 저장',
            icon: isLoading ? null : Icons.save,
            onPressed: (isLoading || !hasChanges()) ? null : handleUpdate,
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TablerButton(
            text: '취소',
            outline: true,
            onPressed: isLoading
                ? null
                : () {
                    if (hasChanges()) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('변경사항 무시'),
                          content: Text('저장하지 않은 변경사항이 있습니다. 정말 취소하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('계속 편집'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                '취소',
                                style: TextStyle(color: TablerColors.danger),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
          ),
        ),
      ],
    );
  }
}
