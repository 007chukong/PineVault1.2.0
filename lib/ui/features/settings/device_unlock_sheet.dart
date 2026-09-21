import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_feedback.dart';
import '../vault/vault_view_model.dart';

/// 1.2.3：设备验证解锁的底部弹窗（改为「图1」的居中留白式布局）。
///
/// 视觉口径：
/// - 顶部细拖拽条保持不变，作为底部弹窗的可识别手势提示。
///   关闭 = 解除绑定），下方是居中标题与说明文字，两侧留白更大。
/// - 底部是等宽的「取消 / 确认」按钮组，按钮高度统一、圆角一致。
class DeviceUnlockSheet extends StatefulWidget {
  const DeviceUnlockSheet({super.key, required this.disable});

  final bool disable;

  @override
  State<DeviceUnlockSheet> createState() => _DeviceUnlockSheetState();
}

class _DeviceUnlockSheetState extends State<DeviceUnlockSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _busy = false;


  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      color: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + keyboard),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: '关闭',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Icon(
                      _heroIcon,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.disable ? '关闭设备验证解锁' : '开启设备验证解锁',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (!widget.disable) ...[
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('device-unlock-master-password'),
                    controller: _password,
                    autofocus: true,
                    obscureText: _obscurePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: '当前主密码',
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        onPressed: _busy
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
                    validator: (value) =>
                        (value ?? '').isEmpty ? '请输入当前主密码' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('confirm-device-unlock'),
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: Text(
                          _busy
                              ? '正在处理…'
                              : widget.disable
                              ? '确认关闭'
                              : '验证并开启',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData get _heroIcon {
    if (widget.disable) return Icons.phonelink_erase_rounded;
    return Icons.fingerprint_rounded;
  }

  String get _description {
    if (widget.disable) {
      return '关闭后，本机只能使用主密码解锁。\n其他设备不受影响。';
    }
    return '先确认当前主密码，再通过指纹、面容、系统密码或 Windows Hello '
        '完成本机绑定。主密码不会被保存。';
  }

  Future<void> _submit() async {
    if (_busy ||
        (!widget.disable && !(_formKey.currentState?.validate() ?? false))) {
      return;
    }
    setState(() => _busy = true);
    final viewModel = context.read<VaultViewModel>();
    final succeeded = widget.disable
        ? await viewModel.disableDeviceUnlock()
        : await viewModel.enableDeviceUnlock(_password.text);
    if (!mounted) return;
    if (succeeded) {
      Navigator.pop(context);
      showAppMessage(context, widget.disable ? '设备验证解锁已关闭' : '设备验证解锁已开启');
    } else {
      setState(() => _busy = false);
      showAppMessage(context, viewModel.errorMessage ?? '操作失败，请重试');
    }
  }
}
