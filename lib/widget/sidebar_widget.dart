import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_web/service/dictionary_api.dart';
import 'package:sign_web/service/token_storage.dart';

class Sidebar extends StatefulWidget {
  final int? initialIndex;
  const Sidebar({super.key, this.initialIndex});

  @override
  State<Sidebar> createState() => SidebarState();
}

class SidebarState extends State<Sidebar> {
  bool isExtended = false;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex ?? 0;
  }

  static const List<String> routePaths = [
    '/home',
    '/studycal',
    '/dictionary',
    '/translate',
    '/course',
    '/bookmark',
    '/user',
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      extended: isExtended,
      labelType: NavigationRailLabelType.none,
      leading: IconButton(
        icon: Icon(isExtended ? Icons.arrow_back_ios : Icons.menu),
        onPressed: () {
          setState(() {
            isExtended = !isExtended;
          });
        },
      ),
      selectedIndex: selectedIndex,
      onDestinationSelected: (idx) async {
        setState(() {
          selectedIndex = idx;
        });
        final path = routePaths[idx];
        if (path == '/dictionary') {
          try {
            final wordData = await DictionaryApi.fetchWords();
            final userId = await TokenStorage.getUserID();

            context.go(
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
          context.go(path);
        }
      },
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home),
          label: Text(
            '홈 화면',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.local_fire_department),
          label: Text(
            '캘린더',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.search),
          label: Text(
            '검색',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.g_translate),
          label: Text(
            '번역',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.menu_book_rounded),
          label: Text(
            '학습코스',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.bookmark_border),
          label: Text(
            '북마크',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person),
          label: Text(
            '사용자 설정',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
