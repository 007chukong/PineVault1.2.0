import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_preferences_service.dart';

/// 把「自动填充排除列表 / 敏感页面保护」下发给 Android 原生层。
///
/// 原生的自动填充服务运行在独立进程（没有 Flutter 引擎），因此这里通过
/// MethodChannel 把设置写进 SharedPreferences（`pinevault.autofill_guard`），
/// 原生侧 [PineVaultAutofillService] 在 onFillRequest / onSaveRequest 里自行读取判断。
class AutofillGuardService {
  static const MethodChannel _channel = MethodChannel(
    'app.pinevault.client/autofill_settings',
  );

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 内置的「敏感页面」包名：金融/支付类应用一律不弹填充与保存提示。
  ///
  /// 与 Kotlin 侧 `AutofillGuard.sensitivePackages` 保持一致；此处仅用于在
  /// 界面上告诉用户哪些应用被自动保护。
  static const List<String> knownSensitivePackages = <String>[
    'com.tencent.mm',
    'com.tencent.mobileqq',
    'com.eg.android.AlipayGphone',
    'com.unionpay',
    'com.unionpay.tsmservice',
    'com.chinamworld.main',
    'com.icbc',
    'com.ccb.longjiLife',
    'cmb.pb',
    'com.android.settings',
  ];

  /// 让原生端与 Dart 侧设置保持一致。非 Android 平台或旧版本原生端静默跳过。
  static Future<void> sync() async {
    if (!isSupported) return;
    final prefs = AppPreferences.instance;
    try {
      await _channel.invokeMethod<void>('setAutofillGuard', <String, Object>{
        'excludedPackages': prefs.excludedAutofillPackages,
        'sensitiveGuard': prefs.sensitivePageGuard,
      });
    } on PlatformException {
      // 旧版本原生端尚未实现该方法，忽略。
    } on MissingPluginException {
      // 非 Android 平台。
    }
  }
}