package ch.cbue.proton_contact_bridge.method_channels

import io.flutter.plugin.common.BinaryMessenger

interface AppMethodChannel {
    val channelName: String
    fun register(messenger: BinaryMessenger)
    fun tearDown()
}
