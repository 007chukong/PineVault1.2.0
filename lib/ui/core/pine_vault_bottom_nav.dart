import 'package:flutter/material.dart';

/// iOS 风格底部四栏导航。
///
/// 特点：无阴影、顶部细分隔线、选中态使用品牌浅绿、图标与文字紧凑排布。
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
      icon: Icons.add_circle_outline,
      activeIcon: Icons.add_circle_rounded,
      label: '新建',
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
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
    final scheme = Theme.of(context).colorScheme;
    final color = selected
        ? scheme.primary
        : scheme.onSurfaceVariant.withValues(alpha: 0.85);
    return InkResponse(
      onTap: onTap,
      radius: 46,
      containedInkWell: true,
      highlightShape: BoxShape.rectangle,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              selected ? entry.activeIcon : entry.icon,
              key: ValueKey<bool>(selected),
              size: 24,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            entry.label,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
