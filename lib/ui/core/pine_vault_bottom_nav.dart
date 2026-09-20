import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 底部三栏导航（1.2.2）。
///
/// 1.2.1 是四栏（密码库 / 新建 / 同步 / 设置），"新建"本身不是一个页面，
/// 却占了一个常驻 Tab，导致"新建页"里塞满了同步与设置的功能入口。
/// 1.2.2 把"新建"去掉（改为密码库页里的一个动作），底栏回归三栏：
/// 密码库 / 同步 / 设置。
///
/// 1.2.2 视觉：
/// - 底栏底色 navLight #C9E5D5（比页面底 #DCEFE4 深一档），顶部 1px 实色分隔线。
/// - 未选中：navUnselectedLight #47624F，对底栏底实测 5.00:1。
/// - 选中：实心胶囊 mint700 #2C8360 + 白字，白字对胶囊实测 4.64:1。
class PineVaultBottomNav extends StatelessWidget {
  const PineVaultBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PineVaultPalette.navLight,
        border: Border(
          top: BorderSide(color: PineVaultPalette.borderLight),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
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
    // 未选中态：无底 + 深绿字（对底栏底 5.00:1）。
    final foreground =
        selected ? Colors.white : PineVaultPalette.navUnselectedLight;

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