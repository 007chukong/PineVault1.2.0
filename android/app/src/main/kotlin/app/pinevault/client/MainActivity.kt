package app.pinevault.client

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.view.autofill.AutofillManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SETTINGS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            val manager = getSystemService(AutofillManager::class.java)
            when (call.method) {
                "hasPendingSaveRefresh" -> result.success(
                    getSharedPreferences(
                        AutofillContract.STATE_PREFERENCES,
                        MODE_PRIVATE,
                    ).getBoolean(AutofillContract.PENDING_SAVE_REFRESH, false),
                )
                "clearPendingSaveRefresh" -> {
                    getSharedPreferences(
                        AutofillContract.STATE_PREFERENCES,
                        MODE_PRIVATE,
                    ).edit().remove(AutofillContract.PENDING_SAVE_REFRESH).apply()
                    result.success(true)
                }
                "isEnabled" -> result.success(manager?.hasEnabledAutofillServices() == true)
                "isBackgroundAllowed" -> {
                    val powerManager = getSystemService(PowerManager::class.java)
                    result.success(
                        powerManager?.isIgnoringBatteryOptimizations(packageName) == true,
                    )
                }
                "requestBackgroundAccess" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName"),
                        ),
                    )
                    result.success(true)
                }
                "enable" -> {
                    startActivity(
                        Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE).apply {
                            data = Uri.parse("package:$packageName")
                        },
                    )
                    result.success(true)
                }
                "disable" -> {
                    manager?.disableAutofillServices()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APPS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "list" -> {
                    try {
                        val pm = packageManager
                        val apps = pm.getInstalledApplications(0)
                            .mapNotNull { info ->
                                val launchIntent =
                                    pm.getLaunchIntentForPackage(info.packageName)
                                if (launchIntent == null) return@mapNotNull null
                                mapOf<String, Any?>(
                                    "label" to pm.getApplicationLabel(info).toString(),
                                    "packageName" to info.packageName,
                                    "icon" to iconPngBytes(info.packageName),
                                )
                            }
                            .sortedBy { (it["label"] as? String).orEmpty().lowercase() }
                        result.success(apps)
                    } catch (error: Exception) {
                        result.error("installed_apps_error", error.message, null)
                    }
                }
                "clearCache" -> {
                    iconCache.clear()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 把应用图标压成 PNG 字节流（边长最大 ICON_SIZE），供 Dart 侧用 Image.memory 展示。
     * 结果按包名缓存：一次列表请求可能涉及上百个图标，避免每次打开选择器都重新解码。
     */
    private fun iconPngBytes(packageName: String): ByteArray? {
        iconCache[packageName]?.let { return it }
        val bytes = try {
            val drawable = packageManager.getApplicationIcon(packageName)
            val source = if (drawable is BitmapDrawable && drawable.bitmap != null) {
                drawable.bitmap
            } else {
                Bitmap.createBitmap(ICON_SIZE, ICON_SIZE, Bitmap.Config.ARGB_8888).also { square ->
                    val canvas = Canvas(square)
                    drawable.setBounds(0, 0, square.width, square.height)
                    drawable.draw(canvas)
                }
            }
            val longest = maxOf(source.width, source.height)
            val scaled = if (longest > ICON_SIZE) {
                val ratio = ICON_SIZE.toFloat() / longest
                Bitmap.createScaledBitmap(
                    source,
                    (source.width * ratio).toInt().coerceAtLeast(1),
                    (source.height * ratio).toInt().coerceAtLeast(1),
                    true,
                )
            } else {
                source
            }
            ByteArrayOutputStream().use { out ->
                scaled.compress(Bitmap.CompressFormat.PNG, 100, out)
                out.toByteArray()
            }
        } catch (error: Exception) {
            null
        }
        if (bytes != null && bytes.isNotEmpty()) {
            iconCache[packageName] = bytes
        }
        return bytes
    }

    companion object {
        private const val SETTINGS_CHANNEL = "app.pinevault.client/autofill_settings"
        private const val APPS_CHANNEL = "app.pinevault.client/installed_apps"

        /** 图标 PNG 的最大边长（像素）。 */
        private const val ICON_SIZE = 72

        /** 包名 -> 图标 PNG 字节流，进程内复用。 */
        private val iconCache = HashMap<String, ByteArray>()
    }
}