part of 'vault_home_screen.dart';

class _ItemEditorDialog extends StatefulWidget {
  const _ItemEditorDialog({required this.viewModel, this.item});

  final VaultViewModel viewModel;
  final VaultItem? item;

  @override
  State<_ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<_ItemEditorDialog> {
  static const _totpService = TotpService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _url;
  late final TextEditingController _notes;
  late final TextEditingController _tags;
  late final TextEditingController _totpInput;
  late final TextEditingController _totpIssuer;
  late final TextEditingController _totpAccount;
  late bool _favorite;
  late String _groupId;
  late bool _totpEnabled;
  late TotpAlgorithm _totpAlgorithm;
  late int _totpDigits;
  late int _totpPeriod;
  late VaultItemScope _scope;
  List<String> _appPackages = const [];
  bool _obscurePassword = true;
  bool _obscureTotpSecret = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _username = TextEditingController(text: item?.username ?? '');
    _password = TextEditingController(text: item?.password ?? '');
    _url = TextEditingController(
      text: item == null || item.urls.isEmpty ? '' : item.urls.first,
    );
    _notes = TextEditingController(text: item?.notes ?? '');
    _tags = TextEditingController(text: item?.tags.join(', ') ?? '');
    final totp = item?.totp;
    _totpInput = TextEditingController(text: totp?.secret ?? '');
    _totpIssuer = TextEditingController(text: totp?.issuer ?? '');
    _totpAccount = TextEditingController(text: totp?.account ?? '');
    _favorite = item?.favorite ?? false;
    _groupId = item?.groupId ?? 'default';
    _totpEnabled = totp != null;
    _totpAlgorithm = totp?.algorithm ?? TotpAlgorithm.sha1;
    _totpDigits = totp?.digits ?? 6;
    _totpPeriod = totp?.period ?? 30;
    _scope = item?.scope ?? VaultItemScope.both;
    _appPackages = List<String>.from(item?.appPackages ?? const []);
  }

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _notes.dispose();
    _tags.dispose();
    _totpInput.dispose();
    _totpIssuer.dispose();
    _totpAccount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    final fieldFill = theme.colorScheme.surfaceContainerLow;

