import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/services/app_preferences_service.dart';

/// 首次启动（或免责声明版本变更）时的免责声明确认页（1.2.4）。
///
/// 必须：输入随机验证码 + 勾选「我已阅读并同意」后才能进入应用。
class DisclaimerScreen extends StatefulWidget {
  const DisclaimerScreen({super.key, required this.onAccepted});

  final VoidCallback onAccepted;

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  /// 1.2.5：开源仓库地址（使用须知里「前往审查代码」的跳转目标）。
  static const String _repoUrl = 'https://github.com/007chukong/PineVault1.2.0';

  /// 打开开源仓库，方便用户自行审查代码；拉不起浏览器时把地址复制到剪贴板。
  Future<void> _openRepo(BuildContext context) async {
    bool ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(_repoUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (ok || !context.mounted) return;
    await Clipboard.setData(const ClipboardData(text: _repoUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法打开浏览器，仓库地址已复制到剪贴板')),
    );
  }

  static const Color _mint600 = Color(0xFF3AA277);
  static const Color _mint800 = Color(0xFF22674B);
  static const Color _mint50 = Color(0xFFF3FBF7);
  static const Color _line = Color(0xFFE1EFE8);
  static const Color _body = Color(0xFF17332A);
  static const Color _muted = Color(0xFF6B8579);

  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  late String _expectedCode;
  bool _agreed = false;
  bool _error = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _expectedCode = _generateCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  /// 生成 4 位随机数字验证码（避免首尾多位 0 造成输入体验问题）。
  String _generateCode() {
    final Random random = Random.secure();
    final int value = 1000 + random.nextInt(9000);
    return value.toString();
  }

  bool get _codeMatched => _codeController.text.trim() == _expectedCode;

  Future<void> _submit() async {
    if (!_agreed || !_codeMatched || _busy) {
      setState(() => _error = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = false;
    });
    await AppPreferences.instance.acceptDisclaimer();
    if (!mounted) return;
    widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = _agreed && _codeMatched;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _line),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: _mint50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_moon_rounded,
                            color: _mint600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '使用前请阅读',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _body,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '松匣 PineVault 免责声明',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _mint50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                                                                                    '1. 松匣 PineVault 是一款本地优先的密码管理工具，所有数据均加密保存在您的设备本地，'
                            '开发者不会收集、上传或查看您的任何数据。\n'
                            '2. 请务必自行牢记主密码。主密码不保存于任何服务器，'
                            '一旦遗忘将无法找回，也无法恢复已加密的数据。\n\n'
                            '3. 请自行做好数据备份（导出备份文件或配置 WebDAV 同步）。'
                            '因设备丢失、损坏、误删除、系统清理或同步配置错误造成的数据丢失，'
                            '需由您自行承担。\n'
                            '4. 自动填充、生物识别解锁等功能依赖设备系统能力，'
                            '在部分机型或系统版本上可能不可用，请以实际表现及官方说明为准。\n'
                            '5. 本工具为开源软件，其代码全部由 DeepSeek（人工智能）全程编写完成。'
                            '请您在使用前自行审阅源码与安装包，并自行排查其中是否存在任何可能危及'
                            '您的密码、数据或设备安全的程序或风险。对于您使用本工具（包括但不限于'
                            '本说明所载的全部内容）所产生的一切风险、损失或损害，开发者均不承担任何责任。',


                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.7,
                              color: _body,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // 1.2.5：开源声明附上仓库地址（蓝色高亮，点击可前往审查代码）。
                          InkWell(
                            onTap: () => _openRepo(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: <Widget>[
                                  Icon(Icons.code_rounded, size: 16, color: Color(0xFF1A73E8)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '前往审查代码：$_repoUrl',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1A73E8),
                                        decoration: TextDecoration.underline,
                                        decorationColor: Color(0xFF1A73E8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      /**
                       * 1.2.5 说明：上面一条是「前往审查代码」入口，"
                       * 指向 DisclaimerScreen 里的 _repoUrl；仅该链接可点击。
                       */
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '请在下方输入验证码以确认您已阅读',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _mint800,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _expectedCode,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 6,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          tooltip: '换一个验证码',
                          onPressed: () {
                            setState(() {
                              _expectedCode = _generateCode();
                              _codeController.clear();
                              _error = false;
                            });
                            _codeFocus.requestFocus();
                          },
                          icon: const Icon(Icons.refresh_rounded, color: _mint600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('disclaimer-code-field'),
                      controller: _codeController,
                      focusNode: _codeFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: (_) => setState(() => _error = false),
                      decoration: InputDecoration(
                        hintText: '输入上方 4 位数字',
                        filled: true,
                        fillColor: Colors.white,
                        errorText: _error && !_codeMatched ? '验证码不正确' : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _line),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      key: const Key('disclaimer-agree-checkbox'),
                      value: _agreed,
                      onChanged: (bool? value) =>
                          setState(() => _agreed = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: _mint600,
                      dense: true,
                      title: const Text(
                        '我已阅读并同意上述免责声明',
                        style: TextStyle(fontSize: 13.5, color: _body),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      key: const Key('disclaimer-confirm'),
                      onPressed: ready && !_busy ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _mint600,
                        disabledBackgroundColor: const Color(0xFFC9E5D5),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _busy ? '正在进入…' : '同意并进入松匣',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
