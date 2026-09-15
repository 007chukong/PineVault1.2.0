import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/services/native_autofill_service.dart';
import '../domain/models/vault_item.dart';
import '../domain/services/autofill_matcher.dart';
import '../ui/core/vault_brand.dart';
import '../ui/features/unlock/unlock_screen.dart';
import '../ui/features/vault/vault_view_model.dart';

class AutofillApp extends StatelessWidget {
  const AutofillApp({
    super.key,
    required this.vaultViewModel,
    required this.request,
  });

  final VaultViewModel vaultViewModel;
  final NativeAutofillRequest request;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: vaultViewModel,
      child: MaterialApp(
        title: '松匣自动填充',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B52)),
          inputDecorationTheme: _autofillInputTheme(),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF72D7B2),
            brightness: Brightness.dark,
          ),
          inputDecorationTheme: _autofillInputTheme(),
          useMaterial3: true,
        ),
        home: request.isSaveRequest
            ? _AutofillSaveFrame(child: _AutofillRouter(request: request))
            : Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: NativeAutofillAuth.cancel,
                    child: const SizedBox.expand(),
                  ),
                  Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.92,
                      heightFactor: 0.64,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: _AutofillRouter(request: request),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AutofillSaveFrame extends StatelessWidget {
  const _AutofillSaveFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SizedBox(
              width: math.min(constraints.maxWidth - 40, 420),
              height: math.min(constraints.maxHeight - 32, 560),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecorationTheme _autofillInputTheme() => const InputDecorationTheme(
  filled: true,
  isDense: true,
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    borderSide: BorderSide.none,
  ),
);

class _AutofillRouter extends StatelessWidget {
  const _AutofillRouter({required this.request});

  final NativeAutofillRequest request;

  @override
  Widget build(BuildContext context) {
    return Consumer<VaultViewModel>(
      builder: (context, viewModel, _) => switch (viewModel.state) {
        VaultAppState.initializing => const _Message('正在读取密码库…', busy: true),
        VaultAppState.noVault ||
        VaultAppState.creating ||
        VaultAppState.restoring => const _Message('请先打开松匣并创建密码库'),
        VaultAppState.locked || VaultAppState.unlocking => UnlockScreen(
          busy: viewModel.state == VaultAppState.unlocking,
          errorMessage: viewModel.errorMessage,
          onUnlock: viewModel.unlock,
          deviceUnlockEnabled: viewModel.deviceUnlockEnabled,
          onDeviceUnlock: viewModel.unlockWithDevice,
          automaticDeviceUnlock: viewModel.automaticDeviceUnlock,
        ),
        VaultAppState.unlocked ||
        VaultAppState.saving ||
        VaultAppState.syncing =>
          request.isSaveRequest
              ? _AutofillSavePrompt(request: request)
              : _AutofillPicker(request: request),
      },
    );
  }
}

class _AutofillSavePrompt extends StatefulWidget {
  const _AutofillSavePrompt({required this.request});

  final NativeAutofillRequest request;

  @override
  State<_AutofillSavePrompt> createState() => _AutofillSavePromptState();
}

class _AutofillSavePromptState extends State<_AutofillSavePrompt> {
  late final TextEditingController _title;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _url;
  bool _saving = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.request.saveTitle);
    _username = TextEditingController(text: widget.request.saveUsername);
    _password = TextEditingController(text: widget.request.savePassword);
    _url = TextEditingController(text: widget.request.saveUrl);
  }

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('保存登录信息', style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: '取消',
                  onPressed: _saving ? null : NativeAutofillAuth.cancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              children: [
                const Text('请确认以下登录信息是否保存到松匣。'),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _username,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: '用户名'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  enabled: !_saving,
                  obscureText: _obscurePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: '密码',
                    suffixIcon: IconButton(
                      onPressed: _saving
                          ? null
                          : () => setState(
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
                const SizedBox(height: 12),
                TextField(
                  controller: _url,
                  enabled: !_saving,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: '网站'),
                ),
                if (_error case final error?) ...[
                  const SizedBox(height: 12),
                  Text(error, style: TextStyle(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : NativeAutofillAuth.cancel,
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '保存中…' : '保存'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = '名称和密码不能为空');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final viewModel = context.read<VaultViewModel>();
    final saved = await viewModel.saveItem(
      title: _title.text,
      username: _username.text,
      password: _password.text,
      url: _url.text,
      notes: '',
      favorite: false,
    );
    if (!mounted) return;
    if (saved) {
      await NativeAutofillAuth.completeSave();
      return;
    }
    setState(() {
      _saving = false;
      _error = viewModel.errorMessage ?? '保存失败，请重试';
    });
  }
}

class _AutofillPicker extends StatefulWidget {
  const _AutofillPicker({required this.request});

  final NativeAutofillRequest request;

  @override
  State<_AutofillPicker> createState() => _AutofillPickerState();
}

class _AutofillPickerState extends State<_AutofillPicker> {
  final _searchController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<VaultViewModel>();
    final allItems = [
      for (final item in viewModel.items)
        if (item.type == VaultItemType.login && item.password.isNotEmpty) item,
    ];
    final matched = matchingAutofillItems(
      items: allItems,
      domains: widget.request.webDomains,
      packageNames: widget.request.packageNames,
    );
    final query = _searchController.text.trim().toLowerCase();
    final source = query.isEmpty && matched.isNotEmpty ? matched : allItems;
    final items = source
        .where((item) {
          return query.isEmpty ||
              item.title.toLowerCase().contains(query) ||
              item.username.toLowerCase().contains(query) ||
              item.urls.any((url) => url.toLowerCase().contains(query));
        })
        .toList(growable: false);
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Expanded(child: VaultBrand(compact: true)),
                IconButton(
                  tooltip: '取消',
                  onPressed: _submitting ? null : NativeAutofillAuth.cancel,
                  icon: const Icon(Icons.close),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      enabled: !_submitting,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: '搜索名称、用户名或网站',
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                  isDense: true,
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 38,
                    maxHeight: 38,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant
                                .withValues(alpha: 0.55),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        errorText: _error,
                      ),
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(child: Text('没有可填充的登录条目'))
                        : ListView.builder(
                            primary: false,
                            padding: EdgeInsets.zero,
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return ListTile(
                                enabled: !_submitting,
                                leading: CircleAvatar(
                                  child: Text(
                                    item.title.trim().isEmpty
                                        ? '?'
                                        : item.title.trim()[0].toUpperCase(),
                                  ),
                                ),
                                title: Text(item.title),
                                subtitle: Text(
                                  item.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _complete(item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _complete(VaultItem item) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await NativeAutofillAuth.complete(
        label: item.title,
        username: item.username,
        password: item.password,
      );
      if (mounted) context.read<VaultViewModel>().lock();
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '填充失败，请重试';
      });
    }
  }
}

class _Message extends StatelessWidget {
  const _Message(this.message, {this.busy = false});

  final String message;
  final bool busy;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const SizedBox(
          height: 48,
          child: Padding(
            padding: EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: VaultBrand(compact: true),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                ],
                Text(message),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
