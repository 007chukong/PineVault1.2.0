import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/kdbx_transfer_data.dart';
import '../../../data/services/app_preferences_service.dart';
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
import '../settings/autofill_exclude_screen.dart';
import '../settings/change_master_password_dialog.dart';
import '../settings/device_unlock_sheet.dart';
import '../settings/sync_history_screen.dart';
import '../settings/webdav_settings_screen.dart';
import '../backup/backup_screen.dart';
import '../backup/backup_view_model.dart';
import 'vault_view_model.dart';
import '../settings/version_history_screen.dart';

part 'vault_home_kdbx.dart';
part 'vault_home_list.dart';
part 'vault_home_groups.dart';
part 'vault_home_item_actions.dart';
part 'vault_home_item_viewer.dart';
part 'vault_home_item_editor.dart';
part 'vault_home_group_selector.dart';

/// 开发者联系邮箱（设置页「关于」中展示，点击可发信或复制）。
const String _developerEmail = '3153057775@qq.com';

/// 1.2.3：开发者酷安主页（设置页「关于 → 酷安主页」点击直达）。
const String _coolapkProfileUrl = 'https://www.coolapk.com/u/20634810';

class VaultHomeScreen extends StatefulWidget {
  const VaultHomeScreen({super.key});

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen>
    with WidgetsBindingObserver {
  static const _wideLayoutMinWidth = 900.0;

  // 1.2.3：屏幕下方可用于滑动切页的区域，高度取屏幕高度的 32%。
  static const double _bottomSwipeHeightFactor = 0.32;

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
    // 1.2.2：宽屏与否已不影响 AppBar，局部变量不再需要。
    _scheduleAutomaticBackupCheck(viewModel);
    return Scaffold(
      appBar: _buildHomeAppBar(viewModel),
      body: Stack(
        children: [
          Column(
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
                // 1.2.2：只有三个页面。原来第 2 项是"新建"页，
                // 它既不是页面、又堆满了同步与设置的功能，已整体删除。
                children: [
                  _buildVaultTab(viewModel),
                  _buildSyncTab(viewModel),
                  _buildSettingsTab(viewModel),
                ],
              ),
            ),
          ],
        ),
          // 1.2.3：悬浮底栏。不再占用 Scaffold 的 bottomNavigationBar，
          // 而是叠加在页面内容之上，内容从玻璃底下透出来才有毛玻璃观感。
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PineVaultBottomNav(
              index: _tabIndex,
              onChanged: (value) {
                if (value == _tabIndex) return;
                setState(() => _tabIndex = value);
              },
            ),
          ),
          // 1.2.3：屏幕下方任意区域横向滑动即可切换底栏三项。
          // 手势层放在最上面、行为取 translucent：横向拖动归它，
          // 纵向拖动仍归下层列表滚动，点击也照常落到下层控件。
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height:
                MediaQuery.sizeOf(context).height *
                _bottomSwipeHeightFactor,
            child: _BottomSwipeArea(
              onSwipeLeft: () => _shiftTab(1),
              onSwipeRight: () => _shiftTab(-1),
            ),
          ),
        ],
      ),
    );
  }

  // 1.2.3：底栏切换的统一入口（点底栏、屏幕下方滑动都走这里）。
  void _shiftTab(int delta) {
    final next = (_tabIndex + delta)
        .clamp(0, PineVaultBottomNav.entryCount - 1)
        .toInt();
    if (next == _tabIndex) return;
    setState(() => _tabIndex = next);
  }

  // 1.2.2：不再需要 isWideLayout —— 宽屏专属的"新建"按钮已移除，
  // 新建入口改为密码库页内所有屏幕尺寸都可见的固定动作。
  PreferredSizeWidget _buildHomeAppBar(VaultViewModel viewModel) {
    final scheme = Theme.of(context).colorScheme;
    // 1.2.2：三条杠（多选 / 展示密码 / 展示网站 / TOTP / 排序 / 锁定）
    // 只服务于"密码库"列表，因此只在密码库页出现。
    final showQuickMenu = _tabIndex == 0;
    final Widget title = switch (_tabIndex) {
      0 => const VaultBrand(compact: true),
      1 => const Text('同步'),
      _ => const Text('设置'),
    };
    return AppBar(
      backgroundColor: Colors.transparent,
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
        // 1.2.2：AppBar 上的"新建"按钮已移除。
        // 原来它只在宽屏（>=900）出现，手机用户根本看不到新建入口；
        // 现在"新建"作为密码库页内的固定动作，见 vault_home_list.dart 顶部按钮。
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
    IconData? icon,
    Widget? leading,
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
        leading: leading,
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

  /// 设置页「清理缓存」：清掉应用列表 / 图标缓存与已解码图片缓存。
  Future<void> _clearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清理缓存？'),
        content: const Text('将清除已安装应用列表、应用图标等临时缓存，'
            '密码库数据不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await InstalledAppsService.clearCache();
    // 图标是 Image.memory 解码后的位图，缓存一并丢弃，避免仍显示旧图。
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (context.mounted) {
      showAppMessage(context, '缓存已清理');
    }
  }

  /// 设置页「联系开发者」：优先唤起邮件应用，失败则把地址复制到剪贴板。
  Future<void> _contactDeveloper(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: _developerEmail);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      opened = false;
    }
    if (opened || !context.mounted) return;
    await Clipboard.setData(const ClipboardData(text: _developerEmail));
    if (context.mounted) {
      showAppMessage(context, '未找到邮件应用，邮箱已复制：$_developerEmail');
    }
  }

  /// 1.2.3：打开开发者酷安主页；系统没有能处理链接的应用时降级为复制地址。
  Future<void> _openCoolapk(BuildContext context) async {
    final uri = Uri.parse(_coolapkProfileUrl);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      opened = false;
    }
    if (opened || !context.mounted) return;
    await Clipboard.setData(const ClipboardData(text: _coolapkProfileUrl));
    if (context.mounted) {
      showAppMessage(context, '未找到可打开链接的应用，酷安主页地址已复制：$_coolapkProfileUrl');
    }
  }

  Widget _buildSyncTab(VaultViewModel viewModel) {
    final theme = Theme.of(context);
    final progress = viewModel.syncProgress;
    final message = viewModel.syncMessage;
    return ListView(
      // 1.2.3：悬浮底栏盖在内容之上，列表按底栏实际高度留出底部余量。
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        32 + PineVaultBottomNav.reservedHeight(context),
      ),
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
        // 1.2.2：「备份与恢复 / 导入 KDBX / 导出 KDBX / 分组管理」不属于云同步，
        // 已统一收归「设置」页，这里不再重复出现。
      ],
    );
  }

  Widget _buildSettingsTab(VaultViewModel viewModel) {
    final theme = Theme.of(context);
    return ListView(
      // 1.2.3：悬浮底栏盖在内容之上，列表按底栏实际高度留出底部余量。
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        32 + PineVaultBottomNav.reservedHeight(context),
      ),
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
        // 1.2.3：读取侧守卫——排除列表 + 敏感页面保护。
        _navigationTile(
          icon: Icons.app_blocking_outlined,
          title: '自动填充排除列表',
          subtitle: '选择不填充的应用与敏感页面保护',
          onTap: () => _pushScreen(const AutofillExcludeScreen()),
        ),
        // 1.2.2：「WebDAV 设置 / 同步历史」属于云同步，只在「同步」页出现。
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
          icon: Icons.cleaning_services_outlined,
          title: '清理缓存',
          subtitle: '清除应用列表与图标等临时缓存',
          onTap: () => _clearCache(context),
        ),
        const PineVaultSectionLabel('显示与排序'),
        // 1.2.4-1：按反馈移除「背景设置」功能（入口 + 页面 + 背景图渲染）。
        // 页面底色仍由 PineVaultBackgroundLayer 统一兜底，见
        // lib/ui/core/pine_vault_background_layer.dart 的维护说明。
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
        PineVaultSurface(
          margin: const EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.zero,
          radius: PineVaultRadii.md,
          // 1.2.4-1：「关于」卡片右侧新增「历史版本 >」入口，点击进入历史版本页
          // （页面见 lib/ui/features/settings/version_history_screen.dart）。
          child: PineVaultListTile(
            icon: Icons.info_outline_rounded,
            title: '松匣 PineVault',
            subtitle: '版本 1.2.4-1',
            onTap: () => _openVersionHistory(context),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '历史版本',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        _navigationTile(
          icon: Icons.mail_outline_rounded,
          title: '联系开发者',
          subtitle: _developerEmail,
          onTap: () => _contactDeveloper(context),
        ),
        _navigationTile(
          // 1.2.3：前置酷安 APP 图标，点击直达酷安主页。
          title: '酷安主页',
          subtitle: 'www.coolapk.com/u/20634810',
          leading: const PineVaultCoolapkBadge(),
          onTap: () => _openCoolapk(context),
        ),
      ],
    );
  }

  /// 1.2.4-1：打开「历史版本」页面（入口 = 设置页关于卡片右侧的「历史版本」）。
  void _openVersionHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const VersionHistoryScreen(),
      ),
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

/// 1.2.3：屏幕下方的滑动切页热区。
///
/// 只接管横向拖动（向左 → 看下一项，向右 → 回上一项）。纵向拖动与点击
/// 一律放行给下层控件——列表照常滚动、底栏按钮照常可点，所以行为取
/// [HitTestBehavior.translucent]，而不是把整块区域吞掉的 opaque。
class _BottomSwipeArea extends StatelessWidget {
  const _BottomSwipeArea({
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  /// 触发切页所需的最小水平甩动速度（逻辑像素 / 秒）。
  /// 取个偏高的值，避免手滑时的抖动被误判成切页。
  static const double _minVelocity = 120;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity <= -_minVelocity) {
          onSwipeLeft();
        } else if (velocity >= _minVelocity) {
          onSwipeRight();
        }
      },
    );
  }
}