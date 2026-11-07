import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tp_theme.dart';

// 版面元件：參考設計稿（大標題＋副標、圓形圖示按鈕、數字膠囊、資料夾分頁卡片、
// 膠囊篩選列、浮動膠囊導覽列）。配色只用色票裡的 Primary / Secondary / Grayscale。

/// 頁面上方：左邊頭像（或返回鍵）、右邊圓形按鈕，下面大標題＋副標。
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final bool large;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(width: double.infinity), // 撐滿寬度，標題靠左
        if (leading != null || actions.isNotEmpty)
          Row(children: [
            if (leading != null) leading!,
            const Spacer(),
            ...actions,
          ]),
        SizedBox(height: leading != null || actions.isNotEmpty ? 18 : 4),
        Text(title, style: large ? TPText.h1.copyWith(fontSize: 30) : TPText.h2.copyWith(fontSize: 26)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: TPText.body.copyWith(fontSize: 15, color: TPColors.grayscale500)),
        ],
      ]),
    );
  }
}

/// 頭像圓圈（名字第一個字）。
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  final Color background;

  const Avatar(this.name,
      {super.key, this.size = 56, this.color = TPColors.primary700, this.background = TPColors.primary100});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(name.isEmpty ? '?' : name.characters.first,
          style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// 白色圓形圖示按鈕（可加紅點數字）。
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final int badge;
  final double size;
  final Color background;
  final Color foreground;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.badge = 0,
    this.size = 52,
    this.background = TPColors.white,
    this.foreground = TPColors.grayscale800,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: SizedBox(
            width: size,
            height: size,
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              offset: const Offset(2, -2),
              child: Center(child: Icon(icon, size: size * 0.46, color: foreground)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 一排數字膠囊（例如：等您確認 2 / 已報名 5 / 家人 1）。
/// 給 onTaps 就可以點進去看詳細清單（右上角出現小箭頭）；onLongPresses 給長者唸說明。
class StatPills extends StatelessWidget {
  final List<(String label, String value)> items;
  final bool large;
  final List<VoidCallback?>? onTaps;
  final List<VoidCallback?>? onLongPresses;

  const StatPills(this.items, {super.key, this.large = false, this.onTaps, this.onLongPresses});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _pill(i)),
        ],
      ]),
    );
  }

  Widget _pill(int i) {
    final tap = onTaps != null && i < onTaps!.length ? onTaps![i] : null;
    final longPress = onLongPresses != null && i < onLongPresses!.length ? onLongPresses![i] : null;
    final radius = BorderRadius.circular(18);
    return Semantics(
      button: tap != null,
      label: '${items[i].$1} ${items[i].$2}',
      child: Material(
        color: TPColors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: tap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  tap();
                },
          onLongPress: longPress,
          child: Stack(children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: large ? 14 : 12, horizontal: 8),
              child: Center(
                heightFactor: 1,
                child: Column(children: [
                  Text(items[i].$2,
                      style: TextStyle(
                          fontSize: large ? 26 : 22, fontWeight: FontWeight.w700, color: TPColors.grayscale900)),
                  const SizedBox(height: 2),
                  Text(items[i].$1,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: large ? 15 : 12, color: TPColors.grayscale500)),
                ]),
              ),
            ),
            if (tap != null)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.chevron_right, size: 18, color: TPColors.grayscale400),
              ),
          ]),
        ),
      ),
    );
  }
}

/// 膠囊篩選列（活動類型、行政區）。選中的是深色膠囊。
class PillSelector<T> extends StatelessWidget {
  final List<(T value, String label, IconData? icon)> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool large;

  const PillSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: large ? 56 : 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (value, label, icon) = options[i];
          final on = value == selected;
          return Material(
            color: on ? TPColors.grayscale900 : TPColors.white,
            shape: StadiumBorder(side: BorderSide(color: on ? TPColors.grayscale900 : TPColors.grayscale200)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(value);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: large ? 18 : 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[
                    Icon(icon, size: large ? 22 : 18, color: on ? TPColors.white : TPColors.grayscale600),
                    const SizedBox(width: 6),
                  ],
                  Text(label,
                      style: TextStyle(
                          fontSize: large ? 18 : 14,
                          fontWeight: FontWeight.w600,
                          color: on ? TPColors.white : TPColors.grayscale700)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 資料夾分頁卡片：左上角凸出一個分頁（放類型膠囊），下面是內容。
/// dark = 深色強調卡（參考圖中間那張）。
class FolderCard extends StatelessWidget {
  final Widget tab;
  final Widget child;
  final bool dark;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FolderCard({
    super.key,
    required this.tab,
    required this.child,
    this.dark = false,
    this.color,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? (dark ? TPColors.grayscale800 : TPColors.white);
    const r = 22.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(r)),
            ),
            child: tab,
          ),
          // 分頁和卡片之間的平滑內凹轉角
          CustomPaint(size: const Size(r, r), painter: _InverseCorner(bg)),
          const Spacer(),
          if (trailing != null) Padding(padding: const EdgeInsets.only(bottom: 6, right: 4), child: trailing!),
        ]),
        Material(
          color: bg,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(r),
            bottomLeft: Radius.circular(r),
            bottomRight: Radius.circular(r),
          ),
          child: InkWell(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(r),
              bottomLeft: Radius.circular(r),
              bottomRight: Radius.circular(r),
            ),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: dark ? TPColors.white : TPColors.grayscale900),
                child: child,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _InverseCorner extends CustomPainter {
  final Color color;

  _InverseCorner(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, w)
      ..lineTo(w, w)
      // 以 (w, 0) 為圓心的四分之一圓：留下左下角，形成往內凹的平滑轉角
      ..arcToPoint(const Offset(0, 0), radius: Radius.circular(w), clockwise: true);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_InverseCorner old) => old.color != color;
}

/// 分頁上的小膠囊（圖示＋文字）。
class TabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool dark;
  final double fontSize;

  const TabChip(this.label, this.icon, {super.key, this.dark = false, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final fg = dark ? TPColors.white : TPColors.grayscale800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: dark ? TPColors.grayscale500 : TPColors.grayscale300, width: 1.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: fontSize + 3, color: fg),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }
}

/// 浮動膠囊導覽列（參考圖底部）：圓形圖示，選中的是白色圓。
class FloatingPillNav extends StatelessWidget {
  final List<(IconData icon, String label, int badge)> items;
  final int current;
  final ValueChanged<int> onTap;

  const FloatingPillNav({super.key, required this.items, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          heightFactor: 1,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: TPColors.grayscale200.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(40),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 6))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  child: Tooltip(
                    message: items[i].$2,
                    child: RoundIconButton(
                      icon: items[i].$1,
                      tooltip: items[i].$2,
                      badge: items[i].$3,
                      size: 56,
                      background: i == current ? TPColors.white : TPColors.grayscale100.withValues(alpha: 0.6),
                      foreground: i == current ? TPColors.grayscale900 : TPColors.grayscale600,
                      onPressed: () => onTap(i),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 活動類型 → 圖示
IconData categoryIcon(String? code) {
  switch (code) {
    case 'HEALTH':
      return Icons.directions_run;
    case 'LEARNING':
      return Icons.menu_book;
    case 'LEISURE':
      return Icons.palette;
    case 'MEAL':
      return Icons.restaurant;
    case 'SOCIAL':
      return Icons.diversity_3;
    default:
      return Icons.event;
  }
}
