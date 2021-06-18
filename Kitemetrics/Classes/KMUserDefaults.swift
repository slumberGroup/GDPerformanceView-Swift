//
//  KMUserDefaults.swift
//  Kitemetrics
//
//  Created by Kitemetrics on 10/27/16.
//  Copyright © 2021 Kitemetrics. All rights reserved.
//

import Foundation

enum KMUserDefaults {
    
    static func setDebug(_ isDebug: Bool) {
        UserDefaults.standard.setValue(isDebug, forKey: "com.kitemetrics.isDebug")
    }
    
    static func isDebug() -> Bool {
        return UserDefaults.standard.bool(forKey: "com.kitemetrics.isDebug")
    }
    
    static func setApplicationId(_ kitemetricsApplicationId: Int) {
        UserDefaults.standard.set(kitemetricsApplicationId, forKey: "com.kitemetrics.applicationId")
    }
    
    static func applicationId() -> Int {
        return UserDefaults.standard.integer(forKey: "com.kitemetrics.applicationId")
    }
    
    static func setDeviceId(_ kitemetricsDeviceId: Int) {
        UserDefaults.standard.set(kitemetricsDeviceId, forKey: "com.kitemetrics.deviceId")
    }
    
    static func deviceId() -> Int {
        return UserDefaults.standard.integer(forKey: "com.kitemetrics.deviceId")
    }
    
    static func setVersionId(kitemetricsVersionId: Int?) {
        UserDefaults.standard.set(kitemetricsVersionId, forKey: "com.kitemetrics.versionId")
    }
    
    static func versionId() -> Int {
        return UserDefaults.standard.integer(forKey: "com.kitemetrics.versionId")
    }
    
    static func setLastVersion(_ lastVersion: [String: String]) {
        UserDefaults.standard.set(lastVersion, forKey: "com.kitemetrics.lastVersion")
    }
    
    static func lastVersion() -> [String: String]? {
        return UserDefaults.standard.dictionary(forKey: "com.kitemetrics.lastVersion") as? [String: String]
    }
    
    static func setLaunchTime(_ datetime: Date) {
        UserDefaults.standard.set(datetime, forKey: "com.kitemetrics.launchTime")
    }
    
    static func launchTime() -> Date? {
        return UserDefaults.standard.value(forKey: "com.kitemetrics.launchTime") as? Date
    }

    static func setCloseTime(_ datetime: Date) {
        UserDefaults.standard.set(datetime, forKey: "com.kitemetrics.closeTime")
    }
    
    static func closeTime() -> Date? {
        return UserDefaults.standard.value(forKey: "com.kitemetrics.closeTime") as? Date
    }
    
    static func setLastAttemptToSendErrorQueue(_ datetime: Date) {
        UserDefaults.standard.set(datetime, forKey: "com.kitemetrics.lastAttemptToSendErrorQueue")
    }
    
    static func lastAttemptToSendErrorQueue() -> Date? {
        return UserDefaults.standard.value(forKey: "com.kitemetrics.lastAttemptToSendErrorQueue") as? Date
    }
    
    static func setNeedsSearchAdsAttribution(_ needsAttribution: Bool) {
        UserDefaults.standard.set(needsAttribution, forKey: "com.kitemetrics.needsSearchAdsAttribution")
    }
    
    static func needsSearchAdsAttribution() -> Bool {
        return UserDefaults.standard.bool(forKey: "com.kitemetrics.needsSearchAdsAttribution")
    }
    
    static func setInstallDate(date: Date) {
        UserDefaults.standard.set(date, forKey: "com.kitemetrics.installDate")
    }
    
    static func installDate() -> Date {
        let value = UserDefaults.standard.value(forKey: "com.kitemetrics.installDate")
        if value != nil {
            let val = value as? Date
            if val != nil {
                return val!
            }
        }
        
        //Install date not yet set.  Set it now.
        let today = Date()
        setInstallDate(date: today)
        return today
    }
    
    static func incrementAttributionRequestAttemptNumber() -> Int {
        var attemptNumber = attributionRequestAttemptNumber()
        attemptNumber = attemptNumber + 1
        UserDefaults.standard.set(attemptNumber, forKey: "com.kitemetrics.attributionRequestAttemptNumber")
        return attemptNumber
    }
    
    static func attributionRequestAttemptNumber() -> Int {
        return UserDefaults.standard.integer(forKey: "com.kitemetrics.attributionRequestAttemptNumber")
    }
    
    static func setAttribution(_ attribution: [String : NSObject]) {
        UserDefaults.standard.set(attribution, forKey: "com.kitemetrics.attribution")
        KMUserDefaults.setAttributionDate()
        KMUserDefaults.setAttributionClientVersionId()
    }
    
    static func attribution() -> [String : NSObject]? {
        return UserDefaults.standard.value(forKey: "com.kitemetrics.attribution") as?  [String : NSObject]
    }
    
    static func setAttributionDate() {
        UserDefaults.standard.set(Date(), forKey: "com.kitemetrics.attributionDate")
    }
    
    static func attributionDate() -> Date? {
        return UserDefaults.standard.value(forKey: "com.kitemetrics.attributionDate") as? Date
    }
    
    static func setAttributionClientVersionId() {
        if KMUserDefaults.attributionClientVersionId() == 0 {
            let versionId = KMUserDefaults.versionId()
            if versionId > 0 {
                UserDefaults.standard.set(versionId, forKey: "com.kitemetrics.attributionClientVersionId")
            }
        }
    }
    
    static func attributionClientVersionId() -> Int {
        return UserDefaults.standard.integer(forKey: "com.kitemetrics.attributionClientVersionId")
    }
    
    static func setAttributionToken(_ attributionTokenString: String) {
        UserDefaults.standard.set(attributionTokenString, forKey: "com.kitemetrics.attributionToken")
    }
    
    // The Attribution Token when ATTrackingManager.AuthorizationStatus is in any status
    static func attributionToken() -> String? {
        return UserDefaults.standard.value(forKey: "com.kitemetrics.attributionToken") as? String
    }
    
    static func setAttributionTokenWithAuthorization(_ attributionTokenString: String) {
        UserDefaults.standard.set(attributionTokenString, forKey: "com.kitemetrics.attributionTokenWithAuthorization")
    }
    
    // The Attribution Token when ATTrackingManager.AuthorizationStatus == .authorized
    static func attributionTokenWithAuthorization() -> String? {
        return UserDefaults.standard.value(forKey: "com.kitemetrics.attributionTokenWithAuthorization") as? String
    }
    
    static func setAttributionTokenTimestamp() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "com.kitemetrics.attributionTokenTimestamp")
    }
    
    static func attributionTokenTimestamp() -> TimeInterval? {
        return UserDefaults.standard.value(forKey: "com.kitemetrics.attributionTokenTimestamp") as? TimeInterval
    }

}
