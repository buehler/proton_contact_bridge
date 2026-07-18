//
//  BGIncrementalSyncTask.swift
//  Runner
//
//  Created by christoph on 23.08.2026.
//

import BackgroundTasks
import Foundation
import OSLog
import Synchronization

class BGIncrementalSyncTask: BGTask {
    let identifier = "ch.cbue.protonContactBridge.bgIncrementalSyncTask"
    let scheduleDelay = 60.0 * 60.0 * 6  // 6 hours
    private let logger = Logger(
        subsystem: "ch.cbue.protonContactBridge",
        category: "BGIncrementalSyncTask"
    )

    func register() {
        logger.info("register bg task \(self.identifier)")
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: self.identifier,
            using: nil
        ) { [weak self] task in
            guard
                let self,
                let refreshTask = task as? BGAppRefreshTask
            else {
                task.setTaskCompleted(success: false)
                return
            }

            self.handle(refreshTask)
        }
    }

    func schedule() {
        logger.info("schedule bg task \(self.identifier)")
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: scheduleDelay)

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info(
                "Scheduled incremental sync no earlier than \(self.scheduleDelay, privacy: .public)s"
            )
        } catch {
            logger.error(
                "Could not schedule incremental sync: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func handle(_ task: BGAppRefreshTask) {
        schedule()

        let completed = Mutex(false)

        func finish(success: Bool) {
            let claimed = completed.withLock { didComplete in
                guard !didComplete else { return false }
                didComplete = true
                return true
            }

            guard claimed else { return }

            task.expirationHandler = nil
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            finish(success: false)
        }

        Task.detached { [weak self] in
            self?.logger.info("execute background incremental sync")

            self?.logger.debug("initialize DB")
            guard let dbURL = try? Database.url() else {
                self?.logger.error("could not resolve database path")
                finish(success: false)
                return
            }
            InitializeDatabase(dbURL.path)

            self?.logger.debug("initialize Auth")
            InitializeAuthFromStore()

            self?.logger.debug("execute sync")
            let result = ExecuteIncrementalSync()

            switch result {
            case UInt8(INCREMENTAL_CONTACT_SYNC_SUCCESS):
                self?.logger.debug("incremental contact sync success")
                do {
                    try await ContactProviderSignaler.signalContactProvider()
                } catch {
                    self?.logger.warning(
                        "could not signal the contact provider: \(error)"
                    )
                }
                finish(success: true)

            case UInt8(INCREMENTAL_CONTACT_SYNC_ERROR),
                UInt8(INCREMENTAL_CONTACT_SYNC_DB_ERROR):
                self?.logger.error("incremental contact sync failed")
                finish(success: false)

            default:
                self?.logger.warning("received unexpected result: \(result)")
                finish(success: false)
            }
        }
    }
}
