import ContactProvider
import Flutter
import Foundation
import OSLog

final class ContactProviderChannel {
    static let channelName = "ch.cbue.protonContactBridge/contact_provider"
    private static let logger = Logger(
        subsystem: "ch.cbue.protonContactBridge",
        category: "ContactProviderChannel"
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
                        message: "Contact provider channel was released",
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
        case "signalEnumerator":
            Task {
                do {
                    try await ContactProviderSignaler.signalContactProvider()
                    result(nil)
                } catch {
                    Self.logger.error(
                        "Contact provider signaling failed: \(error.localizedDescription, privacy: .public)"
                    )
                    result(
                        FlutterError(
                            code: "signal_failed",
                            message: error.localizedDescription,
                            details: nil
                        )
                    )
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
