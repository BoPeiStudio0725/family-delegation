import 'package:flutter/material.dart';

/// 色票：依「城市通入門指引・色票與字級規範」。
/// 三個主色是 500 色階（粗框）：Primary #5AB4C5、Secondary #F5BA4B、Grayscale #738995，
/// 其他色階 50 → 950 都和台北通原始碼 lib/util/tp_colors.dart 相同。
abstract final class TPColors {
  // Primary 主色
  static const Color primary50 = Color(0xFFEDF8FA);
  static const Color primary100 = Color(0xFFDBF1F5);
  static const Color primary200 = Color(0xFFB4E2EA);
  static const Color primary300 = Color(0xFF93D4DF);
  static const Color primary400 = Color(0xFF71C5D5);
  static const Color primary500 = Color(0xFF5AB4C5);
  static const Color primary600 = Color(0xFF468D9B);
  static const Color primary700 = Color(0xFF356C77);
  static const Color primary800 = Color(0xFF22474E);
  static const Color primary900 = Color(0xFF112629);

  // Secondary 輔色
  static const Color secondary50 = Color(0xFFFDF8ED);
  static const Color secondary100 = Color(0xFFFCF2DF);
  static const Color secondary200 = Color(0xFFF8E3BC);
  static const Color secondary300 = Color(0xFFF4D69E);
  static const Color secondary500 = Color(0xFFF5BA4B);
  static const Color secondary600 = Color(0xFFE7A43C);
  static const Color secondary700 = Color(0xFFAD7B2B);
  static const Color secondary800 = Color(0xFF74521B);

  // Grayscale 灰階
  static const Color grayscale50 = Color(0xFFF1F3F4);
  static const Color grayscale100 = Color(0xFFE3E7E9);
  static const Color grayscale200 = Color(0xFFCAD1D5);
  static const Color grayscale300 = Color(0xFFADB8BE);
  static const Color grayscale400 = Color(0xFF91A0A8);
  static const Color grayscale500 = Color(0xFF738995);
  static const Color grayscale600 = Color(0xFF5E6D76);
  static const Color grayscale700 = Color(0xFF475259);
  static const Color grayscale800 = Color(0xFF30383D);
  static const Color grayscale900 = Color(0xFF171B1D);
  static const Color grayscale950 = Color(0xFF0B0D0E);

  // 只用在「取消、收回」等危險動作（台北通 TPColors.red）
  static const Color red50 = Color(0xFFFAEEEE);
  static const Color red500 = Color(0xFFD45251);
  static const Color red600 = Color(0xFFC2332F);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}

/// 字級（TPTextStyles）：h1 36・h2 24・title 18・h3 16・body 14・caption 12
abstract final class TPText {
  static const h1 = TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: TPColors.grayscale900, height: 1.25);
  static const h2 = TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: TPColors.grayscale900, height: 1.3);
  static const title = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: TPColors.grayscale900, height: 1.35);
  static const h3 = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: TPColors.grayscale800, height: 1.4);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: TPColors.grayscale700, height: 1.45);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TPColors.grayscale500, height: 1.4);
}

/// 長者大按鈕的顏色：取自色票的深色階（白字對比夠），語音用顏色名稱指路。
abstract final class ElderColors {
  /// 藍綠色：讓家人幫我、同意、確認參加
  static const Color teal = TPColors.primary700;

  /// 黑色：誰在幫我
  static const Color dark = TPColors.grayscale800;

  /// 灰色：家人幫我做過的事（Grayscale 500）
  static const Color slate = TPColors.grayscale600;

  /// 金色：已報名活動清單
  static const Color gold = TPColors.secondary700;

  /// 淺藍色（Primary 500，深色字）：推薦活動
  static const Color sky = TPColors.primary500;

  /// 紅色：收回、取消報名
  static const Color red = TPColors.red600;

  /// 灰色：不同意、換號碼
  static const Color grey = TPColors.grayscale500;
}

/// 長者首頁大按鈕：Primary #5AB4C5 系列的漸層（深色字），已報名活動是喇叭同款黃色。
/// 飽和度調低（約原本的 65%）、透明度 90%，看起來比較柔和；字仍是深色，對比足夠。
abstract final class ElderGradients {
  static Color soft(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withSaturation(hsl.saturation * 0.65).toColor().withValues(alpha: 0.9);
  }

