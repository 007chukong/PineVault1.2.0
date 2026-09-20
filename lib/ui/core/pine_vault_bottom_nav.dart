import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 底部三栏导航（1.2.3：悬浮磨砂玻璃）。
///
/// 历史：
/// - 1.2.1 是四栏（密码库 / 新建 / 同步 / 设置），"新建"本身不是一个页面，
///   却占了一个常驻 Tab，导致"新建页"里塞满了同步与设置的功能入口。
/// - 1.2.2 把"新建"去掉（改为密码库页里的一个动作），底栏回归三栏：
///   密码库 / 同步 / 设置。
/// - 1.2.3 只改底栏容器本身：从"贴死屏幕底边、全屏通底"改为"四边留白、悬浮"，
///   并换成 iOS 新系统风格的磨砂玻璃（acrylic）质感。三栏结构、图标、文字、
///   选中绿色高亮全部保持不变。
///
/// 1.2.3 视觉口径：
/// - 四边留白：左右 16、底部 12 + 系统安全区，悬浮在页面内容之上。
/// - 大圆角：PineVaultRadii.xl（28）。
/// - 磨砂玻璃：BackdropFilter + ImageFilter.blur(sigma = 18) 轻微模糊下层内容，
///   底色 mint50 #F3FBF7 叠 72% 不透明度，1px 白色高光描边。
/// - 弥散阴影：mint900 低透明度、大 blurRadius、小偏移，淡淡的浮起感。
/// - 未选中文字 navUnselectedLight #47624F；选中为实心胶囊 mint700 #2C8360 + 白字。
///
/// 页面里的可滚动列表用 [reservedHeight] 留出底部余量，避免最后一行被底栏遮住。
class PineVaultBottomNav extends StatelessWidget {
  const PineVaultBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  /// 左右留白。
  static const double horizontalMargin = PineVaultSpacing.md;

  /// 距屏幕底边的留白（不含系统安全区）。
  static const double bottomMargin = PineVaultSpacing.sm;

  /// 玻璃卡片的高度（不含留白）。
  static const double barHeight = 58;

  /// 毛玻璃模糊半径：18 是"轻微模糊、还看得清下层轮廓"。
  static const double blurSigma = 18;

  /// 玻璃卡片圆角。
  static const BorderRadius barRadius = BorderRadius.all(
    Radius.circular(PineVaultRadii.xl),
  );

  static const List<_NavEntry> _entries = <_NavEntry>[
    _NavEntry(
      icon: Icons.vpn_key_outlined,
      activeIcon: Icons.vpn_key_rounded,
      label: '密码库',
    ),
    _NavEntry(
      icon: Icons.cloud_sync_outlined,
      activeIcon: Icons.cloud_sync_rounded,
      label: '同步',
    ),
    _NavEntry(
      icon: Icons.tune_outlined,
      activeIcon: Icons.tune_rounded,
      label: '设置',
    ),
  ];

  /// 底栏只有三栏，单独暴露出去给测试断言用。
  static int get entryCount => _entries.length;

  /// 底栏在页面底部实际占用的高度（含底部留白与系统安全区）。
  ///
  /// 注意：SafeArea 会为子节点移除已消费的安全区 padding，所以放在 SafeArea
  /// 里的内容再调用本方法时拿到的就是不含安全区的值，不会重复计算。
  static double reservedHeight(BuildContext context) =>
      bottomMargin +
      barHeight +
      MediaQuery.paddingOf(context).bottom +
      PineVaultSpacing.sm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalMargin,
        0,
        horizontalMargin,
        bottomMargin + MediaQuery.paddingOf(context).bottom,
      ),
      child: DecoratedBox(
        // 阴影画在裁剪之外，才能从玻璃卡片四周弥散出来。
        decoration: const BoxDecoration(
          borderRadius: barRadius,
          boxShadow: [
            BoxShadow(
              color: Color(0x2922674B), // mint900 叠 16%
              blurRadius: 26,
              spreadRadius: -2,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: Color(0x1422674B), // mint900 叠 8%
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: barRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PineVaultPalette.mint50.withValues(alpha: 0.72),
                borderRadius: barRadius,
                border: Border.all(color: Colors.white.withValues(alpha: 0.66)),
              ),
              // 透明 Material 只是给 InkResponse 一个绘制水波纹的层，
              // 位置在模糊层之上，不影响毛玻璃观感。
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  height: barHeight,
                  child: Row(
                    children: [
                      for (var i = 0; i < _entries.length; i++)
                        Expanded(
                          child: _BottomNavItem(
                            entry: _entries[i],
                            selected: i == index,
                            onTap: () => onChanged(i),
                          ),
                        ),
                    ],
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

class _NavEntry {
  const _NavEntry({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final _NavEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 选中态：实心胶囊 + 白字（4.64:1）；
    // 未选中态：无底 + 深绿字（对毛玻璃底 ≥4.5:1）。
    final foreground = selected
        ? Colors.white
        : PineVaultPalette.navUnselectedLight;

    return InkResponse(
      onTap: onTap,
      radius: 46,
      containedInkWell: true,
      highlightShape: BoxShape.rectangle,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? PineVaultPalette.mint700 : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  selected ? entry.activeIcon : entry.icon,
                  key: ValueKey<bool>(selected),
                  size: 23,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.label,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.1,
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}