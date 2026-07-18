package ch.cbue.proton_go_api_bridge;

import android.content.Context;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodChannel;

public final class ProtonGoApiBridgePlugin implements FlutterPlugin {
    private MethodChannel channel;

    private static native long[] nativeHandles(AndroidSecureStorage helper);

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        Context context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(),
                "ch.cbue.proton_go_api_bridge/platform");
        channel.setMethodCallHandler((call, result) -> {
            if (!call.method.equals("initialize")) {
                result.notImplemented();
                return;
            }
            try {
                System.loadLibrary("proton_bridge_bootstrap");
                long[] handles = nativeHandles(new AndroidSecureStorage(context));
                if (handles == null) {
                    result.error("initialization_failed", "Android JNI initialization failed", null);
                } else {
                    result.success(handles);
                }
            } catch (RuntimeException | LinkageError exception) {
                // Never send platform exception messages across the channel.
                result.error("initialization_failed", "Android platform initialization failed", null);
            }
        });
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        // Native auth refresh may outlive this engine. The helper is owned by
        // the process, holds no Activity, and is reused by subsequent engines.
    }
}
