//
//  ContactProviderSignler.swift
//  Runner
//
//  Created by christoph on 26.08.2026.
//

import OSLog
import ContactProvider

enum ContactProviderSignaler {
    private static let logger = Logger(
        subsystem: "ch.cbue.protonContactBridge",
        category: "ContactProviderSignaler"
    )
    
    static func signalContactProvider() async throws {
        let manager = try ContactProviderManager()
        
        if !manager.isEnabled {
            Self.logger.info("Enabling contact provider")
            try await manager.enable()
        }
        
        guard manager.isEnabled else {
            throw ContactProviderError.deniedByUser
        }
        
        Self.logger.info("Signaling contact provider enumerator")
        do {
            try await manager.signalEnumerator()
        } catch {
            let cocoaError = error as NSError
            guard
                cocoaError.domain == NSCocoaErrorDomain,
                cocoaError.code == 4097 || cocoaError.code == 4099
            else {
                throw error
            }

            Self.logger.notice(
                "Contact provider helper connection failed; resetting the domain and retrying once"
            )
            try await manager.reset()
            try await manager.signalEnumerator()
        }
        Self.logger.info("Contact provider enumerator signaled")
    }
}
