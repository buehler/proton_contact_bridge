import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
    private var nativePathChannel: NativePathChannel?

    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        self.minSize = NSSize(width: 400, height: 600)

        nativePathChannel = NativePathChannel(
            with: flutterViewController.engine.binaryMessenger
        )

        RegisterGeneratedPlugins(registry: flutterViewController)

        super.awakeFromNib()
    }
}
