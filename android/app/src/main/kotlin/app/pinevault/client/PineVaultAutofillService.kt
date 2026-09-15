package app.pinevault.client

import android.app.PendingIntent
import android.app.assist.AssistStructure
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveInfo
import android.service.autofill.SaveRequest
import android.text.InputType
import android.util.Log
import android.view.View
import android.view.autofill.AutofillId
import android.widget.RemoteViews

class PineVaultAutofillService : AutofillService() {
    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback,
    ) {
        if (cancellationSignal.isCanceled) return
        val structure = request.fillContexts.lastOrNull()?.structure
        if (structure == null) {
            callback.onSuccess(null)
            return
        }
        val fields = AutofillStructureParser.parse(structure)
        Log.i(
            TAG,
            "request=${request.id} candidates=${fields.candidateIds.size} " +
                "usernames=${fields.usernameIds.size} passwords=${fields.passwordIds.size}",
        )
        if (fields.passwordIds.isEmpty()) {
            Log.i(TAG, "request=${request.id} ignored: no password field")
            callback.onSuccess(null)
            return
        }

        val authIntent = Intent(this, AutofillAuthActivity::class.java).apply {
            putParcelableArrayListExtra(
                AutofillContract.EXTRA_USERNAME_IDS,
                ArrayList(fields.usernameIds),
            )
            putParcelableArrayListExtra(
                AutofillContract.EXTRA_PASSWORD_IDS,
                ArrayList(fields.passwordIds),
            )
            putStringArrayListExtra(
                AutofillContract.EXTRA_PACKAGE_NAMES,
                arrayListOf(structure.activityComponent.packageName),
            )
            putStringArrayListExtra(
                AutofillContract.EXTRA_WEB_DOMAINS,
                ArrayList(fields.webDomains),
            )
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            request.id,
            authIntent,
            PendingIntent.FLAG_CANCEL_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                },
        )
        val menuPresentation = lockedPresentation()
        val dataset = Dataset.Builder(menuPresentation).apply {
            fields.candidateIds.forEach { id ->
                setValue(id, null, menuPresentation)
            }
            setAuthentication(pendingIntent.intentSender)
            setId("pinevault_locked")
        }.build()
        @Suppress("DEPRECATION")
        val response = FillResponse.Builder()
            .addDataset(dataset)
            .setSaveInfo(
                SaveInfo.Builder(
                    SaveInfo.SAVE_DATA_TYPE_USERNAME or SaveInfo.SAVE_DATA_TYPE_PASSWORD,
                    fields.passwordIds.toTypedArray(),
                ).apply {
                    if (fields.usernameIds.isNotEmpty()) {
                        setOptionalIds(fields.usernameIds.toTypedArray())
                    }
                }.build(),
            )
            .build()
        callback.onSuccess(response)
        Log.i(TAG, "request=${request.id} returned authenticated response")
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        val structure = request.fillContexts.lastOrNull()?.structure
        if (structure == null) {
            callback.onSuccess()
            return
        }
        val fields = AutofillStructureParser.parse(structure)
        val password = fields.passwordIds.asSequence()
            .mapNotNull(fields.values::get)
            .firstOrNull { it.isNotBlank() }
            .orEmpty()
        if (password.isBlank()) {
            callback.onSuccess()
            return
        }
        val username = fields.usernameIds.asSequence()
            .mapNotNull(fields.values::get)
            .firstOrNull { it.isNotBlank() }
            .orEmpty()
        val domain = fields.webDomains.firstOrNull().orEmpty()
        val saveIntent = Intent(this, AutofillAuthActivity::class.java).apply {
            putExtra(AutofillContract.EXTRA_MODE, AutofillContract.MODE_SAVE)
            putExtra(AutofillContract.EXTRA_SAVE_TITLE, domain.ifBlank { "新登录信息" })
            putExtra(AutofillContract.EXTRA_SAVE_USERNAME, username)
            putExtra(AutofillContract.EXTRA_SAVE_PASSWORD, password)
            putExtra(AutofillContract.EXTRA_SAVE_URL, domain)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            saveIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                },
        )
        callback.onSuccess(pendingIntent.intentSender)
    }

    private fun lockedPresentation(): RemoteViews =
        RemoteViews(packageName, R.layout.autofill_presentation).apply {
            setTextViewText(R.id.autofill_label, "填充")
        }

    companion object {
        private const val TAG = "PineVaultAutofill"
    }
}

