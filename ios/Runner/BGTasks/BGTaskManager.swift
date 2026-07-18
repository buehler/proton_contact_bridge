//
//  BGTaskManager.swift
//  Runner
//
//  Created by christoph on 27.08.2026.
//

import OSLog

enum BGTaskManager {
    private static let logger = Logger(
        subsystem: "ch.cbue.protonContactBridge",
        category: "BGTaskManager"
    )
    static private let tasks = [
        BGIncrementalSyncTask()
    ]
    
    static func register() {
        Self.logger.info("Register Background Tasks")
        for task in tasks {
            task.register()
        }
    }
    
    static func schedule() {
        Self.logger.info("Schedule Background Tasks")
        for task in tasks {
            task.schedule()
        }
    }
}
