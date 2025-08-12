import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sign_web/widget/animation_widget.dart';
import 'package:sign_web/service/bookmark_api.dart';
import 'package:sign_web/service/word_detail_api.dart';
import 'package:sign_web/widget/indexbar.dart';
import 'package:sign_web/widget/sidebar_widget.dart';
import 'package:sign_web/widget/word_title.dart';

class Dictionary extends StatefulWidget {
  final List<String> words;
  final Map<String, int> wordIdMap;
  final String userID;
  const Dictionary({
    super.key,
    required this.words,
    required this.wordIdMap,
    required this.userID,
  });

  @override
  State<Dictionary> createState() => DictionaryState();
}

class DictionaryState extends State<Dictionary> {
  late List<String> filteredWordList;
  final Set<String> bookmarked = {};
  final Map<String, GlobalKey> wordKeys = {};
  final ScrollController scrollController = ScrollController();
  final TextEditingController searchController = TextEditingController();

  String? selected;
  int? selectedWid;
  String? selectedPos;
  String? selectedDefinition;
  bool isLoadingDetail = false;

  late Future<void> initVideoPlayer;

  final GlobalKey<AnimationWidgetState> animationKey =
      GlobalKey<AnimationWidgetState>();
  List<Uint8List>? animationFrames;

  final List<String> initials = [
    '#',
    'ㄱ',
    'ㄲ',
    'ㄴ',
    'ㄷ',
    'ㄸ',
    'ㄹ',
    'ㅁ',
    'ㅂ',
    'ㅃ',
    'ㅅ',
    'ㅆ',
    'ㅇ',
    'ㅈ',
    'ㅉ',
    'ㅊ',
    'ㅋ',
    'ㅌ',
    'ㅍ',
    'ㅎ',
  ];

  @override
  void initState() {
    super.initState();
    filteredWordList = List.from(widget.words);
    for (var w in widget.words) {
      wordKeys[w] = GlobalKey();
    }
    loadInitialBookmarks();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> loadInitialBookmarks() async {
    try {
      final result = await BookmarkApi.loadBookmark();
      setState(() {
        bookmarked.addAll(result.keys);
      });
    } catch (e) {
      Fluttertoast.showToast(msg: '북마크 로드 실패');
    }
  }

  String getInitial(String text) {
    final code = text.codeUnitAt(0) - 0xAC00;
    if (code < 0xAC00 || code > 0xD7A3) return '#';
    const init = [
      'ㄱ',
      'ㄲ',
      'ㄴ',
      'ㄷ',
      'ㄸ',
      'ㄹ',
      'ㅁ',
      'ㅂ',
      'ㅃ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅉ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ',
    ];
    return init[(code - 0xAC00) ~/ 588];
  }

  void toggleBookmark(String word, bool success) {
    if (!success) {
      Fluttertoast.showToast(msg: '북마크 변경 실패');
      return;
    }
    setState(() {
      if (bookmarked.contains(word)) {
        bookmarked.remove(word);
        Fluttertoast.showToast(msg: '$word 북마크 해제');
      } else {
        bookmarked.add(word);
        Fluttertoast.showToast(msg: '$word 북마크 추가');
      }
    });
  }

  void selectWord(String word) async {
    FocusScope.of(context).unfocus();

    final wid = widget.wordIdMap[word];
    if (wid == null || wid == 0) return;

    setState(() {
      selected = word;
      selectedWid = wid;
      selectedPos = null;
      selectedDefinition = null;
      isLoadingDetail = true;
    });

    try {
      final data = await WordDetailApi.fetch(wid: wid);
      final decodedFrames = data['frames'] as List<Uint8List>;

      setState(() {
        selectedPos = data['pos'];
        selectedDefinition = data['definition'];
        animationFrames = decodedFrames;
        isLoadingDetail = false;
      });
    } catch (e) {
      Fluttertoast.showToast(msg: '단어 정보를 불러오는데 실패했습니다.');
      setState(() => isLoadingDetail = false);
    }
  }

  void scrollToInitial(String initial) {
    final idx = initial == '#'
        ? filteredWordList.indexWhere((w) => RegExp(r'^[0-9]').hasMatch(w))
        : filteredWordList.indexWhere((w) => getInitial(w) == initial);
    if (idx != -1) {
      scrollController.animateTo(
        idx * 56,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void performSearch() {
    final q = searchController.text.trim();
    setState(() {
      if (q.isEmpty) {
        filteredWordList = List.from(widget.words);
      } else {
        filteredWordList = widget.words.where((w) => w.contains((q))).toList();
      }
      selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(initialIndex: 2),
            VerticalDivider(width: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      // 검색창
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                decoration: InputDecoration(
                                  hintText: '사전 검색',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                                onTap: () => setState(() => selected = null),
                                onSubmitted: (_) => performSearch(),
                              ),
                            ),
                            IconButton(
                              onPressed: performSearch,
                              icon: Icon(Icons.search),
                            ),
                          ],
                        ),
                      ),
                      // 단어 리스트 + 상세 정보 (2분할)
                      Expanded(
                        flex: 5,
                        child: Stack(
                          children: [
                            Row(
                              children: [
                                // 왼쪽: 리스트
                                Expanded(
                                  flex: selected == null ? 1 : 2,
                                  child: ListView(
                                    controller: scrollController,
                                    padding: EdgeInsets.only(
                                      right: 24,
                                      bottom: bottomInset,
                                    ),
                                    children: filteredWordList.map((word) {
                                      return WordTile(
                                        key: wordKeys[word],
                                        word: word,
                                        wid: widget.wordIdMap[word] ?? 0,
                                        userID: widget.userID,
                                        isBookmarked: bookmarked.contains(word),
                                        onTap: () => selectWord(word),
                                        onBookmarkToggle: (result) =>
                                            toggleBookmark(word, result),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                VerticalDivider(width: 1),
                                // 오른쪽: 상세 영역
                                if (selected != null)
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      padding: EdgeInsets.all(24),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                selected ?? '',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.close),
                                                onPressed: () => setState(
                                                  () => selected = null,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            '[${selectedPos ?? ''}] ${selectedDefinition ?? ''}',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(height: 16),
                                          animationFrames != null &&
                                                  animationFrames!.isNotEmpty
                                              ? Column(
                                                  children: [
                                                    AnimationWidget(
                                                      key: animationKey,
                                                      frames: animationFrames!,
                                                      fps: 12.0,
                                                    ),
                                                    SizedBox(height: 8),
                                                    ElevatedButton.icon(
                                                      onPressed: () =>
                                                          animationKey
                                                              .currentState
                                                              ?.reset(),
                                                      icon: Icon(Icons.replay),
                                                      label: Text('다시보기'),
                                                    ),
                                                  ],
                                                )
                                              : SizedBox(
                                                  height: 150,
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ),
                                  ),
                                SizedBox(width: 32),
                              ],
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              width: 32,
                              child: isKeyboardVisible
                                  ? SizedBox.shrink()
                                  : Indexbar(
                                      initials: initials,
                                      onTap: scrollToInitial,
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
          ],
        ),
      ),
    );
  }
}
