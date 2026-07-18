package ch.cbue.proton_contact_bridge

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class NativePathChannel(private val context: Context, messenger: BinaryMessenger) {
    companion object {
        const val CHANNEL_NAME = "ch.cbue.protonContactBridge/native_path"
        private const val TAG = "NativePathChannel"
    }

    private var channel: MethodChannel? = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel?.setMethodCallHandler { call, result ->
            handle(call, result)
        }
    }

    fun tearDown() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        Log.i(TAG, "received method call: ${call.method}")

        when (call.method) {
            "databasePath" -> {
                try {
                    val noBackupDir = context.noBackupFilesDir
                    val dbFile = File(noBackupDir, "databases/proton_contacts.db")
                    dbFile.parentFile?.mkdirs()
                    result.success(dbFile.absolutePath)
                } catch (e: Exception) {
                    result.error(
                        "container_unavailable",
                        "Unable to access safe app storage path",
                        e.localizedMessage
                    )
                }
            }
            else -> result.notImplemented()
        }
    }
}