import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/pine_vault_widgets.dart';
import '../vault/vault_view_model.dart';

/// 1.2.6：存储路径页。
///
/// 只做展示，不改动任何数据：把密码库、备份、同步状态、设备解锁凭据与
/// WebDAV 云端各自的真实路径列出来，方便用户自行备份或排障。
/// 路径规则与各服务保持一一对应：
/// - `VaultFileService`：`${support}/PineVault/vault.pvlt`（及 prev / tmp）
/// - `LocalBackupService`：`${support}/PineVault/backups/<vaultId>`
/// - WebDAV：`Apps/PineVault/vault.pvlt`、`Apps/PineVault/backups/<vaultId>`
class StoragePathsScreen extends StatefulWidget {
  const StoragePathsScreen({super.key});

  @override
  State<StoragePathsScreen> createState() => _StoragePathsScreenState();
}

class _StoragePathsScreenState extends State<StoragePathsScreen> {
  late final Future<String> _supportPath = _loadSupportPath();

  Future<String> _loadSupportPath() async {
    final directory = await getApplicationSupportDirectory();
    return directory.path;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vaultId = context.watch<VaultViewModel>().vaultId;
    return Scaffold(
      appBar: AppBar(title: const Text('存储路径')),
      body: FutureBuilder<String>(
        future: _supportPath,
        builder: (context, snapshot) {
          final support = snapshot.data;
          if (support == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final root = '$support/PineVault';
          final id = vaultId ?? '<密码库 ID>';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PineVaultSurface(
                margin: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '以下均为应用私有目录，普通文件管理器无法直接打开；'
                        '卸载应用会一并删除，需要长期保存请导出备份或使用 WebDAV 同步。'
                        '长按路径可复制。',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const PineVaultSectionLabel('密码库文件'),
              _card(theme, [
                ('密码库目录', root),
                ('当前密码库', '$root/vault.pvlt'),
                ('上一版本副本', '$root/vault.prev.pvlt'),
                ('写入临时文件', '$root/vault.tmp'),
              ]),
              const PineVaultSectionLabel('本机备份与状态'),
              _card(theme, [
                ('本地备份目录', '$root/backups/' + (vaultId == null ? '<vaultId>' : id)),
                ('备份状态', '$root/backup-state-' + (vaultId == null ? '<vaultId>' : id) + '.json'),
                ('自动同步状态', '$root/sync-' + (vaultId == null ? '<vaultId>' : id) + '.json'),
                ('同步历史', '$root/sync-history-' + (vaultId == null ? '<vaultId>' : id) + '.json'),
                ('设备解锁凭据', '$root/device_unlock.json'),
                ('应用设置', '$root/app_preferences.json'),
              ]),
              const PineVaultSectionLabel('WebDAV 云端（坚果云）'),
              _card(theme, [
                ('云端密码库', 'Apps/PineVault/vault.pvlt'),
                (
                  '云端备份目录',
                  'Apps/PineVault/backups/' + (vaultId == null ? '<vaultId>' : id),
                ),
                ('云端目录结构', '应用根目录 → Apps → PineVault'),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _card(ThemeData theme, List<(String, String)> rows) {
    return PineVaultSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      radius: PineVaultRadii.md,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const PineVaultTileDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      rows[index].$1,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: SelectableText(
                      rows[index].$2,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
