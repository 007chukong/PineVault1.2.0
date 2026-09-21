package app.pinevault.client
import android.content.Context
/**
 * 1.2.3：自动填充守卫（读取侧排除列表 + 敏感页面保护）的本地约定。
 *
 * Dart 侧 [AutofillGuardService.sync] 通过 `app.pinevault.client/autofill_settings`
 * 通道下发 `setAutofillGuard`，由 [MainActivity] 写入这里的 SharedPreferences；
 * [PineVaultAutofillService] 在真正生成填充/保存建议前读取同一份数据做过滤。
 */
internal object AutofillGuardContract {
    /** 守卫配置所在的首选项文件（与填充状态分开保存，互不影响）。 */
    const val PREFERENCES = "pinevault.autofill_guard"

    /** 用户手动排除的应用包名集合（StringSet）。 */
    const val EXCLUDED_PACKAGES = "excludedPackages"

    /** 系统内置的敏感页面保护开关，默认开启。 */
    const val SENSITIVE_GUARD = "sensitiveGuard"

    /**
     * 默认受保护的高敏感应用：聊天、支付、银行、钱包与系统设置。
     * 这些应用即使未出现在用户的排除列表里，也不会被填充。
     */
    val SENSITIVE_PACKAGES: Set<String> = setOf(
        "com.tencent.mm",
        "com.tencent.mobileqq",
        "com.eg.android.AlipayGphone",
        "com.unionpay",
        "com.unionpay.tsmservice",
        "com.chinamworld.main",
        "com.icbc",
        "com.ccb.longjiLife",
        "cmb.pb",
        "com.android.settings",
    )

    /** 读取本地守卫配置，判断 [targetPackage] 是否应当跳过填充 / 保存建议。 */
    fun isGuarded(context: Context, targetPackage: String?): Boolean {
        if (targetPackage.isNullOrBlank()) return false
        val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val excluded = prefs.getStringSet(EXCLUDED_PACKAGES, emptySet()) ?: emptySet()
        if (targetPackage in excluded) return true
        if (prefs.getBoolean(SENSITIVE_GUARD, true) && targetPackage in SENSITIVE_PACKAGES) {
            return true
        }
        return false
    }
}