private data class ParsedAutofillFields(
    val candidateIds: List<AutofillId>,
    val usernameIds: List<AutofillId>,
    val passwordIds: List<AutofillId>,
    val webDomains: Set<String>,
    val values: Map<AutofillId, String>,
)

private object AutofillStructureParser {
    fun parse(structure: AssistStructure): ParsedAutofillFields {
        val usernames = linkedSetOf<AutofillId>()
        val passwords = linkedSetOf<AutofillId>()
        val candidates = linkedSetOf<AutofillId>()
        val domains = linkedSetOf<String>()
        val values = linkedMapOf<AutofillId, String>()
        for (windowIndex in 0 until structure.windowNodeCount) {
            visit(
                structure.getWindowNodeAt(windowIndex).rootViewNode,
                usernames,
                passwords,
                candidates,
                domains,
                values,
            )
        }
        val unclassified = candidates - passwords - usernames
        if (passwords.isNotEmpty() && usernames.isEmpty() && unclassified.size == 1) {
            usernames.add(unclassified.single())
        }
        return ParsedAutofillFields(
            candidates.toList(),
            usernames.toList(),
            passwords.toList(),
            domains,
            values,
        )
    }

    private fun visit(
        node: AssistStructure.ViewNode,
        usernames: MutableSet<AutofillId>,
        passwords: MutableSet<AutofillId>,
        candidates: MutableSet<AutofillId>,
        domains: MutableSet<String>,
        values: MutableMap<AutofillId, String>,
    ) {
        node.webDomain?.trim()?.lowercase()?.takeIf { it.isNotEmpty() }?.let(domains::add)
        val id = node.autofillId
        if (id != null && node.autofillType == View.AUTOFILL_TYPE_TEXT) {
            candidates.add(id)
            node.autofillValue?.textValue?.toString()?.let { values[id] = it }
            val hints = node.autofillHints.orEmpty().map(String::lowercase)
            val attributes = node.htmlInfo?.attributes.orEmpty()
                .joinToString(" ") { "${it.first}=${it.second}" }
            val signal = listOfNotNull(
                node.hint?.toString(),
                node.idEntry,
                node.textIdEntry,
                node.contentDescription?.toString(),
                attributes,
            ).joinToString(" ").lowercase()
            val variation = node.inputType and InputType.TYPE_MASK_VARIATION
            val isPassword = hints.any {
                it == View.AUTOFILL_HINT_PASSWORD.lowercase() || it == "newpassword"
            } || variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
                variation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ||
                Regex("(^|[^a-z])(password|passwd|pwd|密码)([^a-z]|$)").containsMatchIn(signal)
            val isUsername = hints.any {
                it == View.AUTOFILL_HINT_USERNAME || it == View.AUTOFILL_HINT_EMAIL_ADDRESS
            } || variation == InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS ||
                variation == InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS ||
                Regex("(^|[^a-z])(username|user|login|email|account|账号|邮箱)([^a-z]|$)")
                    .containsMatchIn(signal)
            if (isPassword) passwords.add(id)
            if (isUsername && !isPassword) usernames.add(id)
        }
        for (index in 0 until node.childCount) {
            visit(node.getChildAt(index), usernames, passwords, candidates, domains, values)
        }
    }
}

internal object AutofillContract {
    const val AUTH_CHANNEL = "app.pinevault.client/autofill_auth"
    const val EXTRA_USERNAME_IDS = "pinevault.username_ids"
    const val EXTRA_PASSWORD_IDS = "pinevault.password_ids"
    const val EXTRA_PACKAGE_NAMES = "pinevault.package_names"
    const val EXTRA_WEB_DOMAINS = "pinevault.web_domains"
    const val EXTRA_MODE = "pinevault.mode"
    const val MODE_SAVE = "save"
    const val EXTRA_SAVE_TITLE = "pinevault.save_title"
    const val EXTRA_SAVE_USERNAME = "pinevault.save_username"
    const val EXTRA_SAVE_PASSWORD = "pinevault.save_password"
    const val EXTRA_SAVE_URL = "pinevault.save_url"
    const val STATE_PREFERENCES = "pinevault.autofill_state"
    const val PENDING_SAVE_REFRESH = "pending_save_refresh"
}
