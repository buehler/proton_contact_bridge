package ch.cbue.proton_contact_bridge.method_channels

import android.Manifest
import android.accounts.Account
import android.accounts.AccountManager
import android.app.Activity
import android.content.ContentResolver
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.ContactsContract
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.lang.ref.WeakReference
import kotlin.coroutines.resume
import androidx.core.content.edit
import ch.cbue.proton_contact_bridge.contacts.provider.ContactsSyncCursorState
import ch.cbue.proton_contact_bridge.contacts.provider.StaticAuthenticator

class ContactProviderChannel(private val context: Context) : AppMethodChannel {
    companion object {
        private const val TAG = "ContactProviderChannel"
    }

    override val channelName = "ch.cbue.protonContactBridge/contact_provider"

    private var activityRef = WeakReference<Activity>(null)
    private val scope = CoroutineScope(Dispatchers.Main)
    private var permissionContinuation: kotlinx.coroutines.CancellableContinuation<Boolean>? = null
    private val permissionRequestCode = 1337
    private var channel: MethodChannel? = null
    private val account =
        Account(StaticAuthenticator.ACCOUNT_NAME, StaticAuthenticator.ACCOUNT_TYPE)
    private lateinit var accountManager: AccountManager

    override fun register(messenger: BinaryMessenger) {
        accountManager = AccountManager.get(context)
        channel = MethodChannel(messenger, channelName)
        channel!!.setMethodCallHandler { call, result ->
            handle(call, result)
        }
    }

    override fun tearDown() {
        channel?.setMethodCallHandler(null)
        channel = null
        detachActivity()
    }

    fun attachActivity(activity: Activity) {
        activityRef = WeakReference(activity)
    }

    fun detachActivity() {
        activityRef.clear()
        permissionContinuation?.let { if (it.isActive) it.cancel() }
        permissionContinuation = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        Log.i(TAG, "received method call: ${call.method}")

        when (call.method) {
            "resetContactProvider" -> {
                scope.launch {
                    try {
                        resetProvider()
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "error during reset request", e)
                        result.error(
                            "reset_failed",
                            "unable to reset contact sync provider",
                            e.localizedMessage
                        )
                    }
                }
            }

            "performLocalContactSync" -> {
                try {
                    scope.launch {
                        signalContactProvider()
                        result.success(null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "error during sync request", e)
                    result.error(
                        "sync_failed",
                        "unable to signal contact sync provider",
                        e.localizedMessage
                    )
                }
            }

            else -> result.notImplemented()
        }
    }

    private suspend fun resetProvider() {
        if (!checkPermissions(context)) {
            Log.w(TAG, "permissions to read/write contacts not given. abort.")
            return
        }

        withContext(Dispatchers.IO) {
            ContentResolver.cancelSync(account, ContactsContract.AUTHORITY)

            val rawContactsUri = ContactsContract.RawContacts.CONTENT_URI.buildUpon()
                .appendQueryParameter(ContactsContract.CALLER_IS_SYNCADAPTER, "true")
                .build()
            val deleted = context.contentResolver.delete(
                rawContactsUri,
                "${ContactsContract.RawContacts.ACCOUNT_NAME}=? AND " +
                        "${ContactsContract.RawContacts.ACCOUNT_TYPE}=?",
                arrayOf(account.name, account.type)
            )
            Log.i(TAG, "deleted $deleted raw contacts for ${account.name}")

            ContactsSyncCursorState(context).reset()

            val exists = accountManager.getAccountsByType(account.type)
                .any { it.name == account.name }
            if (exists && !accountManager.removeAccountExplicitly(account)) {
                throw IllegalStateException("Unable to remove ${account.name} account")
            }
        }
    }

    private suspend fun signalContactProvider() {
        if (!checkPermissions(context)) {
            Log.w(TAG, "permissions to read/write contacts not given. abort.")
            return
        }

        val exists = accountManager.getAccountsByType(account.type)
            .any { it.name == account.name }
        if (!exists) {
            Log.i(TAG, "account does not exist. create.")
            val r = accountManager.addAccountExplicitly(account, null, Bundle())
            Log.d(TAG, "create account: $r")
        } else {
            Log.d(TAG, "account already exists")
        }

        if (ContentResolver.getIsSyncable(account, ContactsContract.AUTHORITY) <= 0) {
            Log.d(TAG, "set syncable for account.")
            ContentResolver.setIsSyncable(
                account,
                ContactsContract.AUTHORITY,
                1
            )
        }

        Log.i(
            TAG,
            "syncable=${
                ContentResolver.getIsSyncable(
                    account,
                    ContactsContract.AUTHORITY
                )
            }"
        )
        Log.i(
            TAG,
            "adapterRegistered=" + ContentResolver.getSyncAdapterTypes().any {
                it.accountType == account.type &&
                        it.authority == ContactsContract.AUTHORITY
            }
        )

