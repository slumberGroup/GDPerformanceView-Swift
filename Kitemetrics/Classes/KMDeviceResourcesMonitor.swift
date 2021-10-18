//
//  KMDeviceResourcesMonitor.swift
//  Slumber
//
//  Created by Joao Garcia on 10/14/21.
//  Copyright © 2021 Summermedia. All rights reserved.
//

import Foundation
import GDPerformanceView_Swift

extension Notification.Name {
    public static let cpuHighUsageLimitReachedNotification = Notification.Name("cpuHighUsageLimitReachedNotification")
    public static let cpuRegularUsageReachedNotification = Notification.Name("cpuRegularUsageReachedNotification")
}

protocol ObservableProtocol {
    var identifier: String { get }
}

protocol CPUAndMemoryUsageReportObservableProtocol: ObservableProtocol {
    func didUpdateCPUAndMemoryUsage(_ usageReport: KMUsageReport)
}

protocol CPUAndMemoryUsageObservableProtocol: ObservableProtocol {
    func cpuIsReachingLimit()
    func cpuHasCalmedDown()
}

/// Memory usage struct. Contains used and total memory in bytes.
struct KMMemoryUsage {
    let used: UInt64
    let total: UInt64
}

/// Usage report struct. Contains CPU usage and average in percentages, FPS and memory usage.
struct KMUsageReport {
    let cpuUsage: Double
    let cpuAverageUsage: Int
    let fps: Int
    let memoryUsage: KMMemoryUsage
}

class KMDeviceResourcesMonitor {
    
    private static let cpuThresholdRatio = 90
    private static let cpuOverThresholdLimitInSeconds = 80 // The limit is 50 (`cpuThresholdRatio`) over 180 seconds.
   
    private var firstTimestamp: DispatchTime?
    private var cpuUsageValues: [Int] = Array(repeating: 0,
                                                   count: KMDeviceResourcesMonitor.cpuOverThresholdLimitInSeconds)
    private var cpuAverageUsage: Int = 0
    private var lastAverageIndexModified: Int = -1
    private var previousElapsedSeconds: Int = 0
    
    /**
     Starts a `PerformanceMonitor`.
     Once we reach `cpuThresholdRatio` we will start counting `cpuOverThresholdLimitInSeconds` before we tell observers
     that the CPU is reaching a high level of usage.
     */
    private lazy var performanceMonitor: PerformanceMonitor = {
        let performanceMonitor = PerformanceMonitor(options: [.performance, .memory],
                                                    style: .light,
                                                    delegate: self)
        performanceMonitor.start()
        performanceMonitor.hide()
        return performanceMonitor
    }()
    
    private var observers: [ObservableProtocol] = []
    
    /**
     Adds an observer to be notified.
     */
    public func addObserver<T: ObservableProtocol>(_ observerToAdd: T) {
        if observers.contains(where: { observer in
            return observer.identifier == observerToAdd.identifier
        }) == false {
            observers.append(observerToAdd)
        }
    }
    
    /**
     Removes an observer from being notified.
     */
    public func removeObserver<T: ObservableProtocol>(_ observerToRemove: T) {
        observers.removeAll(where: { observer in
            return observer.identifier == observerToRemove.identifier
        })
    }
    
    /**
     Checks if we the current CPU usage is above the threshold usage limit (`cpuThresholdRatio`) for the time
     limit threshold (`cpuOverThresholdLimitInSeconds`) and lets observers know so they can loosen up cpu activity.
     Also if it is below the threshold we let them know so they can go back to normal.
     Returns the current CPU usage average
     */
    fileprivate func cpuUsageDidChange(to value: Int) -> Int {

        guard let start = firstTimestamp else {
            // Start counting time
            firstTimestamp = DispatchTime.now()
            return value
        }

        let end = DispatchTime.now()
        let elapsedNanoSeconds = end.uptimeNanoseconds - start.uptimeNanoseconds
        let elapsedSeconds = Int(Double(elapsedNanoSeconds) / 1_000_000_000)

        // Make sure we only count one measurement per second
        guard elapsedSeconds > previousElapsedSeconds else {
            return cpuAverageUsage
        }
        
        previousElapsedSeconds = elapsedSeconds
        
        let thresholdInSeconds = KMDeviceResourcesMonitor.cpuOverThresholdLimitInSeconds
        
        if lastAverageIndexModified == thresholdInSeconds - 1 {
            lastAverageIndexModified = 0
        } else {
            lastAverageIndexModified += 1
        }
        
        cpuUsageValues[lastAverageIndexModified] = value
        
        // For monitoring purposes, we start calculating the average ahead of time
        cpuAverageUsage = cpuUsageValues.reduce(0, +) / thresholdInSeconds
        
        // Start evaluating the cpu usage average
        guard previousElapsedSeconds > thresholdInSeconds else {
            return cpuAverageUsage
        }
                
        if cpuAverageUsage > KMDeviceResourcesMonitor.cpuThresholdRatio {
            KMLog.p("CPU is reaching its limit.")
            observers.forEach { observer in
                if let usageObserver = observer as? CPUAndMemoryUsageObservableProtocol {
                    KMLog.p("Usage Observer Notified - cpu reaching limit.")
                    usageObserver.cpuIsReachingLimit()
                }
            }
        } else {
            KMLog.p("CPU is calming down.")
            observers.forEach { observer in
                if let usageObserver = observer as? CPUAndMemoryUsageObservableProtocol {
                    KMLog.p("Usage Observer Notified - cpu has calmed down.")
                    usageObserver.cpuHasCalmedDown()
                }
            }
        }
        return cpuAverageUsage
    }
}

extension KMDeviceResourcesMonitor: PerformanceMonitorDelegate {
    func performanceMonitor(didReport performanceReport: PerformanceReport) {
        let currentCPUAverageUsage = cpuUsageDidChange(to: Int(performanceReport.cpuUsage))
        let memoryUsage = KMMemoryUsage(used: performanceReport.memoryUsage.used,
                                        total: performanceReport.memoryUsage.total)
        let report = KMUsageReport(cpuUsage: performanceReport.cpuUsage,
                                         cpuAverageUsage: currentCPUAverageUsage,
                                         fps: performanceReport.fps,
                                         memoryUsage: memoryUsage)
        observers.forEach { observer in
            if let usageObserver = observer as? CPUAndMemoryUsageReportObservableProtocol {
                KMLog.p("Usage Report Observer Notified - did update CPU and memory usage.")
                usageObserver.didUpdateCPUAndMemoryUsage(report)
            }
        }
    }
}
