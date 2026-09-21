import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../data/services/app_preferences_service.dart';

/// 全屏自定义背景层（1.2.4）。
///
/// 挂在 `MaterialApp.builder` 上，位于所有页面之下；配合
/// `scaffoldBackgroundColor: Colors.transparent`，实现"主题皮肤"式效果：
/// 背景图会铺满每个页面（含 AppBar、子页面与底栏上层区域）。
///
/// 1. 兜底底色（未启用自定义背景时 = `colorScheme.surface`，随明暗主题变化）；
/// 2. 自定义图片（cover 铺满）；
/// 3. 可选高斯模糊（作用于图片本身）；
/// 4. 可选遮罩（白色半透明，保证文字对比度）；
/// 5. 原有的 `child`（整个应用界面）。
///
/// 监听 [AppPreferences]，关闭背景设置页后立即生效，无需重启。
/// 任何一步失败都静默降级为纯底色，不影响应用可用性。
class PineVaultBackgroundLayer extends StatelessWidget {
  const PineVaultBackgroundLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferences.instance,
      builder: (BuildContext context, Widget? _) {
        final AppPreferences prefs = AppPreferences.instance;
        final String? path = prefs.backgroundPath;
        final bool enabled =
            prefs.backgroundEnabled && path != null && path.isNotEmpty;
        File? file;
        if (enabled) {
          final File candidate = File(path);
          if (candidate.existsSync()) {
            file = candidate;
          }
        }
        final double blur = prefs.backgroundBlur;
        final double overlay = prefs.backgroundOverlay;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: Theme.of(context).colorScheme.surface),
            if (file != null)
              Image.file(
                file,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            if (file != null && blur > 0.1)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            if (file != null && overlay > 0.001)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: overlay.clamp(0.0, 1.0)),
                ),
              ),
            child,
          ],
        );
      },
    );
  }
}
