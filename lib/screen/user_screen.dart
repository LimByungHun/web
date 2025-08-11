import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_web/main.dart';
import 'package:sign_web/screen/updateuser_screen.dart';
import 'package:sign_web/service/logout_api.dart';
import 'package:sign_web/service/token_storage.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/check_widget.dart';
import 'package:sign_web/widget/sidebar_widget.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => UserScreenState();
}

class UserScreenState extends State<UserScreen> {
  String nickname = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUserInfo();
  }

  Future<void> loadUserInfo() async {
    final loadedNickname = await TokenStorage.getNickName();
    setState(() {
      nickname = loadedNickname ?? 'Unknown User';
      isLoading = false;
    });
  }

  Future<void> handleLogout() async {
    final refreshToken = await TokenStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      print('토큰오류 (유효하지 않은 토큰)');
      return;
    }

    final success = await LogoutApi.logout(refreshToken);

    if (success) {
      await TokenStorage.clearTokens();
      Fluttertoast.showToast(
        msg: "로그아웃 되었습니다.",
        backgroundColor: TablerColors.success,
        textColor: Colors.white,
      );
      loginState.value = false;
      if (mounted) GoRouter.of(context).go('/');
    } else {
      Fluttertoast.showToast(
        msg: "로그아웃 실패",
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
        child: Row(
          children: [
            Sidebar(initialIndex: 6),
            VerticalDivider(width: 1, color: TablerColors.border),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 600),
                    padding: EdgeInsets.all(24),
                    child: isLoading
                        ? SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: TablerColors.primary,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: 40),
                              buildProfileCard(),
                              SizedBox(height: 24),
                              buildSettingsCard(),
                              SizedBox(height: 24),
                              buildDangerZoneCard(),
                              SizedBox(height: 40),
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

  Widget buildProfileCard() {
    return TablerCard(
      title: '프로필 정보',
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: TablerColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: TablerColors.primary.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(Icons.person, color: TablerColors.primary, size: 40),
          ),
          SizedBox(height: 16),
          Text(
            nickname,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: TablerColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSettingsCard() {
    return TablerCard(
      title: '계정 설정',
      child: Column(
        children: [
          buildSettingItem(
            icon: Icons.edit_outlined,
            title: '회원 정보 수정',
            subtitle: '닉네임과 비밀번호를 변경할 수 있습니다',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UpdateUserScreen(),
                ),
              ).then((_) => loadUserInfo()); // 수정 후 정보 새로고침
            },
          ),
          Divider(color: TablerColors.border, height: 32),
          buildSettingItem(
            icon: Icons.logout_outlined,
            title: '로그아웃',
            subtitle: '현재 계정에서 로그아웃합니다',
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => Check(
                  title: '로그아웃',
                  content: '정말 로그아웃 하시겠습니까?',
                  confirmText: '로그아웃',
                  onConfirm: handleLogout,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildDangerZoneCard() {
    return TablerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '위험 구역',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: TablerColors.danger,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            '계정을 삭제하면 모든 데이터가 영구적으로 삭제되며 복구할 수 없습니다.',
            style: TextStyle(fontSize: 14, color: TablerColors.textSecondary),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TablerButton(
              text: '회원 탈퇴',
              type: TablerButtonType.danger,
              outline: true,
              icon: Icons.delete_outline,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => Check(
                    title: '회원탈퇴',
                    content: '정말 탈퇴하시겠습니까?\n탈퇴시 모든 데이터가 삭제됩니다.',
                    confirmText: '탈퇴',
                    onConfirm: () {
                      Future.microtask(() => context.push('/delete'));
                    },
                  ),
                  barrierDismissible: false,
                  useRootNavigator: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: TablerColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: TablerColors.primary, size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: TablerColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: TablerColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: TablerColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
