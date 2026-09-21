import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/pine_vault_widgets.dart';

/// 历史版本页面（1.2.4-1 新增）。
///
/// ============================ 维护说明（下次更新必看） ============================
/// 1. [_entries] 按「从新到旧」排列，第 0 项 = 当前正在发布的版本；
/// 2. 发版流程：先在 `CHANGELOG.md` 顶部加一段 `## <tag>（<日期>）`（tag 必须与 git tag 完全一致，
///    例：`1.2.4-1`、`1.2.4-repair`），然后运行仓库根目录的
///    `python3 tools/gen_version_history.py`：它会按 CHANGELOG 重新生成本文件的
///    `_entries` 列表（同时更新 `pubspec.yaml` 版本号之外的展示文案无需改动）；
/// 3. 每条的 [repoUrl] 指向对应 tag 的 GitHub Release 页面；已撤回的版本（1.2.4）指向
///    全部 Release 列表页，并在日志前加「已撤回」前缀；
/// 4. 页面外观跟随主题：Scaffold / AppBar 均透明，让自定义背景图照常透出
///    （与 1.2.4-repair 的「背景图全局铺满」改动保持一致，不要改回实色背景）；
/// 5. 入口在设置页「关于」分组：`vault_home_screen.dart` 的关于卡片右侧「历史版本 >」，
///    跳转见该文件里的 `_openVersionHistory`。
/// ================================================================================
///
/// 单个版本的展示数据。
class _VersionEntry {
  const _VersionEntry({
    required this.version,
    required this.date,
    required this.log,
    required this.repoUrl,
  });

  /// 版本号（与 git tag 一致）。
  final String version;

  /// 发布日期。
  final String date;

  /// 简短更新日志（取自 CHANGELOG 该版本段的前两条）。
  final String log;

  /// 该版本的 GitHub 仓库（Release）地址。
  final String repoUrl;
}

