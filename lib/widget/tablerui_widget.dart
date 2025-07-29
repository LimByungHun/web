import 'package:flutter/material.dart';
import 'package:sign_web/theme/tabler_theme.dart';

class TablerCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final List<Widget>? actions;

  const TablerCard({
    super.key,
    required this.child,
    this.title,
    this.padding,
    this.margin,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TablerColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TablerColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || actions != null)
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: TablerColors.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: TablerColors.textPrimary,
                        ),
                      ),
                    ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
          Padding(padding: padding ?? EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

class TablerButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final TablerButtonType type;
  final bool outline;
  final bool small;
  final IconData? icon;

  const TablerButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = TablerButtonType.primary,
    this.outline = false,
    this.small = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = getColor();
    final buttonStyle = outline
        ? OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding: small
                ? EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                : EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: small
                ? EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                : EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          );

    if (icon != null) {
      return outline
          ? OutlinedButton.icon(
              style: buttonStyle,
              onPressed: onPressed,
              icon: Icon(icon, size: small ? 16 : 18),
              label: Text(text, style: TextStyle(fontSize: small ? 12 : 14)),
            )
          : ElevatedButton.icon(
              style: buttonStyle,
              onPressed: onPressed,
              icon: Icon(icon, size: small ? 16 : 18),
              label: Text(text, style: TextStyle(fontSize: small ? 12 : 14)),
            );
    } else {
      return outline
          ? OutlinedButton(
              style: buttonStyle,
              onPressed: onPressed,
              child: Text(text, style: TextStyle(fontSize: small ? 12 : 14)),
            )
          : ElevatedButton(
              style: buttonStyle,
              onPressed: onPressed,
              child: Text(text, style: TextStyle(fontSize: small ? 12 : 14)),
            );
    }
  }

  Color getColor() {
    switch (type) {
      case TablerButtonType.primary:
        return TablerColors.primary;
      case TablerButtonType.success:
        return TablerColors.success;
      case TablerButtonType.warning:
        return TablerColors.warning;
      case TablerButtonType.danger:
        return TablerColors.danger;
      case TablerButtonType.secondary:
        return TablerColors.secondary;
    }
  }
}

enum TablerButtonType { primary, secondary, success, warning, danger }

class TablerStatsCard extends StatelessWidget {
  final int learnedWords;
  final int streakDays;
  final double overallPercent;

  const TablerStatsCard({
    super.key,
    required this.learnedWords,
    required this.streakDays,
    required this.overallPercent,
  });

  @override
  Widget build(BuildContext context) {
    return TablerCard(
      title: '학습 통계',
      child: Column(
        children: [
          // 진행률 표시
          Row(
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: overallPercent / 100,
                      strokeWidth: 4,
                      backgroundColor: TablerColors.border,
                      valueColor: AlwaysStoppedAnimation(TablerColors.primary),
                    ),
                    Text(
                      '${overallPercent.round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: TablerColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '전체 진행률',
                      style: TextStyle(
                        fontSize: 14,
                        color: TablerColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${overallPercent.round()}% 완료',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: TablerColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // 통계 항목들
          Row(
            children: [
              Expanded(
                child: buildStatItem(
                  '학습한 단어',
                  '$learnedWords개',
                  TablerColors.success,
                  Icons.school,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: buildStatItem(
                  '연속 학습',
                  '$streakDays일',
                  TablerColors.warning,
                  Icons.local_fire_department,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildStatItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: TablerColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: TablerColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class TablerStatsCard2 extends StatelessWidget {
  final int learnedWords;
  final int streakDays;
  final double overallPercent;

  const TablerStatsCard2({
    super.key,
    required this.learnedWords,
    required this.streakDays,
    required this.overallPercent,
  });

  @override
  Widget build(BuildContext context) {
    return TablerCard(
      title: '학습 통계',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        // 진행률 표시
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: overallPercent / 100,
                  strokeWidth: 4,
                  backgroundColor: TablerColors.border,
                  valueColor: AlwaysStoppedAnimation(TablerColors.primary),
                ),
                Text(
                  '${overallPercent.round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TablerColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '전체 진행률',
                  style: TextStyle(
                    fontSize: 14,
                    color: TablerColors.textSecondary,
                  ),
                ),
                Text(
                  '${overallPercent.round()}% 완료',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: TablerColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // 통계 항목들
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width - 80) / 4,
                child: buildStatItem(
                  '학습한 단어',
                  '$learnedWords개',
                  TablerColors.success,
                  Icons.school,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 80) / 4,
                child: buildStatItem(
                  '연속 학습',
                  '$streakDays일',
                  TablerColors.warning,
                  Icons.local_fire_department,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildStatItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: TablerColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: TablerColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
