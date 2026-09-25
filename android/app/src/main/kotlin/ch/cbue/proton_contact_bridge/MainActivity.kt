package ch.cbue.proton_contact_bridge

import ch.cbue.proton_contact_bridge.method_channels.ContactProviderChannel
import ch.cbue.proton_contact_bridge.method_channels.NativePathChannel
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val contactProviderChannel = ContactProviderChannel(this)
    private val channels = arrayOf(
        NativePathChannel(this),
        contactProviderChannel,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        contactProviderChannel.attachActivity(this)
        channels.forEach { it.register(flutterEngine.dartExecutor.binaryMessenger) }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (!contactProviderChannel.onRequestPermissionsResult(requestCode, grantResults)) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channels.forEach { it.tearDown() }
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        contactProviderChannel.detachActivity()
        super.onDestroy()
    }
}
