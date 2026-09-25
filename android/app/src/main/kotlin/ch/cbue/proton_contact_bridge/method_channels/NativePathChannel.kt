package ch.cbue.proton_contact_bridge.method_channels

import android.content.Context
import android.util.Log
import ch.cbue.proton_contact_bridge.database.ContactsDatabase
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NativePathChannel(private val context: Context) : AppMethodChannel {
    companion object {
        private const val TAG = "NativePathChannel"
    }

    override val channelName = "ch.cbue.protonContactBridge/native_path"

    private var channel: MethodChannel? = null

    override fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            handle(call, result)
        }
    }

    override fun tearDown() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        Log.i(TAG, "received method call: ${call.method}")

        when (call.method) {
            "databasePath" -> {
                try {
                    val dbFile = ContactsDatabase.path(context)
                    result.success(dbFile)
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