import 'dart:math' as math;
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/kdbx_transfer_data.dart';
import '../../../data/services/installed_apps_service.dart';
import '../../../data/services/native_autofill_service.dart';
import '../../../data/services/totp_service.dart';
import '../../../domain/models/totp_config.dart';
import '../../../domain/models/vault_item.dart';
import '../../../domain/models/vault_group.dart';
import '../../core/vault_brand.dart';
import '../../core/app_feedback.dart';
import '../../core/app_theme.dart';
import '../../core/pine_vault_bottom_nav.dart';
import '../../core/pine_vault_widgets.dart';
import '../settings/change_master_password_dialog.dart';
import '../settings/device_unlock_sheet.dart';
import '../settings/sync_history_screen.dart';
import '../settings/webdav_settings_screen.dart';
import '../backup/backup_screen.dart';
import '../backup/backup_view_model.dart';
import 'vault_view_model.dart';

part 'vault_home_kdbx.dart';
part 'vault_home_list.dart';
part 'vault_home_groups.dart';
part 'vault_home_item_actions.dart';
part 'vault_home_item_viewer.dart';
part 'vault_home_item_editor.dart';
part 'vault_home_group_selector.dart';

class VaultHomeScreen extends StatefulWidget {
  const VaultHomeScreen({super.key});

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen>
    with WidgetsBindingObserver {
  static const _wideLayoutMinWidth = 900.0;

  bool _automaticBackupChecked = false;
  bool _automaticBackupCheckScheduled = false;
  String? _activeItemId;
  bool _autofillEnabled = false;
  bool _autofillBackgroundAllowed = false;
  bool _autofillBusy = false;
  bool _pendingSaveRefreshCheck = true;

  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAutofillStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pendingSaveRefreshCheck = true;
      _refreshAutofillStatus();
      _schedulePendingSaveRefresh(context.read<VaultViewModel>());
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<VaultViewModel>();
    _schedulePendingSaveRefresh(viewModel);
    final isWideLayout =
        MediaQuery.sizeOf(context).width >= _wideLayoutMinWidth;
    _scheduleAutomaticBackupCheck(viewModel);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildHomeAppBar(viewModel, isWideLayout),
      body: Column(
        children: [
          if (viewModel.syncProgress case final progress?) ...[
            const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(progress),
            ),
          ],
          if (viewModel.webDavConflict)
            MaterialBanner(
              content: const Text('检测到其他设备使用了不同的 WebDAV 配置，本次同步已保留当前设备配置。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WebDavSettingsScreen(),
                    ),
                  ),
                  child: const Text('检查配置'),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildVaultTab(viewModel),
                _buildCreateTab(viewModel),
                _buildSyncTab(viewModel),
                _buildSettingsTab(viewModel),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: PineVaultBottomNav(
        index: _tabIndex,
        onChanged: (value) {
          if (value == _tabIndex) return;
          setState(() => _tabIndex = value);
        },
      ),
    );
  }

