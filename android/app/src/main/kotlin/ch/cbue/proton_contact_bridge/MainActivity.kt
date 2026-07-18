package ch.cbue.proton_contact_bridge

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var nativePathChannel: NativePathChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        nativePathChannel = NativePathChannel(
            context = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        nativePathChannel?.tearDown()
        nativePathChannel = null

        super.cleanUpFlutterEngine(flutterEngine)
    }
}
