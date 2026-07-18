import FlutterMacOS
import Foundation
import OSLog

final class NativePathChannel {
    static let channelName = "ch.cbue.protonContactBridge/native_path"
    private static let logger = Logger(
        subsystem: "ch.cbue.protonContactBridge",
        category: "NativePathChannel"
    )

    private let channel: FlutterMethodChannel

    init(with messenger: any FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: Self.channelName,
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(
                    FlutterError(
                        code: "channel_unavailable",
                        message: "Native Path channel was released",
                        details: nil
                    )
                )
                return
            }

            self.handle(call: call, result: result)
        }
    }

    deinit {
        channel.setMethodCallHandler(nil)
    }

    private func handle(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        Self.logger.notice(
            "received method call: \(call.method, privacy: .public)"
        )
        switch call.method {
        case "databasePath":
            guard let databaseURL = try? Database.url() else {
                result(FlutterError(
                    code: "container_unavailable",
                    message: "Unable to access shared app group container",
                    details: nil
                ))
                return
            }
            result(databaseURL.path)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
