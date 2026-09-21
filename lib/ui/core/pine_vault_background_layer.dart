import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../data/services/app_preferences_service.dart';

/// 全屏自定义背景层（1.2.4）。
///
/// 挂在 `MaterialApp.builder` 上，位于所有页面之下：
/// 1. 自定义图片（cover 铺满）；
/// 2. 可选高斯模糊（作用于图片本身）；
/// 3. 可选遮罩（白色半透明，保证文字对比度）；
/// 4. 原有的 `child`（整个应用界面）。
///
/// 任何一步失败都静默降级为透明，不影响应用可用性。
class PineVaultBackgroundLayer extends StatelessWidget {
  const PineVaultBackgroundLayer({super.key, required this.child});

  final Widget child;

  /// 页面兜底底色，与 `PineVaultPalette.mint50` 保持一致。
  static const Color _fallback = Color(0xFFF3FBF7);

  @override
  Widget build(BuildContext context) {
    final AppPreferences prefs = AppPreferences.instance;
    final String? path = prefs.backgroundPath;
    final bool enabled =
        prefs.backgroundEnabled && path != null && path.isNotEmpty;
    if (!enabled) {
      return child;
    }
    final File file = File(path);
    if (!file.existsSync()) {
      return child;
    }
    final double blur = prefs.backgroundBlur;
    final double overlay = prefs.backgroundOverlay;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: _fallback),
        if (blur > 0.1)
          // 模糊图片本身，避免用 BackdropFilter 每帧重算整屏。
          Image.file(
            file,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const ColoredBox(color: _fallback),
          )
        else
          Image.file(
            file,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const ColoredBox(color: _fallback),
          ),
        if (blur > 0.1)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
        if (overlay > 0.001)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.white.withValues(alpha: overlay.clamp(0.0, 1.0)),
            ),
          ),
        child,
      ],
    );
  }
}
