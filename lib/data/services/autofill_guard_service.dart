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

  /// 内置的「整包保护」应用：均为金融/系统类工具，不存在普通密码输入场景。
  ///
  /// 1.2.5：与 Kotlin 侧 `AutofillGuardContract.SENSITIVE_PACKAGES` 保持一致。
  /// 微信、QQ、支付宝等应用不再整包屏蔽，改为按 activity 判断支付类页面
  /// （见 Kotlin 侧 `PAYMENT_ACTIVITY_KEYWORDS`），因此这里的列表只剩这几项。
  static const List<String> knownSensitivePackages = <String>[
    'com.unionpay',
    'com.unionpay.tsmservice',
    'com.chinamworld.main',
    'com.icbc',
    'com.ccb.longjiLife',
    'cmb.pb',
    'com.android.settings',
  ];

  /// 1.2.5：内置的支付类页面关键词（小写匹配），与 Kotlin 侧保持一致，仅用于界面说明。
  static const List<String> paymentActivityKeywords = <String>[
    'pay', 'cashier', 'checkout', 'wallet', 'tenpay', 'unionpay',
    'bank', 'remittance', 'transfer', 'withdraw', 'recharge',
    'balance', 'billing', 'fund', 'finance', 'quickpass',
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