  PreferredSizeWidget _buildHomeAppBar(
    VaultViewModel viewModel,
    bool isWideLayout,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final showQuickMenu = _tabIndex == 0 || _tabIndex == 1;
    final Widget title = switch (_tabIndex) {
      0 => const VaultBrand(compact: true),
      1 => const Text('新建'),
      2 => const Text('同步'),
      _ => const Text('设置'),
    };
    return AppBar(
      backgroundColor: scheme.surface,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      title: title,
      actions: [
        if (viewModel.busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (_tabIndex == 0 && isWideLayout && !viewModel.selectionMode)
          IconButton(
            key: const Key('add-item'),
            tooltip: '新建',
            onPressed: viewModel.busy
                ? null
                : () => _openEditor(context, viewModel),
            icon: const Icon(Icons.add),
          ),
        if (showQuickMenu) _buildQuickMenuButton(viewModel),
      ],
    );
  }

  Widget _buildQuickMenuButton(VaultViewModel viewModel) {
    final scheme = Theme.of(context).colorScheme;
    final timeActive = viewModel.sortOrder == VaultSortOrder.time;
    final nameActive = viewModel.sortOrder == VaultSortOrder.name;
    return PopupMenuButton<_VaultMenuAction>(
      key: const Key('vault-hamburger'),
      tooltip: '快速操作',
      icon: const Icon(Icons.menu_rounded),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 5,
      shape: const RoundedRectangleBorder(borderRadius: PineVaultRadii.lgAll),
      onSelected: _handleMenuAction,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _VaultMenuAction.multiSelect,
          child: const _MenuRow(
            icon: Icons.checklist_rounded,
            label: '多选操作',
          ),
        ),
        PopupMenuItem(
          value: _VaultMenuAction.togglePasswords,
          child: _MenuRow(
            icon: viewModel.showPasswords
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            label: viewModel.showPasswords ? '隐藏密码' : '展示密码',
            active: viewModel.showPasswords,
          ),
        ),
        PopupMenuItem(
          value: _VaultMenuAction.toggleWebsites,
          child: _MenuRow(
            icon: viewModel.showWebsites
                ? Icons.public_off_outlined
                : Icons.public_outlined,
            label: viewModel.showWebsites ? '隐藏网站' : '展示网站',
            active: viewModel.showWebsites,
          ),
        ),
        PopupMenuItem(
          value: _VaultMenuAction.toggleTotp,
          child: _MenuRow(
            icon: Icons.timer_outlined,
            label: viewModel.showTotp ? '隐藏 TOTP' : '显示 TOTP',
            active: viewModel.showTotp,
          ),
        ),
        PopupMenuItem(
          value: _VaultMenuAction.sortByTime,
          child: _MenuRow(
            icon: timeActive && viewModel.sortReversed
                ? Icons.south_outlined
                : Icons.north_outlined,
            label: timeActive
                ? (viewModel.sortReversed ? '按时间倒序' : '按时间正序')
                : '按时间排序',
            active: timeActive,
          ),
        ),
        PopupMenuItem(
          value: _VaultMenuAction.sortByName,
          child: _MenuRow(
            icon: nameActive && viewModel.sortReversed
                ? Icons.south_outlined
                : Icons.north_outlined,
            label: nameActive
                ? (viewModel.sortReversed ? '按名称倒序' : '按名称正序')
                : '按名称排序',
            active: nameActive,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _VaultMenuAction.lock,
          child: const _MenuRow(icon: Icons.lock_outline, label: '锁定'),
        ),
      ],
    );
  }