  static final invite = [soft(TPColors.primary400), soft(TPColors.primary500)]; // 讓家人幫我辦事
  static final helpers = [soft(TPColors.primary500), soft(TPColors.primary600)]; // 誰在幫我
  static final history = [soft(TPColors.primary300), soft(TPColors.primary500)]; // 家人幫我做過的事
  static final recommend = [soft(TPColors.primary200), soft(TPColors.primary400)]; // 推薦活動
  static const ink = TPColors.grayscale950; // 這些按鈕上的文字顏色
  static final yellow = soft(TPColors.secondary500); // 已報名活動清單（和右上角喇叭同色系）
}

/// 下拉式選單的展開 / 收合動畫：1.3 秒，平滑地打開。
const kExpandAnimation = AnimationStyle(
  duration: Duration(milliseconds: 1300),
  reverseDuration: Duration(milliseconds: 1300),
  curve: Curves.easeInOutCubic,
  reverseCurve: Curves.easeInOutCubic,
);

/// 圓角：比台北通預設再圓一點，保持平滑。
abstract final class TPRadius {
  static const double card = 24;
  static const double button = 18;
  static const double dialog = 28;
}

/// 和台北通一致的主題（主色 Primary 500、底色 Grayscale 50、白色卡片），
/// 版面參考：大標題、圓形圖示按鈕、膠囊標籤、資料夾分頁卡片。
ThemeData buildTownPassTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: TPColors.primary500).copyWith(
    primary: TPColors.primary500,
    onPrimary: TPColors.white,
    secondary: TPColors.secondary500,
    onSecondary: TPColors.grayscale950,
    tertiary: TPColors.grayscale500,
    error: TPColors.red500,
    surface: TPColors.white,
    onSurface: TPColors.grayscale900,
  );
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(TPRadius.button));
  const font = 'NotoSansTC';

  final base = ThemeData.light().textTheme;
  final textTheme = base
      .copyWith(
        displaySmall: TPText.h1,
        headlineSmall: TPText.h2,
        titleLarge: TPText.title,
        titleMedium: TPText.h3,
        titleSmall: TPText.h3.copyWith(fontSize: 14),
        bodyLarge: TPText.body.copyWith(fontSize: 16),
        bodyMedium: TPText.body,
        bodySmall: TPText.caption.copyWith(fontWeight: FontWeight.w400),
        labelLarge: TPText.h3,
        labelSmall: TPText.caption,
      )
      .apply(fontFamily: font);

  return ThemeData(
    useMaterial3: true,
    fontFamily: font,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: TPColors.grayscale50,
    appBarTheme: const AppBarTheme(
      backgroundColor: TPColors.grayscale50,
      foregroundColor: TPColors.grayscale900,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w600, color: TPColors.grayscale900),
    ),
    // 參考圖：圖示按鈕都是白色圓形
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        backgroundColor: TPColors.white,
        foregroundColor: TPColors.grayscale800,
        shape: const CircleBorder(),
        minimumSize: const Size(44, 44),
      ),
    ),
    cardTheme: CardThemeData(
      color: TPColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TPRadius.card)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TPColors.primary500,
        foregroundColor: TPColors.white,
        disabledBackgroundColor: TPColors.grayscale100,
        disabledForegroundColor: TPColors.grayscale500,
        shape: buttonShape,
        minimumSize: const Size(64, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TPColors.primary600,
        side: const BorderSide(color: TPColors.primary500),
        shape: buttonShape,
        minimumSize: const Size(64, 48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: TPColors.primary600, shape: buttonShape),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: TPColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TPRadius.dialog)),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: TPColors.white,
      selectedColor: TPColors.grayscale900,
      checkmarkColor: TPColors.white,
      side: BorderSide(color: TPColors.grayscale200),
      shape: StadiumBorder(),
    ),
    listTileTheme: const ListTileThemeData(iconColor: TPColors.primary600),
    dividerTheme: const DividerThemeData(color: TPColors.grayscale100),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: TPColors.primary500),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: TPColors.grayscale900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TPRadius.button)),
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: TPColors.red500),
  );
}

/// 狀態小標籤（例如「待長輩確認」）。
class StatusTag extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const StatusTag({super.key, required this.text, required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

/// 報名狀態對應的標籤顏色。
StatusTag bookingStatusTag(String status, String label) {
  switch (status) {
    case 'PENDING_ELDER':
      return StatusTag(text: label, color: TPColors.secondary700, background: TPColors.secondary100);
    case 'CANCELLED':
      return StatusTag(text: label, color: TPColors.grayscale600, background: TPColors.grayscale100);
    default:
      return StatusTag(text: label, color: TPColors.primary700, background: TPColors.primary50);
  }
}
