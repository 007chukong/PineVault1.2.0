import 'package:flutter/material.dart';

import '../../../data/services/app_preferences_service.dart';
import '../../../data/services/autofill_guard_service.dart';
import '../../../data/services/installed_apps_service.dart';
import '../../core/app_feedback.dart';

/// 自动填充「排除列表」与「敏感页面保护」设置页（1.2.4）。
///
/// 需求：自动填充功能中提供排除列表，可自行添加不想自动填充的应用；
/// 微信、QQ、支付宝、云闪付等金融软件的付款密码输入页面一律不提供
/// 自动填充与保存密码提示。
class AutofillExcludeScreen extends StatefulWidget {
  const AutofillExcludeScreen({super.key});

  @override
  State<AutofillExcludeScreen> createState() => _AutofillExcludeScreenState();
}

class _AutofillExcludeScreenState extends State<AutofillExcludeScreen> {
  static const Color _mint50 = Color(0xFFF3FBF7);
  static const Color _mint600 = Color(0xFF3AA277);
  static const Color _mint800 = Color(0xFF22674B);
  static const Color _line = Color(0xFFE1EFE8);
  static const Color _body = Color(0xFF17332A);
  static const Color _muted = Color(0xFF6B8579);

  final TextEditingController _search = TextEditingController();
  List<InstalledApp> _apps = const <InstalledApp>[];
  bool _loading = true;
  String? _error;
  String _keyword = '';
  bool _guard = AppPreferences.instance.sensitivePageGuard;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (!InstalledAppsService.isSupported) {
      setState(() {
        _loading = false;
        _error = '当前平台不支持读取已安装应用';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (forceRefresh) {
        await InstalledAppsService.clearCache();
      }
      final List<InstalledApp> apps = await InstalledAppsService.list(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '读取应用列表失败：$error';
      });
    }
  }

  Future<void> _toggle(InstalledApp app, bool excluded) async {
    await AppPreferences.instance.setAutofillExcluded(app.packageName, excluded);
    await AutofillGuardService.sync();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setGuard(bool value) async {
    setState(() => _guard = value);
    await AppPreferences.instance.setSensitivePageGuard(value);
    await AutofillGuardService.sync();
  }

  List<InstalledApp> get _filtered {
    if (_keyword.isEmpty) return _apps;
    final String key = _keyword.toLowerCase();
    return _apps
        .where(
          (InstalledApp app) =>
              app.label.toLowerCase().contains(key) ||
              app.packageName.toLowerCase().contains(key),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<InstalledApp> apps = _filtered;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _body,
        title: const Text(
          '自动填充排除列表',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新应用列表',
            onPressed: _loading ? null : () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          _card(
            child: SwitchListTile(
              value: _guard,
              onChanged: _setGuard,
              activeThumbColor: _mint600,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '敏感页面保护',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _body,
                ),
              ),
              subtitle: const Text(
                '只在支付、收银、钱包、银行卡、转账这类页面跳过自动填充与保存提示；'
                '账号登录等普通密码输入不受影响（1.2.5 起按页面细分）。',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: _muted),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('autofill-exclude-search'),
            controller: _search,
            onChanged: (String value) => setState(() => _keyword = value.trim()),
            decoration: InputDecoration(
              hintText: '搜索应用名称或包名',
              prefixIcon: const Icon(Icons.search_rounded, color: _muted),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _line),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '勾选后，松匣不会在该应用内弹出自填充与保存密码提示。',
            style: TextStyle(fontSize: 12.5, color: _muted),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB3261E)),
              ),
            )
          else if (apps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('没有匹配的应用', style: TextStyle(color: _muted)),
            )
          else
            _card(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < apps.length; i++) ...<Widget>[
                    _row(apps[i]),
                    if (i != apps.length - 1)
                      const Divider(height: 1, color: _line),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 18),
          const Text(
            '系统内置保护（不可关闭）',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _muted,
            ),
          ),
          const SizedBox(height: 8),
          _card(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 0;
                    i < AutofillGuardService.knownSensitivePackages.length;
                    i++) ...<Widget>[
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.lock_outline_rounded,
                      color: _mint800,
                    ),
                    title: Text(
                      AutofillGuardService.knownSensitivePackages[i],
                      style: const TextStyle(fontSize: 13, color: _body),
                    ),
                    subtitle: const Text(
                      '支付类应用：永不自动填充',
                      style: TextStyle(fontSize: 11.5, color: _muted),
                    ),
                  ),
                  if (i != AutofillGuardService.knownSensitivePackages.length - 1)
                    const Divider(height: 1, color: _line),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(InstalledApp app) {
    final bool excluded =
        AppPreferences.instance.isAutofillExcluded(app.packageName);
    return CheckboxListTile(
      key: Key('autofill-exclude-${app.packageName}'),
      value: excluded,
      onChanged: (bool? value) => _toggle(app, value ?? false),
      activeColor: _mint600,
      controlAffinity: ListTileControlAffinity.trailing,
      secondary: SizedBox(
        width: 34,
        height: 34,
        child: app.icon != null
            ? Image.memory(app.icon!, gaplessPlayback: true, fit: BoxFit.contain)
            : const Icon(Icons.android_rounded, color: _muted),
      ),
      title: Text(
        app.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, color: _body),
      ),
      subtitle: Text(
        app.packageName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5, color: _muted),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: child,
    );
  }
}

/// 供设置页复用的提示封装（避免各处 import 重复）。
void autofillExcludeMessage(BuildContext context, String message) {
  showAppMessage(context, message);
}