  Widget _buildVaultTab(VaultViewModel viewModel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideLayoutMinWidth) {
          VaultItem? activeItem;
          for (final item in viewModel.items) {
            if (item.id == _activeItemId) {
              activeItem = item;
              break;
            }
          }
          final listWidth = (constraints.maxWidth * 0.42).clamp(400.0, 480.0);
          return Row(
            children: [
              SizedBox(
                width: listWidth,
                child: _VaultList(
                  viewModel: viewModel,
                  selectedItemId: activeItem?.id,
                  onItemTap: (item) {
                    setState(() => _activeItemId = item.id);
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: activeItem == null
                    ? Center(
                        child: Text(
                          '选择一个条目，或创建新密码',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : _ItemViewer(
                        key: ValueKey(activeItem.id),
                        viewModel: viewModel,
                        item: activeItem,
                        onClose: () {
                          setState(() => _activeItemId = null);
                        },
                        onEdit: () =>
                            _openEditor(context, viewModel, activeItem),
                        onDeleted: () {
                          setState(() => _activeItemId = null);
                        },
                      ),
              ),
            ],
          );
        }
        return _VaultList(viewModel: viewModel);
      },
    );
  }

  Widget _navigationTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback? onTap,
    Color? iconColor,
  }) {
    return PineVaultSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      radius: PineVaultRadii.md,
      onTap: onTap,
      child: PineVaultListTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        iconColor: iconColor,
        showChevron: true,
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return PineVaultSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      radius: PineVaultRadii.md,
      child: PineVaultListTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: Switch.adaptive(value: value, onChanged: onChanged),
      ),
    );
  }

  Future<void> _pushScreen(Widget screen) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Widget _buildCreateTab(VaultViewModel viewModel) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        PineVaultSurface(
          color: theme.colorScheme.primaryContainer,
          onTap: viewModel.busy
              ? null
              : () => _openEditor(context, viewModel),
          child: Row(
            children: [
              const PineVaultIconBadge(
                icon: Icons.add_rounded,
                size: 46,
                radius: 15,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('新建密码条目', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '记录账号、密码、网址与备注',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
        const PineVaultSectionLabel('条目与整理'),
        _navigationTile(
          icon: Icons.checklist_rounded,
          title: '多选操作',
          subtitle: '批量选择、移动或删除条目',
          onTap: viewModel.selectionMode ? null : viewModel.startSelectionMode,
        ),
        _navigationTile(
          icon: Icons.folder_copy_outlined,
          title: '分组管理',
          subtitle: '新建、重命名与调整分组',
          onTap: () => _showGroupManagement(context, viewModel),
        ),
        const PineVaultSectionLabel('数据迁移'),
        _navigationTile(
          icon: Icons.file_download_outlined,
          title: '导入 KDBX',
          subtitle: '从 KeePass 文件导入条目',
          onTap: viewModel.busy ? null : () => _importKdbx(context, viewModel),
        ),
        _navigationTile(
          icon: Icons.file_upload_outlined,
          title: '导出 KDBX',
          subtitle: '导出为 KeePass 兼容文件',
          onTap: viewModel.busy ? null : () => _exportKdbx(context, viewModel),
        ),
        _navigationTile(
          icon: Icons.settings_backup_restore_rounded,
          title: '备份与恢复',
          subtitle: '本地备份管理与恢复',
          onTap: () => _pushScreen(const BackupScreen()),
        ),
        const PineVaultSectionLabel('云同步'),
        _navigationTile(
          icon: Icons.sync_rounded,
          title: '立即同步',
          subtitle: '将当前保险库同步到云端',
          onTap: viewModel.busy ? null : () => _sync(context, viewModel),
        ),
        _navigationTile(
          icon: Icons.cloud_outlined,
          title: 'WebDAV 设置',
          subtitle: '配置服务器地址与账号',
          onTap: () => _pushScreen(const WebDavSettingsScreen()),
        ),
        _navigationTile(
          icon: Icons.history_rounded,
          title: '同步历史',
          subtitle: '查看最近的同步记录',
          onTap: () => _pushScreen(const SyncHistoryScreen()),
        ),
        const PineVaultSectionLabel('安全'),
        _navigationTile(
          icon: Icons.password_rounded,
          title: '修改主密码',
          subtitle: '更新解锁保险库的主密码',
          onTap: () =>
              _handleMenu(context, _VaultMenuAction.changeMasterPassword),
        ),
        _navigationTile(
          icon: Icons.fingerprint_rounded,
          title: '生物识别解锁',
          subtitle: viewModel.deviceUnlockEnabled
              ? '已开启，可用指纹或面容快速解锁'
              : '未开启',
          onTap: () => _handleMenu(context, _VaultMenuAction.deviceUnlock),
        ),
        _navigationTile(
          icon: Icons.auto_mode_rounded,
          title: '自动填充',
          subtitle: _autofillEnabled ? '已开启' : '未开启',
          onTap: () => _handleMenuAction(_VaultMenuAction.autofill),
        ),
        const PineVaultSectionLabel('显示与排序'),
        _switchTile(
          icon: Icons.visibility_outlined,
          title: '展示密码',
          value: viewModel.showPasswords,
          onChanged: (value) => viewModel.setShowPasswords(value),
        ),
        _switchTile(
          icon: Icons.public_outlined,
          title: '展示网站',
          value: viewModel.showWebsites,
          onChanged: (value) => viewModel.setShowWebsites(value),
        ),
        _switchTile(
          icon: Icons.timer_outlined,
          title: '显示 TOTP',
          value: viewModel.showTotp,
          onChanged: (value) => viewModel.setShowTotp(value),
        ),
        _navigationTile(
          icon: Icons.schedule_rounded,
          title: '按时间排序',
          subtitle: viewModel.sortOrder == VaultSortOrder.time
              ? (viewModel.sortReversed ? '当前：倒序' : '当前：正序')
              : null,
          onTap: () => viewModel.setSortOrder(VaultSortOrder.time),
        ),
        _navigationTile(
          icon: Icons.sort_by_alpha_rounded,
          title: '按名称排序',
          subtitle: viewModel.sortOrder == VaultSortOrder.name
              ? (viewModel.sortReversed ? '当前：倒序' : '当前：正序')
              : null,
          onTap: () => viewModel.setSortOrder(VaultSortOrder.name),
        ),
        const PineVaultSectionLabel('会话'),
        _navigationTile(
          icon: Icons.lock_outline_rounded,
          title: '锁定保险库',
          subtitle: '需要重新解锁',
          iconColor: theme.colorScheme.error,
          onTap: viewModel.lock,
        ),
      ],
    );
  }

  Widget _buildSyncTab(VaultViewModel viewModel) {
    final theme = Theme.of(context);
    final progress = viewModel.syncProgress;
    final message = viewModel.syncMessage;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        PineVaultSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const PineVaultIconBadge(
                    icon: Icons.cloud_sync_rounded,
                    size: 46,
                    radius: 15,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WebDAV 云同步', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          viewModel.busy ? '同步进行中…' : '保持多设备密码一致',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: viewModel.busy
                      ? null
                      : () => _sync(context, viewModel),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('立即同步'),
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
                const SizedBox(height: 6),
                Text(progress, style: theme.textTheme.bodySmall),
              ],
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        const PineVaultSectionLabel('同步配置'),
        _navigationTile(
          icon: Icons.cloud_outlined,
          title: 'WebDAV 设置',
          subtitle: '服务器地址、账号与密码',
          onTap: () => _pushScreen(const WebDavSettingsScreen()),
        ),
        _navigationTile(
          icon: Icons.history_rounded,
          title: '同步历史',
          subtitle: '查看最近同步记录',
          onTap: () => _pushScreen(const SyncHistoryScreen()),
        ),
        const PineVaultSectionLabel('本地数据'),
        _navigationTile(
          icon: Icons.settings_backup_restore_rounded,
          title: '备份与恢复',
          subtitle: '本地备份管理与恢复',
          onTap: () => _pushScreen(const BackupScreen()),
        ),
        _navigationTile(
          icon: Icons.file_download_outlined,
          title: '导入 KDBX',
          subtitle: '从 KeePass 文件导入条目',
          onTap: viewModel.busy ? null : () => _importKdbx(context, viewModel),
        ),
        _navigationTile(
          icon: Icons.file_upload_outlined,
          title: '导出 KDBX',
          subtitle: '导出为 KeePass 兼容文件',
          onTap: viewModel.busy ? null : () => _exportKdbx(context, viewModel),
        ),
      ],
    );
  }

  Widget _buildSettingsTab(VaultViewModel viewModel) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        const PineVaultSectionLabel('解锁与安全'),
        _switchTile(
          icon: Icons.fingerprint_rounded,
          title: '生物识别解锁',
          subtitle: viewModel.deviceUnlockSupported
              ? (viewModel.deviceUnlockEnabled ? '已开启' : '未开启')
              : '当前设备不支持',
          value: viewModel.deviceUnlockEnabled,
          onChanged: (viewModel.deviceUnlockSupported &&
                  !viewModel.deviceUnlockBusy)
              ? (value) =>
                  _handleMenu(context, _VaultMenuAction.deviceUnlock)
              : null,
        ),
        _navigationTile(
          icon: Icons.password_rounded,
          title: '修改主密码',
          subtitle: '更新解锁保险库的主密码',
          onTap: () =>
              _handleMenu(context, _VaultMenuAction.changeMasterPassword),
        ),
        _switchTile(
          icon: Icons.auto_mode_rounded,
          title: '自动填充',
          subtitle: _autofillEnabled
              ? (_autofillBackgroundAllowed ? '已开启（含后台）' : '已开启')
              : '未开启',
          value: _autofillEnabled,
          onChanged: _autofillBusy ? null : (value) => _toggleAutofill(),
        ),
        const PineVaultSectionLabel('云同步'),
        _navigationTile(
          icon: Icons.cloud_outlined,
          title: 'WebDAV 设置',
          subtitle: '服务器地址、账号与密码',
          onTap: () => _pushScreen(const WebDavSettingsScreen()),
        ),
        _navigationTile(
          icon: Icons.history_rounded,
          title: '同步历史',
          subtitle: '查看最近同步记录',
          onTap: () => _pushScreen(const SyncHistoryScreen()),
        ),
        const PineVaultSectionLabel('数据'),
        _navigationTile(
          icon: Icons.settings_backup_restore_rounded,
          title: '备份与恢复',
          subtitle: '本地备份管理与恢复',
          onTap: () => _pushScreen(const BackupScreen()),
        ),
        _navigationTile(
          icon: Icons.folder_copy_outlined,
          title: '分组管理',
          subtitle: '新建、重命名与调整分组',
          onTap: () => _showGroupManagement(context, viewModel),
        ),
        _navigationTile(
          icon: Icons.file_download_outlined,
          title: '导入 KDBX',
          onTap: viewModel.busy ? null : () => _importKdbx(context, viewModel),
        ),
        _navigationTile(
          icon: Icons.file_upload_outlined,
          title: '导出 KDBX',
          onTap: viewModel.busy ? null : () => _exportKdbx(context, viewModel),
        ),
        const PineVaultSectionLabel('显示与排序'),
        _switchTile(
          icon: Icons.visibility_outlined,
          title: '展示密码',
          value: viewModel.showPasswords,
          onChanged: (value) => viewModel.setShowPasswords(value),
        ),
        _switchTile(
          icon: Icons.public_outlined,
          title: '展示网站',
          value: viewModel.showWebsites,
          onChanged: (value) => viewModel.setShowWebsites(value),
        ),
        _switchTile(
          icon: Icons.timer_outlined,
          title: '显示 TOTP',
          value: viewModel.showTotp,
          onChanged: (value) => viewModel.setShowTotp(value),
        ),
        const PineVaultSectionLabel('会话'),
        _navigationTile(
          icon: Icons.lock_outline_rounded,
          title: '锁定保险库',
          subtitle: '需要重新解锁',
          iconColor: theme.colorScheme.error,
          onTap: viewModel.lock,
        ),
        const PineVaultSectionLabel('关于'),
        const PineVaultSurface(
          margin: EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.zero,
          radius: PineVaultRadii.md,
          child: PineVaultListTile(
            icon: Icons.info_outline_rounded,
            title: '松匣 PineVault',
            subtitle: '版本 1.2.1',
          ),
        ),
      ],
    );
  }

  void _schedulePendingSaveRefresh(VaultViewModel viewModel) {
    if (!_pendingSaveRefreshCheck ||
        viewModel.state != VaultAppState.unlocked) {
      return;
    }
    _pendingSaveRefreshCheck = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !await NativeAutofillService.hasPendingSaveRefresh()) {
        return;
      }
      final refreshed = await viewModel.reloadAfterAutofillSave();
      if (refreshed) {
        await NativeAutofillService.clearPendingSaveRefresh();
      }
    });
  }

  void _scheduleAutomaticBackupCheck(VaultViewModel viewModel) {
    if (_automaticBackupChecked ||
        _automaticBackupCheckScheduled ||
        viewModel.state != VaultAppState.unlocked) {
      return;
    }
    _automaticBackupCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final backupViewModel = context.read<BackupViewModel>();
      final checked = await backupViewModel.checkAutomatic();
      if (!mounted) return;
      setState(() {
        _automaticBackupCheckScheduled = false;
        _automaticBackupChecked = checked;
      });
      final message = backupViewModel.message;
      if (checked && message != null) {
        showAppMessage(context, message);
      }
    });
  }

  Future<void> _handleMenuAction(_VaultMenuAction action) async {
    if (action == _VaultMenuAction.autofill) {
      await _toggleAutofill();
      return;
    }
    if (!mounted) return;
    await _handleMenu(context, action);
  }

  Future<void> _refreshAutofillStatus() async {
    if (!NativeAutofillService.isSupported) return;
    try {
      final status = await Future.wait([
        NativeAutofillService.isEnabled(),
        NativeAutofillService.isBackgroundAllowed(),
      ]);
      if (mounted) {
        setState(() {
          _autofillEnabled = status[0];
          _autofillBackgroundAllowed = status[1];
        });
      }
    } on PlatformException {
      if (mounted) {
        setState(() {
          _autofillEnabled = false;
          _autofillBackgroundAllowed = false;
        });
      }
    }
  }

  Future<void> _toggleAutofill() async {
    if (_autofillBusy) return;
    setState(() => _autofillBusy = true);
    try {
      if (_autofillEnabled && !_autofillBackgroundAllowed) {
        await NativeAutofillService.requestBackgroundAccess();
      } else if (_autofillEnabled) {
        await NativeAutofillService.disable();
      } else {
        await NativeAutofillService.enable();
      }
      await _refreshAutofillStatus();
    } on PlatformException {
      if (mounted) showAppMessage(context, '无法打开自动填充设置');
    } finally {
      if (mounted) setState(() => _autofillBusy = false);
    }
  }
}

