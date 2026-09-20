import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 一个已安装应用的轻量描述。
class InstalledApp {
  const InstalledApp({
    required this.label,
    required this.packageName,
    this.icon,
  });

  final String label;
  final String packageName;

  /// 应用图标的 PNG 字节流（由原生侧提取）；取不到时为 null。
  final Uint8List? icon;

  @override
  bool operator ==(Object other) =>
      other is InstalledApp && other.packageName == packageName;

  @override
  int get hashCode => packageName.hashCode;
}

/// 通过原生通道读取设备上已安装（且可启动）的应用列表。
class InstalledAppsService {
  static const _channel = MethodChannel('app.pinevault.client/installed_apps');

  /// 进程内缓存：列表随附图标字节流，重复请求一次代价不低。
  static List<InstalledApp>? _cache;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 读取已安装应用列表；[forceRefresh] 为 true 时忽略缓存。
  static Future<List<InstalledApp>> list({bool forceRefresh = false}) async {
    if (!isSupported) return const [];
    if (!forceRefresh) {
      final cached = _cache;
      if (cached != null) return cached;
    }
    try {
      final result = await _channel.invokeListMethod<dynamic>('list');
      if (result == null) return const [];
      final apps = result
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (entry) => InstalledApp(
              label: entry['label'] as String? ?? '',
              packageName: entry['packageName'] as String? ?? '',
              icon: _iconBytes(entry['icon']),
            ),
          )
          .where((app) => app.packageName.isNotEmpty)
          .toList(growable: false);
      _cache = apps;
      return apps;
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// 清空缓存：Dart 侧列表缓存 + 原生侧图标字节流缓存。
  ///
  /// 原生侧另有一份 iconCache，不通知它清理的话，图标仍会从原生缓存返回；
  /// 旧版本原生端没有这个方法时会抛异常，忽略即可。
  static Future<void> clearCache() async {
    _cache = null;
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('clearCache');
    } on Exception {
      // 原生端未实现或调用失败都不影响 Dart 侧缓存已清空，
      // 下次打开选择器仍会重新拉取列表。
      return;
    }
  }

  /// 原生侧返回 ByteArray（Dart 侧即 Uint8List），这里再做一次兜底转换。
  static Uint8List? _iconBytes(Object? raw) {
    if (raw is Uint8List) return raw.isEmpty ? null : raw;
    if (raw is List) {
      final bytes = Uint8List.fromList(
        raw.whereType<int>().toList(growable: false),
      );
      return bytes.isEmpty ? null : bytes;
    }
    return null;
  }
}
