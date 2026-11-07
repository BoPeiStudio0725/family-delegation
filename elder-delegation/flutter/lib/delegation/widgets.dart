import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'speech.dart';
import 'tp_layout.dart';
import 'tp_theme.dart';

/// 長者畫面一律包這層：字放大 1.3 倍。
class ElderScale extends StatelessWidget {
  final Widget child;

  const ElderScale({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // 長者畫面整體飽和度再降 10%，看起來比較柔和（字和按鈕的明暗不變）
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_saturation(0.9)),
      child: MediaQuery(data: mq.copyWith(textScaler: const TextScaler.linear(1.3)), child: child),
    );
  }

  /// 飽和度矩陣：s = 1 原色，s = 0 灰階（Rec. 709 亮度權重）。
  static List<double> _saturation(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final i = 1 - s;
    return [
      r * i + s, g * i, b * i, 0, 0, //
      r * i, g * i + s, b * i, 0, 0, //
      r * i, g * i, b * i + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }
}

/// 一個畫面一個主要動作：又高又寬的大按鈕。長按會唸出按鈕在做什麼。
///
/// - 沒有 [caption]：動作按鈕（同意、確認參加…），圖示＋文字置中，和以前一樣。
/// - 有 [caption]：導覽按鈕（首頁的大按鈕），左邊圓形圖示、下面一行說明、右邊箭頭，
///   告訴長輩「按了會到下一頁」。
/// 高度至少 88、顏色、文字都沒變，長輩原本的使用習慣不受影響。
class BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  /// （保留參數相容；長者介面只有右上角喇叭會出聲，長按不唸）
  final String? speakLabel;

  /// 按鈕下方的一行說明（有的話改成導覽樣式）。
  final String? caption;

  /// 文字顏色（淺色按鈕用深色字，預設白色）。
  final Color? textColor;

  /// 漸層底色（有給就用漸層，左上 → 右下）。
  final List<Color>? gradient;

  const BigButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
    this.speakLabel,
    this.caption,
    this.textColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final base = color ?? Theme.of(context).colorScheme.primary;
    final bg = enabled ? base : TPColors.grayscale100;
    final fg = enabled ? (textColor ?? TPColors.white) : TPColors.grayscale500;
    final radius = BorderRadius.circular(22);

    final Widget content = caption == null
        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 40, color: fg),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'NotoSansTC', fontSize: 22, fontWeight: FontWeight.bold, color: fg, height: 1.2)),
            ),
          ])
        : Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: fg.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: fg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(label,
                    style: TextStyle(
                        fontFamily: 'NotoSansTC', fontSize: 22, fontWeight: FontWeight.bold, color: fg, height: 1.2)),
                const SizedBox(height: 2),
                Text(caption!,
                    style: TextStyle(fontFamily: 'NotoSansTC', fontSize: 15, color: fg.withValues(alpha: 0.9))),
              ]),
            ),
            Icon(Icons.chevron_right, size: 36, color: fg),
          ]);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: caption == null ? label : '$label，$caption',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            // 參考設計稿：平面、不加陰影
          ),
          child: Material(
            color: enabled && gradient != null ? Colors.transparent : bg,
            borderRadius: radius,
            child: Ink(
              decoration: enabled && gradient != null
                  ? BoxDecoration(
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient!,
                      ),
                    )
                  : null,
              child: InkWell(
              borderRadius: radius,
              onTap: enabled
                  ? () {
                      HapticFeedback.lightImpact();
                      onPressed!();
                    }
                  : null,
              splashColor: TPColors.white.withValues(alpha: 0.2),
              highlightColor: TPColors.black.withValues(alpha: 0.08),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 88),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: caption == null ? 16 : 14, vertical: 12),
                  // heightFactor: 1 → 高度跟著內容，放在頁面底部也不會撐滿整個畫面
                  child: Center(heightFactor: 1, child: content),
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 長者首頁的提醒框（例如「家人想幫您辦事」「有 2 個活動等您確認」）。
/// 維持黃色（語音說「黃色的框框」），左邊加一條色帶、圓形圖示、右邊箭頭。
class ElderNoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String speakText;

  const ElderNoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.speakText,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: TPColors.secondary100,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: const Border(left: BorderSide(color: TPColors.secondary500, width: 8)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: TPColors.secondary500, shape: BoxShape.circle),
                child: Icon(icon, size: 30, color: TPColors.grayscale950),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: TPColors.grayscale900)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 15, color: TPColors.grayscale700)),
                ]),
              ),
              const Icon(Icons.chevron_right, size: 32, color: TPColors.secondary700),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 區塊標題：左邊一條主色短線（台北通常見的段落樣式）。
class SectionTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;

  const SectionTitle(this.text, {super.key, this.icon, this.color = TPColors.grayscale800});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Row(children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(color: TPColors.primary500, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        if (icon != null) ...[Icon(icon, size: 22, color: color), const SizedBox(width: 6)],
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: color)),
        ),
      ]),
    );
  }
}