/// 历史版本数据（由 tools/gen_version_history.py 依据 CHANGELOG.md 生成）。
const List<_VersionEntry> _entries = <_VersionEntry>[
  const _VersionEntry(
    version: '1.2.4-1',
    date: '2026-09-21',
    log: '新增「历史版本」入口：设置页「关于 → 松匣 PineVault」行右侧，进入后按从新到旧列出历史所有版本、发布日期、简短更新日志，以及该版本对应的 GitHub 仓库（Release）地址，点击直接用浏览器打开；新增 `tools/gen_version_history.py`：按 CHANGELOG.md 自动生成历史版本列表，下次更新无需手写',
    repoUrl: 'https://github.com/007chukong/PineVault1.2.0/releases/tag/1.2.4-1',
  ),
  const _VersionEntry(
    version: '1.2.4-repair',
    date: '2026-09-21',
    log: '修复：关于页版本号仍显示 1.2.3（硬编码），现随版本一起更新；修复：自定义背景图只显示在背景设置页；现在背景图像主题皮肤一样铺满整个应用（含 AppBar、各子页面与底栏上层区域），并实时响应设置变化',
    repoUrl: 'https://github.com/007chukong/PineVault1.2.0/releases/tag/1.2.4-repair',
  ),
  const _VersionEntry(
    version: '1.2.4',
    date: '2026-09-21',
    log: '（已撤回，由 1.2.4-repair 取代）新增「自动填充排除列表」：可逐应用排除，并提供「敏感页面保护」开关（默认开启，内置聊天/支付/银行/钱包/系统设置等高敏感应用）。排除或受保护的应用，原生填充服务不再生成填充建议、也不再弹出保存提示；配置通过 `autofill_settings` 通道下发到原生，与填充状态分文件存储；新增「人脸解锁」开关：开启后设备验证仅接受面容/指纹，不再回落到系统密码；「设备验证解锁」弹窗改为居中留白式布局（圆形图标徽章 + 居中说明 + 等宽按钮组）',
    repoUrl: 'https://github.com/007chukong/PineVault1.2.0/releases',
  ),
  const _VersionEntry(
    version: '1.2.3',
    date: '2026-09-21',
    log: '底部导航改为悬浮式磨砂玻璃条：上下左右均留出边距，不再贴死屏幕底边、不再全宽通底；圆角放大到 28，半透明浅绿底叠加背景模糊（BackdropFilter，sigma 18）与淡淡弥散阴影，选中项保留绿色高亮，图标 + 文字布局不变；页面主体内容保持原样，仅调整底栏样式；三个页面（密码库 / 同步 / 设置）的滚动列表与多选操作栏按底栏实际高度预留底部余量，最后一行不再被悬浮底栏遮挡',
    repoUrl: 'https://github.com/007chukong/PineVault1.2.0/releases/tag/1.2.3',
  ),
  const _VersionEntry(
    version: '1.2.2',
    date: '2026-09-20',
    log: '底部导航由四栏收敛为三栏：密码库 / 同步 / 设置。1.2.1 中"新建"并不是一个页面，却占了常驻 Tab，导致"新建页"里堆满了同步与设置的入口；新建入口改为密码库页顶部的常驻主按钮「新建密码」，所有屏幕尺寸（含手机）都能一眼看到；空状态文案同步指向该按钮',
    repoUrl: 'https://github.com/007chukong/PineVault1.2.0/releases/tag/1.2.2',
  ),
  const _VersionEntry(
    version: '1.2.1',
    date: '2026-09-20',
    log: '全新的浅绿视觉体系：重写全局主题，以薄荷浅绿为品牌主色，统一圆角、间距与浅色分层卡片，取消重阴影；新增「通用视觉组件」：卡片、图标徽章、区块标题、设置列表项、分隔线与统计卡，全应用复用同一套视觉语言',
    repoUrl: 'https://github.com/007chukong/PineVault1.2.0/releases/tag/1.2.1',
  ),
  const _VersionEntry(
    version: '1.2.0',
    date: '2026-09-20',
    log: '密码条目新增“应用”字段：可为条目选择适用范围（网站 / 应用 / 应用及网站）；新增“已安装应用”选择器，通过原生通道读取设备上可启动的应用列表（Android）',
    repoUrl: 'https://github.com/007chukong/PineVault1.2.0/releases/tag/1.2.0',
  ),
  const _VersionEntry(
    version: '1.0.9',
    date: '2026-09-15',
    log: 'Android 自动填充新增保存登录信息：保存前可查看并编辑名称、用户名、密码和网站；保存成功后，主 App 重新加载本地密码库，并按现有逻辑触发 WebDAV 同步',
    repoUrl: 'https://github.com/007chukong/PineVault1.2.0/releases/tag/1.0.9',
  ),
];

class VersionHistoryScreen extends StatelessWidget {
  const VersionHistoryScreen({super.key});

  /// 仓库主页（页面底部展示，点击跳转）。
  static const String _repoHome = 'https://github.com/007chukong/PineVault1.2.0';

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('历史版本'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          Text(
            '共 ${_entries.length} 个版本（从新到旧）',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (final _VersionEntry entry in _entries) _versionCard(context, entry),
          _repoCard(context, scheme),
        ],
      ),
    );
  }

  Widget _versionCard(BuildContext context, _VersionEntry entry) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return PineVaultSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      onTap: () => _open(context, entry.repoUrl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                entry.version,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                entry.date,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.log,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(Icons.link_rounded, size: 15, color: scheme.primary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'GitHub 仓库 · ${entry.repoUrl}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.primary),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: scheme.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _repoCard(BuildContext context, ColorScheme scheme) {
    return PineVaultSurface(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      onTap: () => _open(context, _repoHome),
      child: Row(
        children: <Widget>[
          Icon(Icons.code_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('项目仓库主页', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  _repoHome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: scheme.primary),
        ],
      ),
    );
  }

  /// 打开链接；设备拉不起浏览器时把地址复制到剪贴板（1.2.3 酷安入口同款兜底策略）。
  Future<void> _open(BuildContext context, String url) async {
    bool ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开浏览器，链接已复制到剪贴板')),
        );
      }
    }
  }
}
