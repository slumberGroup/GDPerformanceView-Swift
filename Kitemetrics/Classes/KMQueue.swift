//
//  KMQueue.swift
//  Kitemetrics
//
//  Created by Kitemetrics on 10/31/16.
//  Copyright © 2021 Kitemetrics. All rights reserved.
//

import Foundation
import Reachability

class KMQueue: CPUAndMemoryUsageObservableProtocol {
        
    var reachability: Reachability?
    let requester = KMRequest()
    var queue = [URLRequest]()
    var outgoingRequests = [URL: Int]()
    
    var filesToSend: [URL]?
    var errorFilesToSend: [URL]?
    var requestsToSend: [URLRequest]?
    var currentFile: URL?
    var newFilesToLoad = false
    var errorOnLastSend = false
    var isApiKeySet = false
    
    var isQueueSuspended = false
    
    let serialDispatchQueue = DispatchQueue(label: "com.kitemetrics.KMQueue.serialDispatchQueue", qos: .background)
    
    private var resourcesMonitor: KMDeviceResourcesMonitor?
    
    static let kMaxQueueSize = 15
    static let kTimeToWaitBeforeSendingMessagesWithErrors = 12.0 * 60.0 * 60.0 // 12 hours
    static let kMaxQueueFilesToSave = 200
    static let kMaxErrorFilesToSave = 100
    