        Log.i(TAG, "request immediate sync from provider.")
        ContentResolver.requestSync(
            account,
            ContactsContract.AUTHORITY,
            Bundle().apply {
                putBoolean(ContentResolver.SYNC_EXTRAS_MANUAL, true)
                putBoolean(ContentResolver.SYNC_EXTRAS_EXPEDITED, true)
            }
        )

        Log.i(
            TAG,
            "pending=${
                ContentResolver.isSyncPending(
                    account,
                    ContactsContract.AUTHORITY
                )
            }, " +
                    "active=${
                        ContentResolver.isSyncActive(
                            account,
                            ContactsContract.AUTHORITY
                        )
                    }"
        )
    }

    private suspend fun checkPermissions(context: Context): Boolean {
        val permissions =
            listOf(Manifest.permission.READ_CONTACTS, Manifest.permission.WRITE_CONTACTS)
        val missing = permissions.filter {
            ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) return true

        val activity = activityRef.get()
        if (activity == null) {
            Log.w(TAG, "No activity attached; cannot request contacts permissions")
            return false
        }

        // A false rationale result is expected on the first request and after a
        // denial that Android considers permanent. Persist whether we have
        // attempted the request to distinguish those cases across launches.
        val preferences = context.getSharedPreferences("contact_permissions", Context.MODE_PRIVATE)
        fun requestKey(permission: String) = if (permission == Manifest.permission.READ_CONTACTS) {
            "read_contacts_requested"
        } else {
            "write_contacts_requested"
        }

        val permanentlyDenied = missing.any { permission ->
            preferences.getBoolean(requestKey(permission), false) &&
                    !ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)
        }
        if (permanentlyDenied) {
            Log.i(TAG, "Contacts permission was previously denied; not prompting again")
            return false
        }

        if (missing.any { ActivityCompat.shouldShowRequestPermissionRationale(activity, it) }) {
            val userApproved = showAwaitableRationale(
                activity,
                "Contact Access",
                "To provide your KinCrypt contacts to your local phone, we need access to your contacts."
            )
            if (!userApproved) return false
        }

        preferences.edit {
            for (permission in missing) putBoolean(requestKey(permission), true)
        }
        if (!requestSystemPermission(activity, missing.toTypedArray())) return false
        return permissions.all {
            ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private suspend fun requestSystemPermission(
        activity: Activity,
        permissions: Array<String>
    ): Boolean =
        suspendCancellableCoroutine { continuation ->
            if (permissionContinuation?.isActive == true) {
                continuation.resume(false)
                return@suspendCancellableCoroutine
            }
            permissionContinuation = continuation
            continuation.invokeOnCancellation {
                if (permissionContinuation === continuation) permissionContinuation = null
            }
            ActivityCompat.requestPermissions(
                activity,
                permissions,
                permissionRequestCode
            )
        }

    private suspend fun showAwaitableRationale(
        activity: Activity,
        title: String,
        message: String
    ): Boolean =
        suspendCancellableCoroutine { continuation ->
            val dialog = MaterialAlertDialogBuilder(activity)
                .setTitle(title)
                .setMessage(message)
                .setPositiveButton("Allow") { _, _ ->
                    if (continuation.isActive) continuation.resume(
                        true
                    )
                }
                .setNegativeButton("Cancel") { d, _ -> d.dismiss() }
                .setOnDismissListener { if (continuation.isActive) continuation.resume(false) }
                .show()

            continuation.invokeOnCancellation { dialog.dismiss() }
        }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode == permissionRequestCode) {
            val isGranted = grantResults.isNotEmpty() &&
                    grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            val continuation = permissionContinuation
            permissionContinuation = null
            if (continuation?.isActive == true) continuation.resume(isGranted)
            return true
        }
        return false
    }
}
