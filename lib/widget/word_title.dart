import 'package:flutter/material.dart';
import 'package:sign_web/service/bookmark_api.dart';
import 'package:sign_web/theme/tabler_theme.dart';

class WordTile extends StatefulWidget {
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

  @override
  State<WordTile> createState() => WordTileState();
}

class WordTileState extends State<WordTile> {
  bool isHovered = false;
  bool isLoading = false;

  Future<void> handleBookmarkToggle() async {
    setState(() => isLoading = true);

    bool success;
    if (widget.isBookmarked) {
      success = await BookmarkApi.removeBookmark(wid: widget.wid);
    } else {
      success = await BookmarkApi.addBookmark(wid: widget.wid);
    }

    setState(() => isLoading = false);
    widget.onBookmarkToggle(success);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isHovered
              ? TablerColors.primary.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isHovered
              ? Border.all(color: TablerColors.primary.withOpacity(0.2))
              : null,
        ),
        child: ListTile(
          onTap: widget.onTap,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            widget.word,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: TablerColors.textPrimary,
            ),
          ),
          trailing: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(TablerColors.primary),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    widget.isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: widget.isBookmarked
                        ? TablerColors.warning
                        : TablerColors.textSecondary,
                  ),
                  onPressed: handleBookmarkToggle,
                  splashRadius: 20,
                ),
        ),
      ),
    );
  }
}
