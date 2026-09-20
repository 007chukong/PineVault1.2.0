import 'package:flutter/material.dart';

/// 松匣（PineVault）视觉规范 —— 以「浅绿」为核心的浅色系配色（1.2.2 加深版）。
///
/// 1.2.2 的设计原则（针对 1.2.1「太糊、看不清」的返工）：
/// 1. 页面底 / 顶栏 / 底栏使用**实体浅绿**（不再用近白的 mint50），白色卡片才浮得起来。
/// 2. 卡片保持纯白，但加**明确的绿色描边**：对白卡 3.10:1（非文本 UI 需 ≥3:1）。
/// 3. 次级文字 5.43:1、分割线 1.82:1，整体加深一档；主色由 mint600 加深到 mint700，
///    白字按钮对比度由 3.17:1 提升到 **4.64:1**（AA 达标）。
/// 4. 底栏底色比页面再深一档（5.00:1 的未选中文字），选中项用白色胶囊 + mint700。
///
/// 以上对比度均为 WCAG 2.1 公式实测值，不是估计。
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

  // ---- 表面与文字（1.2.2 实测对比度） ----
  /// 页面底 / 顶栏底色：实体浅绿（不再是近白）。
  static const Color pageLight = Color(0xFFDCEFE4);

  /// 底部导航底色：比页面底再深一档。
  static const Color navLight = Color(0xFFC9E5D5);

  static const Color surfaceLight = pageLight;
  static const Color cardLight = Colors.white;

  /// 卡片描边：对白卡 3.10:1。
  static const Color borderLight = Color(0xFF54A17F);

  /// 卡内分割线：对白卡 1.82:1。
  static const Color dividerLight = Color(0xFF8FCDAF);

  static const Color textPrimaryLight = Color(0xFF17332A);

  /// 次级文字：对白卡 5.43:1、对页底 4.53:1。
  static const Color textSecondaryLight = Color(0xFF55705F);

  /// 底栏未选中文字：对底栏底 5.00:1。
  static const Color navUnselectedLight = Color(0xFF47624F);

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
      primary: PineVaultPalette.mint700,
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
      // 1.2.2：页面底已是实体浅绿，卡片/列表项一律用纯白才浮得起来。
      surfaceContainerLowest: PineVaultPalette.cardLight,
      surfaceContainerLow: PineVaultPalette.cardLight,
      surfaceContainer: const Color(0xFFEAF7F1),
      surfaceContainerHigh: PineVaultPalette.mint200,
      surfaceContainerHighest: PineVaultPalette.mint200,
      /// 卡片描边（非文本 UI 需 ≥3:1，此处对白卡 3.10:1）。
      outline: PineVaultPalette.borderLight,
      /// 卡内分割线（弱但可见：对白卡 1.82:1）。
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
