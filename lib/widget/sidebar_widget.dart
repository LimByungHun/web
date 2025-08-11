import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_web/service/dictionary_api.dart';
import 'package:sign_web/service/token_storage.dart';
import 'package:sign_web/theme/tabler_theme.dart';

class Sidebar extends StatefulWidget {
  final int? initialIndex;
  const Sidebar({super.key, this.initialIndex});

  @override
  State<Sidebar> createState() => SidebarState();
}

class SidebarState extends State<Sidebar> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex ?? 0;
  }

  static const List<String> routePaths = [
    '/home',
    '/calendar',
    '/dictionary',
    '/translate',
    '/course',
    '/bookmark',
    '/user',
  ];

  static const List<SidebarItem> menuItems = [
    SidebarItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '홈'),
    SidebarItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      label: '캘린더',
    ),
    SidebarItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      label: '사전',
    ),
    SidebarItem(
      icon: Icons.g_translate_outlined,
      activeIcon: Icons.g_translate,
      label: '장문 연습',
    ),
    SidebarItem(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
      label: '학습코스',
    ),
    SidebarItem(
      icon: Icons.bookmark_border_outlined,
      activeIcon: Icons.bookmark,
      label: '북마크',
    ),
    SidebarItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: '설정',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: TablerColors.border)),
      ),
      child: Column(
        children: [
          // 로고/제목 영역
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: TablerColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: TablerColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.sign_language,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '수어 술술',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: TablerColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // 메뉴 항목들
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final isSelected = selectedIndex == index;

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () async {
                        setState(() => selectedIndex = index);
                        await _handleNavigation(index);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? TablerColors.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.icon,
                              size: 20,
                              color: isSelected
                                  ? TablerColors.primary
                                  : TablerColors.textSecondary,
                            ),
                            SizedBox(width: 12),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? TablerColors.primary
                                    : TablerColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNavigation(int index) async {
    final path = routePaths[index];

    if (path == '/dictionary') {
      try {
        final wordData = await DictionaryApi.fetchWords();
        final userId = await TokenStorage.getUserID();

        GoRouter.of(context).go(
          '/dictionary',
          extra: {
            'words': wordData.words,
            'wordIdMap': wordData.wordIDMap,
            'userID': userId ?? '',
          },
        );
      } catch (e) {
        Fluttertoast.showToast(msg: '사전 로딩 오류');
      }
    } else {
      GoRouter.of(context).go(path);
    }
  }
}

class SidebarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
