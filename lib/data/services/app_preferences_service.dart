import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 应用级偏好（1.2.4 新增）。
///
/// 与「保险库数据」无关的三块设置集中在这里，持久化为应用支持目录下的
/// `app_preferences.json`：
/// 1. 免责声明的接受状态（按声明版本号记录，文案有实质变化时版本号 +1，
///    老用户会重新看到声明）；
/// 2. 自定义背景（图片路径 / 遮罩浓度 / 模糊半径）；
/// 3. 自动填充排除列表镜像、敏感页面保护、人脸解锁开关。
///
/// 单例 + 内存缓存：所有 UI 通过 [instance] 读写，写入后立即落盘并
/// [notifyListeners]，界面用 ListenableBuilder 监听即可。
class AppPreferences extends ChangeNotifier {
  AppPreferences._();

  static final AppPreferences instance = AppPreferences._();

  static const String _fileName = 'app_preferences.json';

  /// 免责声明版本：文案有实质变化时递增。
  static const String disclaimerVersion = '1.0';

  static const String _kDisclaimer = 'disclaimerVersion';
  static const String _kBackgroundPath = 'backgroundPath';
  static const String _kBackgroundEnabled = 'backgroundEnabled';
  static const String _kBackgroundOverlay = 'backgroundOverlay';
  static const String _kBackgroundBlur = 'backgroundBlur';
  static const String _kExcluded = 'excludedAutofillPackages';
  static const String _kSensitiveGuard = 'sensitivePageGuard';
  static const String _kFaceUnlock = 'faceUnlockEnabled';

  final Map<String, Object?> _data = <String, Object?>{};
  Directory? _supportDirectory;
  bool _loaded = false;

  bool get loaded => _loaded;

  /// 应用私有支持目录（首次用到时惰性创建）。
  Directory? get supportDirectory => _supportDirectory;

  /// 读取磁盘上的偏好；失败时按默认值继续（不阻塞启动）。
  Future<void> load() async {
    if (_loaded) return;
    try {
      _supportDirectory = await getApplicationSupportDirectory();
      final file = File('${_supportDirectory!.path}/$_fileName');
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _data.addAll(decoded.cast<String, Object?>());
        }
      }
    } catch (_) {
      // 忽略：按默认值工作。
    }
    _loaded = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------- 免责声明

  String? get disclaimerAcceptedVersion => _data[_kDisclaimer] as String?;

  /// 当前版本声明是否已经接受过。
  bool get disclaimerAccepted => disclaimerAcceptedVersion == disclaimerVersion;

  Future<void> acceptDisclaimer() async {
    _data[_kDisclaimer] = disclaimerVersion;
    notifyListeners();
    await _persist();
  }

  // ------------------------------------------------------------------ 背景

  String? get backgroundPath => _data[_kBackgroundPath] as String?;

  bool get backgroundEnabled =>
      (_data[_kBackgroundEnabled] as bool? ?? true) && backgroundPath != null;

  /// 遮罩浓度：0 表示原图，值越大越暗（便于前景文字保持对比度）。
  double get backgroundOverlay =>
      (_data[_kBackgroundOverlay] as num?)?.toDouble() ?? 0.35;

  /// 背景模糊半径（sigma）：0 表示不模糊。
  double get backgroundBlur =>
      (_data[_kBackgroundBlur] as num?)?.toDouble() ?? 6;

  Future<void> setBackgroundEnabled(bool value) async {
    _data[_kBackgroundEnabled] = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setBackgroundOverlay(double value) async {
    _data[_kBackgroundOverlay] = value.clamp(0.0, 0.85);
    notifyListeners();
    await _persist();
  }

  Future<void> setBackgroundBlur(double value) async {
    _data[_kBackgroundBlur] = value.clamp(0.0, 30.0);
    notifyListeners();
    await _persist();
  }

  /// 把用户挑选的图片复制进应用私有目录，避免外部路径失效。
  ///
  /// 返回落盘后的绝对路径；失败抛出 [FileSystemException] 由上层提示。
  Future<String> importBackgroundImage(String sourcePath) async {
    final source = File(sourcePath);
    final directory = await _backgroundDirectory();
    final extension = _extensionOf(sourcePath);
    final target = File('${directory.path}/custom_background$extension');
    // 换图时清掉旧的其它扩展名文件，避免残留。
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is File && entity.path != target.path) {
          await entity.delete();
        }
      }
    }
    await source.copy(target.path);
    _data[_kBackgroundPath] = target.path;
    _data[_kBackgroundEnabled] = true;
    notifyListeners();
    await _persist();
    return target.path;
  }

  Future<void> clearBackground() async {
    final path = backgroundPath;
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // 忽略：文件已不存在。
      }
    }
    _data.remove(_kBackgroundPath);
    _data[_kBackgroundEnabled] = false;
    notifyListeners();
    await _persist();
  }

  Future<Directory> _backgroundDirectory() async {
    final support =
        _supportDirectory ??= await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/background');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static String _extensionOf(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '.jpg';
    final extension = name.substring(dot).toLowerCase();
    return extension.length > 6 ? '.jpg' : extension;
  }

  // -------------------------------------------------------------- 自动填充

  /// 排除列表：命中的包名不再展示自动填充按钮、也不提示保存。
  List<String> get excludedAutofillPackages {
    final raw = _data[_kExcluded];
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }

  bool isAutofillExcluded(String packageName) =>
      excludedAutofillPackages.contains(packageName);

  Future<void> setExcludedAutofillPackages(Iterable<String> packages) async {
    final normalized = packages
        .where((entry) => entry.trim().isNotEmpty)
        .map((entry) => entry.trim())
        .toSet()
        .toList()
      ..sort();
    _data[_kExcluded] = normalized;
    notifyListeners();
    await _persist();
  }

  Future<void> setAutofillExcluded(String packageName, bool excluded) async {
    final current = excludedAutofillPackages.toSet();
    if (excluded) {
      current.add(packageName);
    } else {
      current.remove(packageName);
    }
    await setExcludedAutofillPackages(current);
  }

  /// 敏感页面保护：付款密码页、银行类页面一律不弹填充/保存。
  bool get sensitivePageGuard => _data[_kSensitiveGuard] as bool? ?? true;

  Future<void> setSensitivePageGuard(bool value) async {
    _data[_kSensitiveGuard] = value;
    notifyListeners();
    await _persist();
  }

  // ---------------------------------------------------------------- 人脸解锁

  /// 人脸解锁开关：开启后调用系统验证时只接受生物识别（面容/指纹），
  /// 不再回退到设备密码。
  bool get faceUnlockEnabled => _data[_kFaceUnlock] as bool? ?? false;

  Future<void> setFaceUnlockEnabled(bool value) async {
    _data[_kFaceUnlock] = value;
    notifyListeners();
    await _persist();
  }

  // ------------------------------------------------------------------ 落盘

  Future<void> _persist() async {
    try {
      final support =
          _supportDirectory ??= await getApplicationSupportDirectory();
      final file = File('${support.path}/$_fileName');
      if (!await support.exists()) {
        await support.create(recursive: true);
      }
      await file.writeAsString(jsonEncode(_data), flush: true);
    } catch (_) {
      // 写入失败不影响本次会话内的设置生效。
    }
  }
}