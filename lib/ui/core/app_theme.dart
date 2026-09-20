import 'package:flutter/material.dart';

/// 松匣（PineVault）全新视觉规范 —— 以「浅绿」为核心的浅色系配色。
///
/// 设计原则：
/// 1. 主色为温和的薄荷绿，整体偏浅、偏亮，避免大块深色。
/// 2. 背景使用极浅的绿色白（mint50），卡片用纯白，形成柔和层次。
/// 3. 仅用少量辅助浅色（天蓝/青柠/沙金/珊瑚）做状态区分，不抢主色。
/// 4. 统一圆角与间距，界面观感更「轻」。
///
/// 说明：为避免不同 Flutter 版本间 ThemeData 子主题类型改名
/// （如 AppBarTheme -> AppBarThemeData）带来的编译风险，本文件只设置
/// 稳定字段（colorScheme / useMaterial3 / brightness / scaffoldBackgroundColor），
/// 其余视觉细节由 pine_vault_widgets.dart 中的公共组件承载。
class PineVaultPalette {
  const PineVaultPalette._();

  // ---- 品牌主色阶（薄荷浅绿） ----
  static const Color mint50 = Color(0xFFF3FBF7);
  static const Color mint100 = Color(0xFFE3F6EC);
  static const Color mint200 = Color(0xFFC7EBD9);
  static const Color mint300 = Color(0xFFA5E0C6);
  static const Color mint400 = Color(0xFF7ED1AE);
  static const Color mint500 = Color(0xFF54BC92);
  static const Color mint600 = Color(0xFF3AA277);
  static const Color mint700 = Color(0xFF2C8360);
  static const Color mint800 = Color(0xFF22674B);
  static const Color mint900 = Color(0xFF164834);

  /// 主题种子色。
  static const Color seed = mint500;

  // ---- 辅助浅色 ----
  static const Color sky = Color(0xFF6FAEDC);
  static const Color lime = Color(0xFF93BE62);
  static const Color sand = Color(0xFFD9B45E);
  static const Color coral = Color(0xFFC1503C);

  // ---- 表面与文字 ----
  static const Color surfaceLight = mint50;
  static const Color cardLight = Colors.white;
  static const Color dividerLight = Color(0xFFE1EFE8);
  static const Color textPrimaryLight = Color(0xFF17332A);
  static const Color textSecondaryLight = Color(0xFF6B8579);

  static const Color surfaceDark = Color(0xFF0F1A15);
  static const Color cardDark = Color(0xFF17251F);
  static const Color dividerDark = Color(0xFF26382F);
  static const Color textPrimaryDark = Color(0xFFE7F4ED);
  static const Color textSecondaryDark = Color(0xFF9DB3A8);
}

/// 统一圆角。
class PineVaultRadii {
  const PineVaultRadii._();

  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius tile = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(xl));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}

/// 统一间距。
class PineVaultSpacing {
  const PineVaultSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// 构建松匣浅绿主题。
ThemeData buildPineVaultTheme({
  Brightness brightness = Brightness.light,
  String? fontFamily,
}) {
  final isLight = brightness == Brightness.light;
  final scheme = buildPineVaultColorScheme(brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        isLight ? PineVaultPalette.surfaceLight : PineVaultPalette.surfaceDark,
    fontFamily: fontFamily,
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
  );
}

/// 仅构建配色方案，方便在局部（如自绘组件）单独取用。
ColorScheme buildPineVaultColorScheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;

  final base = ColorScheme.fromSeed(
    seedColor: PineVaultPalette.seed,
    brightness: brightness,
  );

  if (isLight) {
    return base.copyWith(
      primary: PineVaultPalette.mint600,
      onPrimary: Colors.white,
      primaryContainer: PineVaultPalette.mint100,
      onPrimaryContainer: PineVaultPalette.mint900,
      secondary: PineVaultPalette.mint400,
      onSecondary: Colors.white,
      secondaryContainer: PineVaultPalette.mint200,
      onSecondaryContainer: PineVaultPalette.mint900,
      tertiary: PineVaultPalette.sky,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFDCEDF9),
      onTertiaryContainer: const Color(0xFF1B3D57),
      error: PineVaultPalette.coral,
      onError: Colors.white,
      errorContainer: const Color(0xFFFBE4E0),
      onErrorContainer: const Color(0xFF6B2115),
      surface: PineVaultPalette.surfaceLight,
      onSurface: PineVaultPalette.textPrimaryLight,
      onSurfaceVariant: PineVaultPalette.textSecondaryLight,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: PineVaultPalette.mint50,
      surfaceContainer: PineVaultPalette.mint100,
      surfaceContainerHigh: PineVaultPalette.mint200,
      surfaceContainerHighest: PineVaultPalette.mint200,
      outline: const Color(0xFFB9D5C7),
      outlineVariant: PineVaultPalette.dividerLight,
      shadow: const Color(0x14305B49),
      scrim: const Color(0x80224536),
      inverseSurface: PineVaultPalette.mint900,
      onInverseSurface: PineVaultPalette.mint50,
      inversePrimary: PineVaultPalette.mint300,
    );
  }

  return base.copyWith(
    primary: PineVaultPalette.mint300,
    onPrimary: const Color(0xFF08301F),
    primaryContainer: const Color(0xFF1E4B38),
    onPrimaryContainer: PineVaultPalette.mint100,
    secondary: PineVaultPalette.mint400,
    onSecondary: const Color(0xFF06281A),
    secondaryContainer: const Color(0xFF25493A),
    onSecondaryContainer: PineVaultPalette.mint200,
    tertiary: PineVaultPalette.sky,
    onTertiary: const Color(0xFF06283F),
    tertiaryContainer: const Color(0xFF274357),
    onTertiaryContainer: const Color(0xFFD6E9F7),
    error: const Color(0xFFE2907F),
    onError: const Color(0xFF4A1208),
    errorContainer: const Color(0xFF5C2015),
    onErrorContainer: const Color(0xFFFADBD4),
    surface: PineVaultPalette.surfaceDark,
    onSurface: PineVaultPalette.textPrimaryDark,
    onSurfaceVariant: PineVaultPalette.textSecondaryDark,
    surfaceContainerLowest: const Color(0xFF0B1410),
    surfaceContainerLow: PineVaultPalette.cardDark,
    surfaceContainer: const Color(0xFF1C2C25),
    surfaceContainerHigh: const Color(0xFF23362D),
    surfaceContainerHighest: const Color(0xFF2A4036),
    outline: const Color(0xFF3E5A4C),
    outlineVariant: PineVaultPalette.dividerDark,
    shadow: const Color(0x66000000),
    scrim: const Color(0x99000000),
    inverseSurface: PineVaultPalette.mint100,
    onInverseSurface: PineVaultPalette.mint900,
    inversePrimary: PineVaultPalette.mint700,
  );
}
