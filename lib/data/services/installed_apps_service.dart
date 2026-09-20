import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 一个已安装应用的轻量描述。
class InstalledApp {
  const InstalledApp({required this.label, required this.packageName});

  final String label;
  final String packageName;

  @override
  bool operator ==(Object other) =>
      other is InstalledApp && other.packageName == packageName;

  @override
  int get hashCode => packageName.hashCode;
}

/// 通过原生通道读取设备上已安装（且可启动）的应用列表。
class InstalledAppsService {
  static const _channel = MethodChannel('app.pinevault.client/installed_apps');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<List<InstalledApp>> list() async {
    if (!isSupported) return const [];
    try {
      final result = await _channel.invokeListMethod<dynamic>('list');
      if (result == null) return const [];
      return result
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (entry) => InstalledApp(
              label: entry['label'] as String? ?? '',
              packageName: entry['packageName'] as String? ?? '',
            ),
          )
          .where((app) => app.packageName.isNotEmpty)
          .toList(growable: false);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }
}
