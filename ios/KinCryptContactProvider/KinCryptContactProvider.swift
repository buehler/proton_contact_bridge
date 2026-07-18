//
//  KinCryptContactProvider.swift
//  KinCryptContactProvider
//
//  Created by christoph on 16.08.2026.
//

import ContactProvider
import ExtensionFoundation
import Foundation
import OSLog

enum ContactProviderLog {
    private static let subsystem = "ch.cbue.protonContactBridge"

    static let lifecycle = Logger(
        subsystem: subsystem,
        category: "ContactProviderExtension"
    )
    static let database = Logger(
        subsystem: subsystem,
        category: "ContactProviderDatabase"
    )
    static let enumeration = Logger(
        subsystem: subsystem,
        category: "ContactProviderEnumeration"
    )
}

@main
class KinCryptContactProvider: ContactProviderExtension {
    private let rootContainerEnumerator: KinCryptContactProviderRootContainerEnumerator

    required init() {
        rootContainerEnumerator = KinCryptContactProviderRootContainerEnumerator()
        ContactProviderLog.lifecycle.notice("Contact provider extension initialized")
    }

    func configure(for domain: ContactProviderDomain) {
        ContactProviderLog.lifecycle.debug("Contact provider domain configured")
    }

    func enumerator(for collection: ContactItem.Identifier) -> ContactItemEnumerator {
        ContactProviderLog.lifecycle.debug("Root container enumerator requested")
        return rootContainerEnumerator
    }

    func invalidate() async throws {
        ContactProviderLog.lifecycle.notice("Contact provider extension invalidating")
        await rootContainerEnumerator.invalidate()
        ContactProviderLog.lifecycle.notice("Contact provider extension invalidated")
    }
}