enum _VaultMenuAction {
  sync,
  webDav,
  history,
  backup,
  groupManagement,
  changeMasterPassword,
  deviceUnlock,
  autofill,
  importKdbx,
  exportKdbx,
  multiSelect,
  lock,
  togglePasswords,
  toggleWebsites,
  toggleTotp,
  sortByTime,
  sortByName,
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : null;
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }
}

Future<void> _handleMenu(BuildContext context, _VaultMenuAction action) async {
  final viewModel = context.read<VaultViewModel>();
  switch (action) {
    case _VaultMenuAction.sync:
      await _sync(context, viewModel);
    case _VaultMenuAction.webDav:
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const WebDavSettingsScreen()),
      );
    case _VaultMenuAction.history:
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const SyncHistoryScreen()),
      );
    case _VaultMenuAction.backup:
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const BackupScreen()),
      );
    case _VaultMenuAction.groupManagement:
      await _showGroupManagement(context, viewModel);
    case _VaultMenuAction.changeMasterPassword:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ChangeMasterPasswordDialog(),
      );
    case _VaultMenuAction.deviceUnlock:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            DeviceUnlockSheet(disable: viewModel.deviceUnlockEnabled),
      );
    case _VaultMenuAction.autofill:
      break;
    case _VaultMenuAction.importKdbx:
      await _importKdbx(context, viewModel);
    case _VaultMenuAction.exportKdbx:
      await _exportKdbx(context, viewModel);
    case _VaultMenuAction.multiSelect:
      viewModel.startSelectionMode();
    case _VaultMenuAction.lock:
      viewModel.lock();
    case _VaultMenuAction.togglePasswords:
      viewModel.setShowPasswords(!viewModel.showPasswords);
    case _VaultMenuAction.toggleWebsites:
      viewModel.setShowWebsites(!viewModel.showWebsites);
    case _VaultMenuAction.toggleTotp:
      viewModel.setShowTotp(!viewModel.showTotp);
    case _VaultMenuAction.sortByTime:
      viewModel.setSortOrder(VaultSortOrder.time);
    case _VaultMenuAction.sortByName:
      viewModel.setSortOrder(VaultSortOrder.name);
  }
}