    InputDecoration decoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: fieldFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      );
    }

    Widget algorithmSelector() => DropdownButtonFormField<TotpAlgorithm>(
      initialValue: _totpAlgorithm,
      decoration: decoration(
        '算法',
        Icons.security_outlined,
      ).copyWith(fillColor: theme.colorScheme.surface, prefixIcon: null),
      items: const [
        DropdownMenuItem(value: TotpAlgorithm.sha1, child: Text('SHA1')),
        DropdownMenuItem(value: TotpAlgorithm.sha256, child: Text('SHA256')),
        DropdownMenuItem(value: TotpAlgorithm.sha512, child: Text('SHA512')),
      ],
      onChanged: _busy
          ? null
          : (value) =>
                setState(() => _totpAlgorithm = value ?? TotpAlgorithm.sha1),
    );

    Widget digitsSelector() => DropdownButtonFormField<int>(
      initialValue: _totpDigits,
      decoration: decoration(
        '位数',
        Icons.pin_outlined,
      ).copyWith(fillColor: theme.colorScheme.surface, prefixIcon: null),
      items: const [
        DropdownMenuItem(value: 6, child: Text('6 位')),
        DropdownMenuItem(value: 8, child: Text('8 位')),
      ],
      onChanged: _busy
          ? null
          : (value) => setState(() => _totpDigits = value ?? 6),
    );

    Widget periodSelector() => DropdownButtonFormField<int>(
      initialValue: _totpPeriod,
      decoration: decoration(
        '周期',
        Icons.schedule_outlined,
      ).copyWith(fillColor: theme.colorScheme.surface, prefixIcon: null),
      items: const [
        DropdownMenuItem(value: 30, child: Text('30 秒')),
        DropdownMenuItem(value: 60, child: Text('60 秒')),
      ],
      onChanged: _busy
          ? null
          : (value) => setState(() => _totpPeriod = value ?? 30),
    );

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: compact
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, compact ? 12 : 20, 20, 12),
          child: Column(
            children: [
              if (compact)
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item == null ? '新建密码' : '编辑密码',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (compact)
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          key: const Key('item-title'),
                          controller: _title,
                          autofocus: !compact,
                          decoration: decoration('名称', Icons.label_outline),
                          validator: (value) =>
                              (value ?? '').trim().isEmpty ? '请输入名称' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _username,
                          decoration: decoration('用户名', Icons.person_outline),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('item-password'),
                          controller: _password,
                          obscureText: _obscurePassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: decoration('密码', Icons.key_outlined)
                              .copyWith(
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            children: [
                              SwitchListTile.adaptive(
                                value: _totpEnabled,
                                onChanged: _busy
                                    ? null
                                    : (value) =>
                                          setState(() => _totpEnabled = value),
                                secondary: const Icon(Icons.timer_outlined),
                                title: const Text('动态验证码'),
                                subtitle: Text(
                                  _totpEnabled ? '验证码密钥随密码库加密保存' : '未配置',
                                ),
                              ),
                              if (_totpEnabled) ...[
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    14,
                                  ),
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _totpInput,
                                        obscureText: _obscureTotpSecret,
                                        enableSuggestions: false,
                                        autocorrect: false,
                                        decoration:
                                            decoration(
                                              '密钥或 otpauth:// 地址',
                                              Icons.vpn_key_outlined,
                                            ).copyWith(
                                              fillColor:
                                                  theme.colorScheme.surface,
                                              suffixIcon: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    tooltip: _obscureTotpSecret
                                                        ? '显示密钥'
                                                        : '隐藏密钥',
                                                    onPressed: () => setState(
                                                      () => _obscureTotpSecret =
                                                          !_obscureTotpSecret,
                                                    ),
                                                    icon: Icon(
                                                      _obscureTotpSecret
                                                          ? Icons
                                                                .visibility_outlined
                                                          : Icons
                                                                .visibility_off_outlined,
                                                    ),
                                                  ),
                                                  if (_supportsTotpScanner)
                                                    IconButton(
                                                      tooltip: '扫描二维码',
                                                      onPressed: _scanTotp,
                                                      icon: const Icon(
                                                        Icons.qr_code_scanner,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                        validator: (value) {
                                          if (!_totpEnabled) return null;
                                          try {
                                            _totpService.parse(value ?? '');
                                            return null;
                                          } on FormatException catch (error) {
                                            return error.message.toString();
                                          }
                                        },
                                        onFieldSubmitted: (_) =>
                                            _applyTotpInput(showError: true),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _totpIssuer,
                                        decoration:
                                            decoration(
                                              '服务名称（可选）',
                                              Icons.business_outlined,
                                            ).copyWith(
                                              fillColor:
                                                  theme.colorScheme.surface,
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _totpAccount,
                                        decoration:
                                            decoration(
                                              '验证码账号（可选）',
                                              Icons.person_outline,
                                            ).copyWith(
                                              fillColor:
                                                  theme.colorScheme.surface,
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (compact) ...[
                                        algorithmSelector(),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(child: digitsSelector()),
                                            const SizedBox(width: 8),
                                            Expanded(child: periodSelector()),
                                          ],
                                        ),
                                      ] else
                                        Row(
                                          children: [
                                            Expanded(
                                              child: algorithmSelector(),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(child: digitsSelector()),
                                            const SizedBox(width: 8),
                                            Expanded(child: periodSelector()),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _url,
                          keyboardType: TextInputType.url,
                          decoration: decoration('网站', Icons.link_outlined),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<VaultItemScope>(
                          initialValue: _scope,
                          decoration: decoration(
                            '适用类型',
                            Icons.category_outlined,
                          ),
                          items: [
                            for (final scope in VaultItemScope.values)
                              DropdownMenuItem(
                                value: scope,
                                child: Text(scope.label),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(
                                  () => _scope = value ?? _scope,
                                ),
                        ),
                        const SizedBox(height: 10),
                        _AppSelector(
                          selected: _appPackages,
                          enabled: !_busy,
                          onChanged: (values) =>
                              setState(() => _appPackages = values),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _notes,
                          minLines: 2,
                          maxLines: 4,
                          decoration: decoration('备注', Icons.notes_outlined),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _tags,
                          decoration: decoration(
                            '标签',
                            Icons.sell_outlined,
                          ).copyWith(hintText: '多个标签用逗号分隔'),
                        ),
                        const SizedBox(height: 4),
                        if (widget.viewModel.groups.isNotEmpty) ...[
                          _GroupSelector(
                            groups: widget.viewModel.groups,
                            selectedId: _groupId,
                            enabled: !_busy,
                            onSelected: (value) =>
                                setState(() => _groupId = value),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Icon(
                              Icons.star_outline,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('收藏此条目')),
                            Checkbox.adaptive(
                              value: _favorite,
                              splashRadius: 0,
                              overlayColor: const WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(
                                      () => _favorite = value ?? false,
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (widget.item != null)
                    TextButton(
                      onPressed: _busy ? null : _delete,
                      child: const Text('删除'),
                    ),
                  const Spacer(),
                  if (!compact)
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  if (compact)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                  const SizedBox(width: 10),
                  if (compact)
                    Expanded(
                      child: FilledButton(
                        key: const Key('save-item'),
                        onPressed: _busy ? null : _save,
                        child: Text(_busy ? '保存中…' : '保存'),
                      ),
                    )
                  else
                    FilledButton(
                      key: const Key('save-item'),
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? '保存中…' : '保存'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final saved = await widget.viewModel.saveItem(
      existing: widget.item,
      groupId: _groupId,
      title: _title.text,
      username: _username.text,
      password: _password.text,
      url: _url.text,
      appPackages: _appPackages,
      scope: _scope,
      notes: _notes.text,
      tags: _tags.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(growable: false),
      totp: _totpEnabled ? _totpFromFields() : null,
      favorite: _favorite,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
      _showError();
    }
  }

  Future<void> _delete() async {
    final item = widget.item;
    if (item == null) return;
    setState(() => _busy = true);
    final deleted = await widget.viewModel.deleteItem(item);
    if (!mounted) return;
    if (deleted) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
      _showError();
    }
  }

  void _showError() {
    showAppMessage(context, widget.viewModel.errorMessage ?? '操作失败，请重试');
  }

  bool get _supportsTotpScanner =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  TotpConfig _totpFromFields() {
    final input = _totpInput.text.trim();
    final parsed = _totpService.parse(input);
    final isUri = input.toLowerCase().startsWith('otpauth://');
    return parsed.copyWith(
      algorithm: isUri ? parsed.algorithm : _totpAlgorithm,
      digits: isUri ? parsed.digits : _totpDigits,
      period: isUri ? parsed.period : _totpPeriod,
      issuer: _totpIssuer.text.trim().isEmpty
          ? parsed.issuer
          : _totpIssuer.text.trim(),
      account: _totpAccount.text.trim().isEmpty
          ? parsed.account
          : _totpAccount.text.trim(),
    );
  }

  void _applyTotpInput({required bool showError}) {
    try {
      final config = _totpService.parse(_totpInput.text);
      setState(() {
        _totpInput.text = config.secret;
        _totpAlgorithm = config.algorithm;
        _totpDigits = config.digits;
        _totpPeriod = config.period;
        if (config.issuer.isNotEmpty) _totpIssuer.text = config.issuer;
        if (config.account.isNotEmpty) _totpAccount.text = config.account;
      });
    } on FormatException catch (error) {
      if (showError) showAppMessage(context, error.message.toString());
    }
  }

  Future<void> _scanTotp() async {
    FocusScope.of(context).unfocus();
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _TotpQrScannerScreen()),
    );
    if (value == null || !mounted) return;
    _totpInput.text = value;
    _applyTotpInput(showError: true);
  }
}

class _TotpQrScannerScreen extends StatefulWidget {
  const _TotpQrScannerScreen();

  @override
  State<_TotpQrScannerScreen> createState() => _TotpQrScannerScreenState();
}

class _TotpQrScannerScreenState extends State<_TotpQrScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描动态验证码二维码')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: SafeArea(
              top: false,
              child: Text(
                '将网站提供的动态验证码二维码放入框内',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      _handled = true;
      Navigator.pop(context, value);
      return;
    }
  }
}

/// 编辑器中的「应用」字段：展示已选应用，并可打开系统应用列表进行多选。
class _AppSelector extends StatefulWidget {
  const _AppSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final List<String> selected;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_AppSelector> createState() => _AppSelectorState();
}

class _AppSelectorState extends State<_AppSelector> {
  List<InstalledApp>? _apps;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_apps != null || _loading) return;
    if (!InstalledAppsService.isSupported) return;
    setState(() => _loading = true);
    final apps = await InstalledAppsService.list();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  String _labelFor(String packageName) {
    final apps = _apps;
    if (apps != null) {
      for (final app in apps) {
        if (app.packageName == packageName && app.label.isNotEmpty) {
          return app.label;
        }
      }
    }
    return packageName;
  }

  Future<void> _pick() async {
    final apps = _apps ?? await InstalledAppsService.list();
    if (!mounted) return;
    setState(() => _apps = apps);
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AppPickerSheet(
        apps: apps,
        initialSelected: widget.selected,
      ),
    );
    if (result != null) widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selected;
    final supported = InstalledAppsService.isSupported;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: !widget.enabled || !supported ? null : _pick,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: '应用',
              prefixIcon: const Icon(Icons.apps_outlined, size: 20),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.chevron_right, size: 20),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: Text(
              !supported
                  ? '仅 Android 支持读取应用列表'
                  : selected.isEmpty
                  ? '选择适用的应用'
                  : '已选择 ${selected.length} 个应用',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final packageName in selected)
                InputChip(
                  label: Text(_labelFor(packageName)),
                  tooltip: packageName,
                  onDeleted: widget.enabled
                      ? () => widget.onChanged(
                          selected
                              .where((value) => value != packageName)
                              .toList(growable: false),
                        )
                      : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 系统应用多选列表。
class _AppPickerSheet extends StatefulWidget {
  const _AppPickerSheet({required this.apps, required this.initialSelected});

  final List<InstalledApp> apps;
  final List<String> initialSelected;

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  late final Set<String> _selected = {...widget.initialSelected};
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawQuery = _query.trim();
    final query = rawQuery.toLowerCase();
    final apps = query.isEmpty
        ? widget.apps
        : widget.apps
              .where(
                (app) =>
                    app.label.toLowerCase().contains(query) ||
                    app.packageName.toLowerCase().contains(query),
              )
              .toList(growable: false);
    final manualCandidate =
        rawQuery.isNotEmpty &&
            !widget.apps.any((app) => app.packageName == rawQuery)
        ? rawQuery
        : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('选择应用', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: '搜索应用名称或包名',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            if (manualCandidate != null)
              ListTile(
                dense: true,
                leading: const Icon(Icons.add),
                title: Text(
                  '手动添加：$manualCandidate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => setState(() => _selected.add(manualCandidate)),
              ),
            Flexible(
              child: apps.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('没有找到应用'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        return CheckboxListTile(
                          dense: true,
                          value: _selected.contains(app.packageName),
                          title: Text(
                            app.label.isEmpty ? app.packageName : app.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            app.packageName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              _selected.add(app.packageName);
                            } else {
                              _selected.remove(app.packageName);
                            }
                          }),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _selected.toList(growable: false),
                    ),
                    child: Text('确定 (${_selected.length})'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}