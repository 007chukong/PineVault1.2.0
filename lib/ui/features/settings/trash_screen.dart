import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/trashed_vault_item.dart';
import '../../../domain/models/vault_item.dart';
import '../../core/app_feedback.dart';
import '../../core/app_theme.dart';
import '../../core/pine_vault_widgets.dart';
import '../vault/vault_view_model.dart';

/// 1.2.6：回收站页面。
///
/// 删除条目时不再直接丢弃，而是连同删除时间一起留在密码库内的
/// [TrashedVaultItem] 列表里（随主密码库一起加密保存，云同步同为密文）。
/// 在这里可以找回或彻底删除；超过 [TrashedVaultItem.retentionDays] 天的
/// 条目会在进入本页时自动清理。
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _purgeExpired());
  }

  /// 进入页面时先清掉已过期（超过保留期）的条目。
  Future<void> _purgeExpired() async {
    final viewModel = context.read<VaultViewModel>();
    final now = DateTime.now().toUtc();
    final expiredCount =
        viewModel.trashedItems.where((entry) => entry.isExpiredAt(now)).length;
    if (expiredCount == 0) return;
    final succeeded = await viewModel.purgeExpiredTrashedItems();
    if (succeeded && mounted) {
      showAppMessage(
        context,
        '已自动清理 $expiredCount 条超过 ${TrashedVaultItem.retentionDays} 天的记录',
      );
    }
  }

  Future<void> _restore(TrashedVaultItem entry) async {
    final viewModel = context.read<VaultViewModel>();
    final restored = await viewModel.restoreTrashedItem(entry.item.id);
    if (!mounted) return;
    showAppMessage(
      context,
      restored
          ? '已找回「${entry.item.title}」'
          : (viewModel.errorMessage ?? '找回失败，请重试'),
    );
  }

  Future<void> _purge(TrashedVaultItem entry) async {
    final viewModel = context.read<VaultViewModel>();
    final confirmed = await showPineVaultDeleteConfirmDialog(
      context,
      title: '彻底删除这条记录？',
      message: '「${entry.item.title}」将被永久删除，无法再找回。',
      confirmLabel: '彻底删除',
    );
    if (confirmed != true || !mounted) return;
    final purged = await viewModel.purgeTrashedItem(entry.item.id);
    if (!mounted) return;
    showAppMessage(
      context,
      purged
          ? '已彻底删除「${entry.item.title}」'
          : (viewModel.errorMessage ?? '删除失败，请重试'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<VaultViewModel>();
    final entries = viewModel.trashedItems;
    final busy = viewModel.busy;
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PineVaultSurface(
            margin: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '删除的条目会先放进这里，保留 ${TrashedVaultItem.retentionDays} 天，'
                    '到期后自动清理。回收站内容随密码库一起加密保存。',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: Text('回收站是空的')),
            )
          else
            for (final entry in entries)
              _entryTile(theme, viewModel, entry, busy),
        ],
      ),
    );
  }

  Widget _entryTile(
    ThemeData theme,
    VaultViewModel viewModel,
    TrashedVaultItem entry,
    bool busy,
  ) {
    final item = entry.item;
    final local = entry.deletedAt.toLocal();
    final deletedAt =
        '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
    final remaining = entry.remainingDaysAt(DateTime.now().toUtc());
    final subtitle = <String>[
      if (_groupName(viewModel, item) case final name?) name,
      if (item.username.isNotEmpty) item.username,
      '删除于 $deletedAt · 剩余 $remaining 天',
    ].join(' · ');
    return PineVaultSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      radius: PineVaultRadii.md,
      child: PineVaultListTile(
        icon: Icons.password_rounded,
        title: item.title.isEmpty ? '未命名' : item.title,
        subtitle: subtitle,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('trash-restore-${item.id}'),
              tooltip: '找回',
              icon: const Icon(Icons.restore_rounded),
              onPressed: busy ? null : () => _restore(entry),
            ),
            IconButton(
              key: Key('trash-purge-${item.id}'),
              tooltip: '彻底删除',
              icon: Icon(
                Icons.delete_forever_rounded,
                color: theme.colorScheme.error,
              ),
              onPressed: busy ? null : () => _purge(entry),
            ),
          ],
        ),
      ),
    );
  }

  String? _groupName(VaultViewModel viewModel, VaultItem item) {
    for (final group in viewModel.groups) {
      if (group.id == item.groupId) return group.name;
    }
    return null;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
