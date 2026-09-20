import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 松匣新版通用视觉组件。
///
/// 这些组件刻意保持"轻"：无阴影、浅色块分层、大圆角，
/// 以便全应用共享同一套浅绿语言。
class PineVaultSurface extends StatelessWidget {
  const PineVaultSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color,
    this.radius = PineVaultRadii.lg,
    this.border = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final double radius;
  final bool border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final container = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radius),
        border: border
            // 1.2.2：不再用 alpha 稀释（1.2.1 就是这样糊掉的）。
            // 直接用 outline = #54A17F，对白卡实测 3.10:1。
            ? Border.all(color: scheme.outline)
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) {
      return Padding(padding: margin, child: container);
    }
    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: container),
      ),
    );
  }
}

/// 带浅绿底色的图标徽章。
class PineVaultIconBadge extends StatelessWidget {
  const PineVaultIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = 42,
    this.radius = 14,
  });

  final IconData icon;
  final Color? color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: tint, size: size * 0.52),
    );
  }
}

/// 页面区块标题。
class PineVaultSectionLabel extends StatelessWidget {
  const PineVaultSectionLabel(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 设置类列表项：浅色卡内一行，右侧可带箭头 / 开关 / 自定义控件。
class PineVaultListTile extends StatelessWidget {
  const PineVaultListTile({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.dense = false,
    this.showChevron = false,
  }) : assert(
         icon != null || leading != null,
         'PineVaultListTile 需要 icon 或 leading 至少提供一个',
       );

  final IconData? icon;

  /// 自定义前置图标（1.2.3：酷安 APP 图标这类位图）。提供时优先于 [icon]。
  final Widget? leading;

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool dense;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = Padding(
      padding: EdgeInsets.fromLTRB(14, dense ? 10 : 13, 14, dense ? 10 : 13),
      child: Row(
        children: [
          leading ??
              PineVaultIconBadge(
                icon: icon!,
                color: iconColor,
                size: dense ? 36 : 40,
                radius: dense ? 12 : 13,
              ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          if (showChevron && trailing == null)
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// 卡片内的分隔线。
class PineVaultTileDivider extends StatelessWidget {
  const PineVaultTileDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      endIndent: 14,
      // 1.2.2：去掉 alpha 0.5 的稀释，用实色 #8FCDAF（对白卡 1.82:1）。
      color: scheme.outlineVariant,
    );
  }
}

/// 统计小卡片（用于首页/同步页的概览数字）。
class PineVaultStatTile extends StatelessWidget {
  const PineVaultStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(PineVaultRadii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: tint),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1.2.3：酷安 APP 图标徽章。
///
/// 与 [PineVaultIconBadge] 对齐同一个 40x40 的圆角图标位，区别是直接贴官方
/// APP 图标位图（assets/coolapk_icon.png），而不是 Material 图标字体。
class PineVaultCoolapkBadge extends StatelessWidget {
  const PineVaultCoolapkBadge({super.key, this.size = 40, this.radius = 13});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/coolapk_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        // 资源缺失时不留空白，退回等尺寸空位，布局不塌。
        errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
      ),
    );
  }
}
