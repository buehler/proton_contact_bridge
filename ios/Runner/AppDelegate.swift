import ContactProvider
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var contactProviderChannel: ContactProviderChannel?
    private var nativePathChannel: NativePathChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication
            .LaunchOptionsKey: Any]?
    ) -> Bool {
        BGTaskManager.register()
        BGTaskManager.schedule()
        return super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
    }

    func didInitializeImplicitFlutterEngine(
        _ engineBridge: FlutterImplicitEngineBridge
    ) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        contactProviderChannel = ContactProviderChannel(
            with: engineBridge.applicationRegistrar.messenger()
        )
        nativePathChannel = NativePathChannel(
            with: engineBridge.applicationRegistrar.messenger()
        )
    }
}
