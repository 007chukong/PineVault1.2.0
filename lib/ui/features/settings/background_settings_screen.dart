import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../data/services/app_preferences_service.dart';
import '../../core/app_feedback.dart';

/// 自定义背景设置页（1.2.4）。
///
/// 需求：设置里提供「背景设置」，可选择相册中的图片作为应用背景，
/// 并可调节遮罩与模糊程度。
class BackgroundSettingsScreen extends StatefulWidget {
  const BackgroundSettingsScreen({super.key});

  @override
  State<BackgroundSettingsScreen> createState() =>
      _BackgroundSettingsScreenState();
}

class _BackgroundSettingsScreenState extends State<BackgroundSettingsScreen> {
  static const Color _mint50 = Color(0xFFF3FBF7);
  static const Color _mint600 = Color(0xFF3AA277);
  static const Color _line = Color(0xFFE1EFE8);
  static const Color _body = Color(0xFF17332A);
  static const Color _muted = Color(0xFF6B8579);

  final AppPreferences _prefs = AppPreferences.instance;
  bool _busy = false;

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        dialogTitle: '选择背景图片',
        type: FileType.image,
      );
      if (file == null) return;
      final String? source = file.path;
      if (source == null) {
        if (mounted) showAppMessage(context, '无法读取所选图片');
        return;
      }
      await _prefs.importBackgroundImage(source);
      await _prefs.setBackgroundEnabled(true);
      _refresh();
    } catch (error) {
      if (mounted) showAppMessage(context, '设置背景失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    await _prefs.clearBackground();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final String? path = _prefs.backgroundPath;
    final bool hasImage = path != null && path.isNotEmpty && File(path).existsSync();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _body,
        title: const Text(
          '背景设置',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.file(File(path), fit: BoxFit.cover),
                      ColoredBox(
                        color: Colors.white.withValues(
                          alpha: _prefs.backgroundOverlay.clamp(0.0, 1.0),
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.86),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '效果预览',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _body,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.image_outlined, size: 40, color: _muted),
                        SizedBox(height: 8),
                        Text(
                          '还没有自定义背景',
                          style: TextStyle(fontSize: 13, color: _muted),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  key: const Key('background-pick'),
                  onPressed: _busy ? null : _pick,
                  style: FilledButton.styleFrom(
                    backgroundColor: _mint600,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(hasImage ? '更换背景图片' : '从相册选择图片'),
                ),
              ),
              if (hasImage) ...<Widget>[
                const SizedBox(width: 10),
                OutlinedButton(
                  key: const Key('background-clear'),
                  onPressed: _busy ? null : _clear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _body,
                    minimumSize: const Size(96, 46),
                    side: const BorderSide(color: _line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('清除'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SwitchListTile(
                  key: const Key('background-enabled'),
                  value: _prefs.backgroundEnabled,
                  onChanged: hasImage
                      ? (bool value) async {
                          await _prefs.setBackgroundEnabled(value);
                          _refresh();
                        }
                      : null,
                  activeThumbColor: _mint600,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '启用自定义背景',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _body,
                    ),
                  ),
                  subtitle: const Text(
                    '关闭后恢复默认的浅绿底色',
                    style: TextStyle(fontSize: 12.5, color: _muted),
                  ),
                ),
                const Divider(height: 1, color: _line),
                _sliderTile(
                  key: 'background-overlay',
                  title: '遮罩浓度',
                  value: _prefs.backgroundOverlay,
                  min: 0,
                  max: 0.8,
                  divisions: 16,
                  label: '${(_prefs.backgroundOverlay * 100).round()}%',
                  hint: '提高遮罩可让文字更清晰',
                  onChanged: (double value) async {
                    await _prefs.setBackgroundOverlay(value);
                    _refresh();
                  },
                ),
                const Divider(height: 1, color: _line),
                _sliderTile(
                  key: 'background-blur',
                  title: '背景模糊',
                  value: _prefs.backgroundBlur.clamp(0, 20),
                  min: 0,
                  max: 20,
                  divisions: 20,
                  label: _prefs.backgroundBlur.clamp(0, 20).round().toString(),
                  hint: '模糊可以弱化背景、突出内容',
                  onChanged: (double value) async {
                    await _prefs.setBackgroundBlur(value);
                    _refresh();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '背景会铺满整个应用（包括底栏的上层区域）。'
            '底栏在任何情况下都保持半透明磨砂效果。',
            style: TextStyle(fontSize: 12, height: 1.6, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _sliderTile({
    required String key,
    required String title,
    required String hint,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _body,
              ),
            ),
            const Spacer(),
            Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: _muted),
            ),
          ],
        ),
        Slider(
          key: Key(key),
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: _mint600,
          onChanged: onChanged,
        ),
        Text(
          hint,
          style: const TextStyle(fontSize: 11.5, color: _muted),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
