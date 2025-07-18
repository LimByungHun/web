import 'package:flutter/material.dart';
import 'package:sign_web/service/bookmark_api.dart';

class WordTile extends StatelessWidget {
  final String word;
  final int wid;
  final String userID;
  final bool isBookmarked;
  final VoidCallback onTap;
  final void Function(bool) onBookmarkToggle;

  const WordTile({
    super.key,
    required this.word,
    required this.wid,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmarkToggle,
    required this.userID,
  });

  Future<void> handleBookmarkToggle() async {
    bool success;
    if (isBookmarked) {
      success = await BookmarkApi.removeBookmark(wid: wid);
    } else {
      success = await BookmarkApi.addBookmark(wid: wid);
    }
    onBookmarkToggle(success);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(word),
      trailing: IconButton(
        icon: Icon(
          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          color: isBookmarked ? Colors.amber : null,
        ),
        onPressed: handleBookmarkToggle,
      ),
      onTap: onTap,
    );
  }
}
