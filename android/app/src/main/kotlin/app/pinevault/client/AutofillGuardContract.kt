package app.pinevault.client

import android.content.Context

/**
 * 自动填充守卫（读取侧排除列表 + 敏感页面保护）的本地约定。
 *
 * Dart 侧 [AutofillGuardService.sync] 通过 `app.pinevault.client/autofill_settings`
 * 通道下发 `setAutofillGuard`，由 [MainActivity] 写入这里的 SharedPreferences；
 * [PineVaultAutofillService] 在真正生成填充/保存建议前读取同一份数据做过滤。
 *
 * 1.2.5 变化：敏感保护由「整包屏蔽」改为「按页面（activity）细分」——
 * 只有支付 / 收银 / 钱包 / 银行卡 / 转账这类页面才跳过填充与保存，
 * 微信、QQ、支付宝等应用的账号登录与普通密码输入恢复正常填充与保存。
 */
internal object AutofillGuardContract {
    /** 守卫配置所在的首选项文件（与填充状态分开保存，互不影响）。 */
    const val PREFERENCES = "pinevault.autofill_guard"

    /** 用户手动排除的应用包名集合（StringSet），命中的整包跳过。 */
    const val EXCLUDED_PACKAGES = "excludedPackages"

    /** 系统内置的敏感页面保护开关，默认开启。 */
    const val SENSITIVE_GUARD = "sensitiveGuard"

    /**
     * 1.2.5：仍然「整包保护」的应用——全是金融/系统类工具，没有普通密码输入场景。
     * 其余应用改由 [PAYMENT_ACTIVITY_KEYWORDS] 按页面判断。
     */
    val SENSITIVE_PACKAGES: Set<String> = setOf(
        "com.unionpay",
        "com.unionpay.tsmservice",
        "com.chinamworld.main",
        "com.icbc",
        "com.ccb.longjiLife",
        "cmb.pb",
        "com.android.settings",
    )

    /**
     * 1.2.5：支付 / 收银 / 钱包 / 转账类页面的 activity 类名关键词（小写匹配）。
     *
     * 微信、QQ、支付宝等应用的支付相关界面类名通常包含 pay / cashier / wallet /
     * remittance / transfer 等字样，命中后即视为敏感页面；
     * 普通登录页不会命中，因此账号密码照常可填充与保存。
     */
    val PAYMENT_ACTIVITY_KEYWORDS: List<String> = listOf(
        "pay",
        "cashier",
        "checkout",
        "wallet",
        "tenpay",
        "unionpay",
        "bank",
        "remittance",
        "transfer",
        "withdraw",
        "recharge",
        "balance",
        "billing",
        "fund",
        "finance",
        "quickpass",
    )

    /**
     * 判断 [targetPackage] / [activityName] 是否应当跳过填充与保存建议。
     *
     * - 用户在「自动填充排除列表」里勾选的应用：整包跳过；
     * - 内置金融/系统工具类应用：整包跳过；
     * - 支付 / 收银 / 钱包类页面：按 activity 类名跳过（1.2.5 新增）。
     */
    fun isGuarded(
        context: Context,
        targetPackage: String?,
        activityName: String? = null,
    ): Boolean {
        if (targetPackage.isNullOrBlank()) return false
        val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val excluded = prefs.getStringSet(EXCLUDED_PACKAGES, emptySet()) ?: emptySet()
        if (targetPackage in excluded) return true
        if (!prefs.getBoolean(SENSITIVE_GUARD, true)) return false
        if (targetPackage in SENSITIVE_PACKAGES) return true
        return isPaymentActivity(activityName)
    }

    /** 支付 / 收银 / 钱包 / 转账类页面（1.2.5）。 */
    fun isPaymentActivity(activityName: String?): Boolean {
        val name = activityName?.lowercase().orEmpty()
        if (name.isBlank()) return false
        return PAYMENT_ACTIVITY_KEYWORDS.any { name.contains(it) }
    }
}