    init() {
        self.requester.queue = self
        self.reachability = try! Reachability()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didReceivePostSuccess), name: NSNotification.Name(rawValue: "com.kitefaster.KMRequest.Post.Success"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didReceivePostError), name: NSNotification.Name(rawValue: "com.kitefaster.KMRequest.Post.Error"), object: nil)
        
        resourcesMonitor = KMDeviceResourcesMonitor()
        
        resourcesMonitor?.addObserver(self)
        
        KMLog.p("KMQueue init")
    }
    
    deinit {
        resourcesMonitor?.removeObserver(self)
        resourcesMonitor = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    func addItem(item: URLRequest) {
        self.serialDispatchQueue.async {
            KMLog.p("KMQueue addItem with url: " +  item.url!.absoluteString)
            self.queue.append(item)
            
            if self.queue.count > KMQueue.kMaxQueueSize {
                self.saveQueue()
            }
        }
    }
    
    func saveQueue(setCloseTime: Bool = false) {
        self.serialDispatchQueue.async {
            if self.queue.count > 0 {
                KMLog.p("KMQueue saveQueue, " + String(self.queue.count) + " items.")
                var filePath = self.queueDirectory()
                let now = String(Date().timeIntervalSinceReferenceDate)
                filePath = filePath.appendingPathComponent(now + ".data", isDirectory: false)
                
                do {
                    let data = NSKeyedArchiver.archivedData(withRootObject: self.queue)
                    try data.write(to: filePath, options: [NSData.WritingOptions.atomic])
                    self.queue.removeAll()
                    self.newFilesToLoad = true
                } catch let error {
                    KMError.logError(error)
                }
                
                //If over file limit, remove older files
                self.removeOldFiles(directory: self.queueDirectory(), maxFilesToKeep: KMQueue.kMaxQueueFilesToSave)
            }
            
            if self.isReadyToSend() {
                if self.newFilesToLoad
                && self.currentFile == nil
                && (self.requestsToSend == nil || self.requestsToSend!.count == 0)
                && (self.filesToSend == nil || self.filesToSend!.count == 0) || self.errorOnLastSend {
                    self.startSending()
                } else if (Kitemetrics.shared.currentBackoffMultiplier > 1 && self.currentFile != nil && self.requestsToSend != nil && self.requestsToSend!.count > 0 && self.filesToSend != nil && self.filesToSend!.count > 0) {
                    self.sendNextRequest()
                }
                self.startSendingErrors()
            }
            
            if setCloseTime {
                KMUserDefaults.setCloseTime(Date())
            }
        }
    }
    
    func removeOldFiles(directory: URL, maxFilesToKeep: Int) {
        let fileManager = FileManager.default
        do {
            var contents: [URL]? = nil
            contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)
            
            //if we have too many files, delete the oldest files
            if contents != nil && contents!.count > maxFilesToKeep {
                let orderedContents = contents!.sorted {a,b in
                    let atime = KMQueue.timeIntervalFromFilename(a.lastPathComponent)
                    let btime = KMQueue.timeIntervalFromFilename(b.lastPathComponent)
                    return atime < btime
                }
                contents = nil
                
                let overage = orderedContents.count - maxFilesToKeep
                for i in 0...overage - 1 {
                    let url = orderedContents[i]
                    do {
                        try FileManager.default.removeItem(at: url)
                    } catch let error {
                        KMError.logError(error)
                    }
                }
            }
        } catch let error {
            KMError.logError(error)
        }
    }
    
    func saveRequestToError(_ request: URLRequest) {
        self.serialDispatchQueue.async {
            KMLog.p("KMQueue saveRequestToError")
            var filePath = self.queueErrorsDirectory()
            let now = String(Date().timeIntervalSinceReferenceDate)
            filePath = filePath.appendingPathComponent(now + ".errdata", isDirectory: false)
                
            do {
                let data = NSKeyedArchiver.archivedData(withRootObject: request)
                try data.write(to: filePath, options: [NSData.WritingOptions.atomic])
            } catch let error {
                KMError.logError(error)
            }
            
            //If over file limit, remove older files
            self.removeOldFiles(directory: self.queueErrorsDirectory(), maxFilesToKeep: KMQueue.kMaxErrorFilesToSave)
            
            self.removeCurrentSendRequestAndSendNext()
        }
    }
    
    func loadFilesToSend() {
        self.serialDispatchQueue.async {
            KMLog.p("KMQueue loadFilesToSend")
            let fileManager = FileManager.default
            do {
                let directory = self.queueDirectory()
                let contents: [URL]? = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)
                    self.newFilesToLoad = false
                    
                    if contents != nil && contents!.count > 0 {
                        self.filesToSend = contents!.sorted {a,b in
                            let atime = KMQueue.timeIntervalFromFilename(a.lastPathComponent)
                            let btime = KMQueue.timeIntervalFromFilename(b.lastPathComponent)
                            return atime < btime
                        }
                    }
            } catch let error {
                KMError.logError(error)
            }
            
            if self.loadRequestsToSend() {
                self.sendNextRequest()
            }
        }
    }
    
    func loadErrorFilesToSend() {
        self.serialDispatchQueue.async {
            KMLog.p("KMQueue loadErrorFilesToSend")
            let fileManager = FileManager.default
            do {
                let contents: [URL]? = try fileManager.contentsOfDirectory(at: self.queueErrorsDirectory(), includingPropertiesForKeys: [], options: FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)
                
                if contents != nil && contents!.count > 0 {
                    self.errorFilesToSend = contents!.sorted {a,b in
                        let atime = KMQueue.timeIntervalFromFilename(a.lastPathComponent)
                        let btime = KMQueue.timeIntervalFromFilename(b.lastPathComponent)
                        return atime < btime
                    }
                }
            } catch let error {
                KMError.logError(error)
            }
            
            self.sendNextErrorRequest()
        }
    }
    
    func errorRequestToSend() -> (request: URLRequest, file: URL)? {
        KMLog.p("KMQueue errorRequestToSend")
        if self.errorFilesToSend != nil && self.errorFilesToSend!.count > 0 {
            guard let file = self.errorFilesToSend?.first else {
                return nil
            }
            do {
                let data = try Data(contentsOf: file)
                if let request = NSKeyedUnarchiver.unarchiveObject(with: data) as? URLRequest {
                    return (request, file)
                } else {
                    return nil
                }
            } catch let error {
                KMError.logError(error)
            }
        }
        return nil
    }
    
    func loadRequestsToSend() -> Bool {
        KMLog.p("KMQueue loadRequestsToSend")
        
        guard let filesToSend = filesToSend,
              filesToSend.isEmpty == false else {
                  KMLog.p("KMQueue loadRequestsToSend empty or nil")
                  return false
              }
        
        KMLog.p("KMQueue loadRequestsToSend filesToSend count \(filesToSend.count)")
        guard let file = filesToSend.first else {
            return false
        }
        do {
            KMLog.p("KMQueue loadRequestsToSend getting data")
            let data = try Data(contentsOf: file)
            KMLog.p("KMQueue loadRequestsToSend data bytes \(data.count)")
            self.requestsToSend = NSKeyedUnarchiver.unarchiveObject(with: data) as? [URLRequest]
            self.currentFile = file
            return true
        } catch let error {
            KMError.logError(error)
        }
        return false
    }
    
    func sendNextRequest() {
        KMLog.p("KMQueue sendNextRequest")
        self.errorOnLastSend = false
        if isReadyToSend() {
            guard let request = self.requestsToSend?.first else {
                KMError.logErrorMessage("sendNextRequest: Expected to find a request in the queue but it is empty.")
                return
            }
            if let currentFile = self.currentFile {
                self.requester.postRequest(request, filename: currentFile)
            }
        }
    }
    
    func sendNextErrorRequest() {
        KMLog.p("KMQueue sendNextErrorRequest")
        if isReadyToSend() {
            guard let (request, file) = errorRequestToSend() else {
                return
            }
            self.requester.postRequest(request, filename: file)
        }
    }
    
    @objc func didReceivePostSuccess(notification: Notification) {
        KMLog.p("KMQueue didReceivePostSuccess")
        if let info = notification.userInfo as? Dictionary<String, Any> {
            guard let filename = info["filename"] as? URL else {
                KMError.logErrorMessage("Post success notification is missing filename.")
                return
            }
            
            if filename.pathExtension == "errdata" {
                removeCurrentErrorSendRequestAndSendNext(filename)
            } else {
                if self.currentFile == filename {
                    removeCurrentSendRequestAndSendNext()
                } else {
                    KMError.logErrorMessage("didReceivePostSuccess: Filenames do not match.")
                }
            }
        }
    }
    
    @objc func didReceivePostError(notification: Notification) {
        KMLog.p("KMQueue didReceivePostError")
        
        if let info = notification.userInfo as? Dictionary<String, Any> {
            guard let filename = info["filename"] as? URL else {
                KMError.logErrorMessage("Post error notification is missing filename.")
                return
            }
            guard var request = info["request"] as? URLRequest else {
                KMError.logErrorMessage("Post error notification is missing request.")
                return
            }
            
            let isOldError = filename.pathExtension == "errdata"
            if isOldError {
                if errorFilesToSend?.first != filename {
                    KMError.logErrorMessage("didReceivePostError oldError: Filenames do not match.")
                    return
                }
            } else {
                if self.currentFile != filename {
                    KMError.logErrorMessage("didReceivePostError: Filenames do not match.")
                    return
                }
            }
            
            let requestAttemptCountStr = request.value(forHTTPHeaderField: "requestAttemptCount")
            var requestAttemptCount: Int? = 1
            if requestAttemptCountStr == nil {
                request.setValue("1", forHTTPHeaderField: "requestAttemptCount")
            } else {
                requestAttemptCount = Int(requestAttemptCountStr!)
                if requestAttemptCount == nil || requestAttemptCountStr == nil {
                    requestAttemptCount = 1
                    request.setValue("1", forHTTPHeaderField: "requestAttemptCount")
                    KMError.logErrorMessage("Could not convert value of requestAttemptCount to int.  value = " + requestAttemptCountStr!)
                }
                requestAttemptCount = requestAttemptCount! + 1
                request.setValue(String(describing: requestAttemptCount!), forHTTPHeaderField: "requestAttemptCount")
            }
                    
            if isOldError {
                do {
                    let data = NSKeyedArchiver.archivedData(withRootObject: request)
                    try data.write(to: filename, options: [NSData.WritingOptions.atomic])
                } catch let error {
                    KMError.logError(error)
                }
                skipCurrentErrorSendRequestAndSendNext(filename)
            } else {
                if requestAttemptCount! >= 3 {
                    saveRequestToError(request)
                } else {
                    if self.requestsToSend != nil && self.requestsToSend!.count > 0 {
                        self.requestsToSend?[0] = request
                        //overwrite current file with the modified request
                        do {
                            if let array = self.requestsToSend {
                                let data = NSKeyedArchiver.archivedData(withRootObject: array)
                                if let currentFile = self.currentFile {
                                    try data.write(to: currentFile, options: [NSData.WritingOptions.atomic])
                                }
                            }
                        } catch let error {
                            KMError.logError(error)
                        }
                        
                        //Make sure this flag is set last to prevent multi-threading conflicts
                        self.errorOnLastSend = true
                    }
                }
            }
        
        }
    }
    
    func removeCurrentSendRequestAndSendNext() {
        KMLog.p("KMQueue removeCurrentSendRequestAndSendNext")
        if self.requestsToSend?.isEmpty == false {
            self.requestsToSend?.removeFirst()
            if self.requestsToSend?.isEmpty == true && self.filesToSend?.isEmpty == false {
                self.filesToSend?.removeFirst()
                if let currentFile = self.currentFile {
                    do {
                        try FileManager.default.removeItem(at: currentFile)
                        self.currentFile = nil
                    } catch let error {
                        KMError.logError(error)
                    }
                }
                if self.loadRequestsToSend() {
                    self.sendNextRequest()
                } else if self.newFilesToLoad {
                    self.startSending()
                }
            } else {
                //overwrite current file without the sent request
                do {
                    if let array = self.requestsToSend {
                        let data = NSKeyedArchiver.archivedData(withRootObject: array)
                        if let currentFile = self.currentFile {
                            try data.write(to: currentFile, options: [NSData.WritingOptions.atomic])
                        }
                    }
                } catch let error {
                    KMError.logError(error)
                }
                self.sendNextRequest()
            }
        }
    }
    
    func removeCurrentErrorSendRequestAndSendNext(_ filename: URL) {
        KMLog.p("KMQueue removeCurrentErrorSendRequestAndSendNext")
        if self.errorFilesToSend != nil && self.errorFilesToSend!.count > 0 && self.errorFilesToSend![0] == filename {
            self.errorFilesToSend!.remove(at: 0)
        }
        
        do {
            try FileManager.default.removeItem(at: filename)
        } catch let error {
            KMError.logError(error)
        }
        
        sendNextErrorRequest()
    }
    
    func skipCurrentErrorSendRequestAndSendNext(_ filename: URL) {
        KMLog.p("KMQueue skipCurrentErrorSendRequestAndSendNext")
        if self.errorFilesToSend != nil && self.errorFilesToSend!.count > 0 && self.errorFilesToSend![0] == filename {
            self.errorFilesToSend!.remove(at: 0)
        }
        
        sendNextErrorRequest()
    }
    
    func startSending() {
        KMLog.p("KMQueue startSending")
        if isReadyToSend() {
            loadFilesToSend()
        }
    }
    
    func startSendingErrors() {
        guard let lastAttemptDate = KMUserDefaults.lastAttemptToSendErrorQueue() else {
            return
        }
        if fabs(lastAttemptDate.timeIntervalSinceNow) > KMQueue.kTimeToWaitBeforeSendingMessagesWithErrors {
            KMUserDefaults.setLastAttemptToSendErrorQueue(Date())
            loadErrorFilesToSend()
        }
    }
    
    class func timeIntervalFromFilename(_ filename: String) -> TimeInterval {
        let timeAsString: String
        if filename.contains(".data") {
            timeAsString = filename.replacingOccurrences(of: ".data", with: "")
        } else {
            timeAsString = filename.replacingOccurrences(of: ".errdata", with: "")
        }
        let time = TimeInterval(timeAsString)
        return time!
    }
    
    func applicationLibraryDirectory() -> URL {
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).last!
    }
    
    func queueDirectory() -> URL {
        return kitemetricsDirectoryWithSubDir(subdirectory: "queue")
    }
    
    func queueErrorsDirectory() -> URL {
        return kitemetricsDirectoryWithSubDir(subdirectory: "queueErrors")
    }
    
    func kitemetricsDirectoryWithSubDir(subdirectory: String) -> URL {
        let documentsDir = applicationLibraryDirectory()
        
        let path = documentsDir.appendingPathComponent("Application Support", isDirectory:true).appendingPathComponent(KMDevice.appBundleId(), isDirectory:true).appendingPathComponent("Kitemetrics", isDirectory:true).appendingPathComponent(subdirectory, isDirectory:true)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path.relativePath) == false {
            do {
                try fileManager.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                KMError.logError(error)
            }
        }
        
        return path
    }
    
    func isReadyToSend() -> Bool {
        if self.isApiKeySet == false {
            if Kitemetrics.shared.apiKey == "" {
                KMError.logErrorMessage("Kitemetrics needs API Key, or API Key not yet loaded", sendToServer: false)
                return false
            } else {
                self.isApiKeySet = true
            }
        }
        
        if let reachability = self.reachability {
            if reachability.connection != .unavailable && self.isApiKeySet {
                if Kitemetrics.shared.currentBackoffValue < Kitemetrics.shared.currentBackoffMultiplier {
                    Kitemetrics.shared.currentBackoffValue = Kitemetrics.shared.currentBackoffValue + 1
                    KMLog.p("Connection timeout, skip")
                    return false
                }
                
                KMLog.p("Ready to send")
                return true
            }
        } else {
            KMLog.p("Not reachable")
        }
        
        return false
    }
    
    // MARK: - CPUAndMemoryUsageObservableProtocol
    
    var identifier: String {
        return "KMQueue"
    }
    
    func cpuIsReachingLimit() {
        if isQueueSuspended == false {
            isQueueSuspended = true
            serialDispatchQueue.suspend()
        }
    }
    
    func cpuHasCalmedDown() {
        if isQueueSuspended == true {
            isQueueSuspended = false
            serialDispatchQueue.resume()
        }
    }
    
}
