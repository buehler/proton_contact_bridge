# JNI resolves these names and the helper method directly.
-keep class ch.cbue.proton_go_api_bridge.ProtonGoApiBridgePlugin {
    private static native long[] nativeHandles(ch.cbue.proton_go_api_bridge.AndroidSecureStorage);
}
-keep class ch.cbue.proton_go_api_bridge.AndroidSecureStorage {
    public byte[] execute(int, byte[], byte[]);
}
