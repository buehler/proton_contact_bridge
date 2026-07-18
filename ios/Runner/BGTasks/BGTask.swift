//
//  BGTask.swift
//  Runner
//
//  Created by christoph on 23.08.2026.
//

protocol BGTask {
    var identifier: String { get }
    var scheduleDelay: TimeInterval { get }
    func register()
    func schedule()
}
