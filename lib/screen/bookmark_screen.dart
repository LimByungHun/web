import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:video_player/video_player.dart';
import 'package:sign_web/service/bookmark_api.dart';
import 'package:sign_web/service/word_detail_api.dart';
import 'package:sign_web/widget/indexbar.dart';
import 'package:sign_web/widget/sidebar_widget.dart';
import 'package:sign_web/widget/word_title.dart';

class Bookmark extends StatefulWidget {
  const Bookmark({super.key});

  @override
  State<Bookmark> createState() => _BookmarkState();
}

class _BookmarkState extends State<Bookmark> {
  Map<String, int> wordIdMap = {};
  List<String> filteredWords = [];
  final Set<String> bookmarked = {};
  final ScrollController scrollController = ScrollController();
  final TextEditingController searchController = TextEditingController();

  String? selected;
  int? selectedWid;
  String? selectedPos;
  String? selectedDefinition;
  bool isLoadingDetail = false;

  VideoPlayerController? controller;
  late Future<void> initVideoPlayer;

  // 초성 인덱스
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
    loadBookmarks();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> loadBookmarks() async {
    try {
      final result = await BookmarkApi.loadBookmark();
      setState(() {
        wordIdMap = result;
        filteredWords = result.keys.toList()..sort();
        bookmarked.clear();
        bookmarked.addAll(result.keys);
      });
    } catch (e) {
      Fluttertoast.showToast(msg: '북마크 로드 실패');
    }
  }

  void toggleBookmark(String word, bool success) {
    if (!success) {
      Fluttertoast.showToast(msg: '북마크 변경 실패');
      return;
    }
    setState(() {
      if (bookmarked.contains(word)) {
        bookmarked.remove(word);
        Fluttertoast.showToast(msg: '“$word” 북마크 해제');
      } else {
        bookmarked.add(word);
        Fluttertoast.showToast(msg: '“$word” 북마크 추가');
      }
    });
  }

  void selectWord(String word) async {
    FocusScope.of(context).unfocus();

    final wid = wordIdMap[word];
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

      controller =
          VideoPlayerController.networkUrl(
              Uri.parse(
                'http://10.101.170.168/video/${Uri.encodeComponent(word)}.mp4',
              ),
            )
            ..setLooping(true)
            ..setPlaybackSpeed(1.0);

      initVideoPlayer = controller!.initialize().then((_) {
        setState(() {});
        controller!.play();
      });

      setState(() {
        selectedPos = data['pos'];
        selectedDefinition = data['definition'];
        isLoadingDetail = false;
      });
    } catch (e) {
      Fluttertoast.showToast(msg: '단어 정보를 불러오는 데 실패했습니다.');
      setState(() => isLoadingDetail = false);
    }
  }

  String getInitial(String word) {
    final code = word.codeUnitAt(0);
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

  List<String> getSortedInitials() {
    final s = filteredWords.map(getInitial).toSet().toList();
    s.sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });
    return s;
  }

  void scrollToInitial(String initial) {
    final idx = initial == '#'
        ? filteredWords.indexWhere((w) => !RegExp(r'^[가-힣]').hasMatch(w))
        : filteredWords.indexWhere((w) => getInitial(w) == initial);
    if (idx != -1) {
      scrollController.animateTo(
        idx * 56.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void search() {
    final q = searchController.text.trim();
    setState(() {
      if (q.isEmpty) {
        filteredWords = wordIdMap.keys.toList()..sort();
      } else {
        filteredWords = wordIdMap.keys.where((w) => w.contains(q)).toList()
          ..sort();
      }
      selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final initials = getSortedInitials();
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(initialIndex: 5),
            VerticalDivider(width: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                decoration: InputDecoration(
                                  hintText: '북마크 단어 검색',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                                onSubmitted: (_) => search(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: search,
                            ),
                          ],
                        ),
                      ),
                      // 단어 리스트 + 인덱스바
                      Expanded(
                        flex: 5,
                        child: Stack(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: selected == null ? 1 : 2,
                                  child: ListView.builder(
                                    controller: scrollController,
                                    itemCount: filteredWords.length,
                                    itemBuilder: (ctx, idx) {
                                      final w = filteredWords[idx];
                                      return WordTile(
                                        word: w,
                                        wid: wordIdMap[w] ?? 0,
                                        userID: '',
                                        isBookmarked: bookmarked.contains(w),
                                        onTap: () => selectWord(w),
                                        onBookmarkToggle: (result) =>
                                            toggleBookmark(w, result),
                                      );
                                    },
                                  ),
                                ),
                                VerticalDivider(width: 1),
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
                                          if (controller != null)
                                            FutureBuilder(
                                              future: initVideoPlayer,
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                        ConnectionState.done &&
                                                    controller!
                                                        .value
                                                        .isInitialized) {
                                                  return AspectRatio(
                                                    aspectRatio: controller!
                                                        .value
                                                        .aspectRatio,
                                                    child: VideoPlayer(
                                                      controller!,
                                                    ),
                                                  );
                                                } else {
                                                  return SizedBox(
                                                    height: 120,
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          SizedBox(height: 16),
                                          Text('수화 설명 출력 예정'),
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