/// 沒有資料時的畫面：大圖示＋說明。
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(color: TPColors.primary50, shape: BoxShape.circle),
          child: Icon(icon, size: 48, color: TPColors.primary500),
        ),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: TPColors.grayscale800)),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: TPColors.grayscale600)),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    );
  }
}

/// 「再聽一次」大喇叭：72×72、黃底黑框，固定在每頁右上角。
/// 正在唸的時候圖示變成音波，讓長輩知道「現在有在講話」。
class ListenButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ListenButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ValueListenableBuilder<bool>(
        valueListenable: speaker.speaking,
        builder: (_, talking, __) => Semantics(
          button: true,
          label: '再聽一次',
          child: SizedBox(
            width: 72,
            height: 72,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: TPColors.secondary500,
                foregroundColor: TPColors.grayscale950,
                shape: const CircleBorder(),
                side: const BorderSide(color: TPColors.grayscale950, width: 3),
                padding: EdgeInsets.zero,
              ),
              // 靜音時是喇叭：按一下開始說明；說話時是音波（錄音）圖示：再按一下停止
              // （正在說進入提示時按，代表長輩照著提示要聽說明，直接改唸說明）
              onPressed: () => talking && !speaker.hintPlaying ? speaker.stop() : onPressed(),
              child: Icon(talking ? Icons.graphic_eq : Icons.volume_up, size: 44),
            ),
          ),
        ),
      ),
    );
  }
}

/// 長者頁面共用的 AppBar：加高、大返回鍵、右上角大喇叭。
AppBar elderAppBar(BuildContext context, {required String title, required VoidCallback onListen}) {
  // 只看「這一頁」能不能返回（不要把蓋在上面的對話框算進去）
  final canPop = ModalRoute.of(context)?.canPop ?? false;
  return AppBar(
    toolbarHeight: 88,
    leadingWidth: canPop ? 84 : null,
    automaticallyImplyLeading: false,
    // 參考設計稿：白色圓形返回鍵（長者版加大到 60）
    leading: canPop
        ? Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: RoundIconButton(
                icon: Icons.arrow_back,
                tooltip: '回上一頁',
                size: 60,
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          )
        : null,
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    actions: [ListenButton(onPressed: onListen)],
  );
}

void showMessage(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$error', style: const TextStyle(fontSize: 16))));
}

/// 長者畫面用：顯示訊息，同時唸出來。字比較大，成功是打勾、錯誤是驚嘆號，停留比較久。
void elderMessage(BuildContext context, Object message) {
  final isError = message is Exception || message is Error;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      backgroundColor: isError ? TPColors.red600 : TPColors.grayscale800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle, color: TPColors.white, size: 32),
        const SizedBox(width: 12),
        Expanded(child: Text('$message', style: const TextStyle(fontSize: 19, height: 1.35))),
      ]),
    ));
}

Future<bool> confirmDialog(BuildContext context, String title, String okLabel) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(okLabel)),
      ],
    ),
  );
  return ok ?? false;
}

/// 長者用的確認視窗（雙重確認的第二步）：大圖示、大字、兩個滿版大按鈕上下排，
/// 確定的按鈕用和原本按鈕相同的顏色，長輩一看就知道是同一件事。
Future<bool> elderConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String okLabel,
  required Color okColor,
  required IconData icon,
  String cancelLabel = '先不要',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ElderScale(
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: okColor.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: okColor),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: TPColors.grayscale900)),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: TPColors.grayscale700)),
            ],
            const SizedBox(height: 16),
            BigButton(icon: icon, label: okLabel, color: okColor, onPressed: () => Navigator.pop(ctx, true)),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: TPColors.grayscale700,
                  side: const BorderSide(color: TPColors.grayscale200, width: 2),
                  textStyle: const TextStyle(fontFamily: 'NotoSansTC', fontSize: 20, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(cancelLabel),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
  return ok ?? false;
}

/// 讀取中 / 錯誤 / 有資料 三種狀態的共用寫法。
class AsyncView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  final Widget Function(Object error)? errorBuilder;

  const AsyncView({super.key, required this.future, required this.builder, this.errorBuilder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return errorBuilder?.call(snap.error!) ??
              Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${snap.error}')));
        }
        return builder(snap.data as T);
      },
    );
  }
}

/// 提示：有幾個活動因為和已報名的時段衝突而沒有列出。
class ConflictNote extends StatelessWidget {
  final int count;
  final bool large;

  const ConflictNote(this.count, {super.key, this.large = false});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: TPColors.secondary50, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(Icons.event_busy, size: large ? 26 : 20, color: TPColors.secondary700),
        const SizedBox(width: 8),
        Expanded(
          child: Text('已隱藏 $count 個和已報名活動時間衝突的活動，取消報名後會再出現',
              style: TextStyle(fontSize: large ? 16 : 13, color: TPColors.grayscale700)),
        ),
      ]),
    );
  }
}
