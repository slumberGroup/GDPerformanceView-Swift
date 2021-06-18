//
//  KMDevice.swift
//  Kitemetrics
//
//  Created by Kitemetrics on 10/21/16.
//  Copyright © 2021 Kitemetrics. All rights reserved.
//

import Foundation
import AdSupport
import UIKit


public enum KMDevice {
    
    //The build-version-number string for the bundle
    public static func appBuildVersion() -> String {
        return stringValueFromInfoDict(kCFBundleVersionKey as String)
    }
    
    // The release-version-number string for the bundle.
    public static func appVersion() -> String {
        return stringValueFromInfoDict("CFBundleShortVersionString")
    }
    
    //The user-visible name of the bundle; used by Siri and visible on the Home screen in iOS.
    public static func appBundleDisplayName() -> String {
        return stringValueFromInfoDict("CFBundleDisplayName")
    }
    
    //The human-readable name of the bundle.  This key is often found in the InfoPlist.strings since it is usually localized.
    public static func appBundleName() -> String {
        return stringValueFromInfoDict(kCFBundleNameKey as String)
    }
    
    //An identifier string that specifies the app type of the bundle. The string should be in reverse DNS format.
    public static func appBundleId() -> String {
        return stringValueFromInfoDict(kCFBundleIdentifierKey as String)
    }
    
    public static func advertisingIdentifier() -> String {
        let identifierManager = ASIdentifierManager.shared()
        if identifierManager.isAdvertisingTrackingEnabled {
            let identifier = identifierManager.advertisingIdentifier
            return identifier.uuidString
        }
        
        return ""
    }
    
    static func stringValueFromInfoDict(_ key: String) -> String {
        let dict = Bundle.main.infoDictionary
        if dict != nil {
            let value = dict![key]
            if value == nil {
                return ""
            } else {
                guard let val = value as? String else {
                    return ""
                }
                return val
            }
        }
        
        return ""
    }
    
    //e.g. Version 10.0 (Build 14A345)
    public static func iosVersion() -> String {
        return ProcessInfo.processInfo.operatingSystemVersionString
    }

    
    public static func deviceType() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        guard let deviceType = NSString(bytes: &systemInfo.machine, length: Int(_SYS_NAMELEN), encoding: String.Encoding.ascii.rawValue) as String? else {
            return KMDevice.model()
        }
        return deviceType
    }
    
    //e.g. iPhone
    static func model() -> String {
        return UIDevice.current.model
    }
    
    //e.g. en
    public static func preferredLanguage() -> String {
        if Locale.preferredLanguages.count > 0 {
            return Locale.preferredLanguages[0]
        }
        return ""
    }
    
    //e.g. US
    public static func regionCode() -> String {
        guard let regionCode = Locale.current.regionCode else {
            return ""
        }
        return regionCode
    }
    
    //e.g. iOS
    static func systemName() -> String {
        return UIDevice.current.systemName
    }
    
    //e.g. 10.0
    static func systemVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    //e.g. 744643BA-0BB4-469F-BD23-7BC5AF3A708E
    public static func identifierForVendor() -> String {
        guard let uuid = UIDevice.current.identifierForVendor else {
            return ""
        }
        return uuid.uuidString
    }
    
}
