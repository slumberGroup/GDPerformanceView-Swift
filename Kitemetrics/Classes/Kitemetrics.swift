//
//  Kitemetrics.swift
//  Pods
//
//  Created by Kitefaster on 10/18/16.
//  Copyright © 2018 Kitefaster, LLC. All rights reserved.
//

import StoreKit
import AdSupport
import iAd

///Kitemetrics iOS Client SDK
@objc
public class Kitemetrics: NSObject {

    ///Kitemetrics singleton
    @objc
    public static let shared = Kitemetrics()
    
    static let kServer = "https://cloud.kitemetrics.com:443"
    static let kAPI = "/api/v1/"
    static let kApplications = "applications"
    static let kDevices = "devices"
    static let kVersions = "versions"
    static let kSessions = "sessions"
    static let kEvents = "events"
    static let kEventSignUps = "eventSignUps"
    static let kEventInvites = "eventInvites"
    static let kEventRedeemInvites = "eventRedeemInvites"
    static let kErrors = "errors"
    static let kPurchases = "purchases"
    static let kAttributions = "attributions"
    static let kAPIKey = "apiKey"
    static let kApplicationsEndpoint = kServer + kAPI + kApplications
    static let kDevicesEndpoint = kServer + kAPI + kDevices
    static let kVersionsEndpoint = kServer + kAPI + kVersions
    static let kSessionsEndpoint = kServer + kAPI + kSessions
    static let kEventsEndpoint = kServer + kAPI + kEvents
    static let kEventSignUpsEndpoint = kServer + kAPI + kEventSignUps
    static let kEventInviteEndpoint = kServer + kAPI + kEventInvites
    static let kEventRedeemInviteEndpoint = kServer + kAPI + kEventRedeemInvites
    static let kErrorsEndpoint = kServer + kAPI + kErrors
    static let kPurchasesEndpoint = kServer + kAPI + kPurchases
    static let kAttributionsEndpoint = kServer + kAPI + kAttributions
    
    static let kMaxSearchAdAttributionAttempts = 1000
    static let kAttributionTryAgainSeconds = TimeInterval(2)
    
    var apiKey: String = ""
    public var userIdentifier: String = ""
    let sessionManager = KMSessionManager()
    let queue = KMQueue()
    let timerManager = KMTimerManager()
    var currentBackoffMultiplier = 1
    var currentBackoffValue = 1
    
    private override init() {
        super.init()
        KMLog.p("Kitemetrics shared instance initialized!")
        sessionManager.delegate = self
    }
    
    @objc
    public func initSession(apiKey: String) {
        initSession(apiKey: apiKey, userIdentifier: "")
    }
    
    ///Call on app startup, preferablly in AppDelegate application(_:didFinishLaunchingWithOptions:)
    ///- parameter apiKey: Obtain the apiKey from https://cloud.kitemetrics.com
    ///- parameter userIdentifier: Optional.  This is used for tracking the number of active users.  Do not use Personally Identifiable Information (e.g. email addresses, phone numbers, full name, social security numbers, etc).
    @objc
    public func initSession(apiKey: String, userIdentifier: String) {
        KMLog.p("Kitemetrics shared instance initialized with apiKey!")
        self.apiKey = apiKey
        
        var uid = userIdentifier
        if uid != "" {
            if isEmailAddress(inputString: uid) {
                KMError.printError("Do not use Personally Identifiable Information (e.g. email addresses, phone numbers, full name, social security numbers, etc) as the userIdentifier.")
                uid = ""
            } else {
                self.userIdentifier = uid
            }
        } else {
            let lastVersion = KMUserDefaults.lastVersion()
            if lastVersion != nil && lastVersion!["userIdentifier"] != "" {
                self.userIdentifier = lastVersion!["userIdentifier"]!
            }
        }
        
        appLaunch()
    }

    func isEmailAddress(inputString: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        
        let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: inputString)
    }
    
    func appLaunch() {
        KMLog.p("App Launch")
        let lastVersion = KMUserDefaults.lastVersion()
        let currentVersion = KMHelper.versionDict()
        
        if lastVersion == nil {
            //This is a new install or a reinstall
            postApplication()
            postDevice()
            postVersion(currentVersion, installType: KFInstallType.newInstall)
            KMUserDefaults.setNeedsSearchAdsAttribution(true)
            KMUserDefaults.setLastVersion(currentVersion)
            KMUserDefaults.setLastAttemptToSendErrorQueue(Date())
            KMUserDefaults.setInstallDate(date: Date())
        } else if lastVersion! != currentVersion {
            KMUserDefaults.setVersionId(kitemetricsVersionId: nil)
            if lastVersion!["appVersion"] != currentVersion["appVersion"] {
                postVersion(currentVersion, installType: KFInstallType.appVersionUpdate)
            } else if lastVersion!["userIdentifier"] != currentVersion["userIdentifier"] {
                postVersion(currentVersion, installType: KFInstallType.userChange)
            } else if lastVersion!["osVersion"] != currentVersion["osVersion"] || lastVersion!["osCountry"] != currentVersion["osCountry"] || lastVersion!["osLanguage"] != currentVersion["osLanguage"] {
                postVersion(currentVersion, installType: KFInstallType.osChange)
            } else {
                postVersion(currentVersion, installType: KFInstallType.unknown)
            }
            KMUserDefaults.setLastVersion(currentVersion)
        }
        
        self.queue.startSending()
        self.timerManager.performForegroundActions()
        
        if #available(iOS 10, *) {
            if KMUserDefaults.needsSearchAdsAttribution() {
                //Number of days since install
                let installDate = KMUserDefaults.installDate()
                let diff = Date().timeIntervalSince1970 - installDate.timeIntervalSince1970
                if diff > 31557600 {
                    //If it has been more than 1 year since install and we still haven't retrieved attribution data.  It is no longer available.  Stop trying.
                    KMUserDefaults.setNeedsSearchAdsAttribution(false)
                } else {
                    //Click Latency
                    //Most users that click on a Search Ads impression immediately download the app. When the app is opened immediately and the
                    //Search Ads Attribution API is called, the corresponding ad click might not have been processed by our system yet due to some
                    //latency. We recommend setting a delay of a few seconds before retrieving attribution data.
                    //Source: https://searchads.apple.com/v/advanced/help/b/docs/pdf/attribution-api.pdf
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.postSearchAdsAttribution()
                    }
                }
            } else {
                if KMUserDefaults.attributionDate() == nil && KMUserDefaults.attributionClientVersionId() == 0 && KMUserDefaults.attributionRequestAttemptNumber() < Kitemetrics.kMaxSearchAdAttributionAttempts {
                    if ASIdentifierManager.shared().isAdvertisingTrackingEnabled == false {
                        KMUserDefaults.setAttributionDate()
                    } else {
                        //Resend attribution
                        self.postSearchAdsAttribution()
                    }
                    
                }
            }
        }
    }
    
    func postApplication() {
        var request = URLRequest(url: URL(string: Kitemetrics.kApplicationsEndpoint)!)
        guard let json = KMHelper.applicationJson() else {
            return
        }
        request.httpBody = json
        self.queue.addItem(item: request)
    }
    
    func postDevice() {
        var request = URLRequest(url: URL(string: Kitemetrics.kDevicesEndpoint)!)
        guard let json = KMHelper.deviceJson() else {
            return
        }
        request.httpBody = json
        self.queue.addItem(item: request)
    }
    
    func postVersion(_ versionDict: [String: Any], installType: KFInstallType) {
        var modifiedVersionDict = versionDict
        modifiedVersionDict["timestamp"] = Date().timeIntervalSince1970
        modifiedVersionDict["installType"] = installType.rawValue
        
        if let applicationId = KMUserDefaults.applicationId() {
            if applicationId > 0 {
                modifiedVersionDict["applicationId"] = applicationId
            } else {
                modifiedVersionDict["bundleId"] = KMDevice.appBundleId()
            }
        }

        let deviceId = KMUserDefaults.deviceId()
        if deviceId > 0 {
            modifiedVersionDict["deviceId"] = deviceId
        } else {
            modifiedVersionDict["deviceIdForVendor"] = KMDevice.identifierForVendor()
        }

        var request = URLRequest(url: URL(string: Kitemetrics.kVersionsEndpoint)!)
        guard let json = KMHelper.jsonFromDictionary(modifiedVersionDict) else {
            return
        }
        request.httpBody = json
        
        self.queue.addItem(item: request)
    }
    
    ///Log a custom event.
    ///- parameter eventName: Max size of 255
    @objc
    public func logEvent(_ eventName: String) {
        postEvent(eventName)
    }
    
    func postEvent(_ event: String) {
        if event.count > 255 {
            KMError.printError("Length of event must be less than 256 characters. Truncating.")
        }
        var request = URLRequest(url: URL(string: Kitemetrics.kEventsEndpoint)!)
        guard let json = KMHelper.eventJson(event) else {
            return
        }
        request.httpBody = json
        
        self.queue.addItem(item: request)
    }
    
    ///Log when a user signs up or creates an account.
    ///- parameter method: The method used to sign up (e.g. Facebook, Google, Email)
    ///- parameter userIdentifier: This is used for tracking the number of active users.  Do not use Personally Identifiable Information (e.g. email addresses, phone numbers, full name, social security numbers, etc).
    @objc
    public func logSignUp(method: String, userIdentifier: String) {
        if method.count > 255 {
            KMError.printError("Length of method must be less than 256 characters. Truncating.")
        }
        if userIdentifier.count == 0 {
            KMError.printError("Length of userIdentifier must be greater than 0 characters.")
            return
        }
        if userIdentifier.count > 255 {
            KMError.printError("Length of userIdentifier must be less than 256 characters. Truncating.")
        }
        
        if isEmailAddress(inputString: userIdentifier) {
            KMError.printError("Do not use Personally Identifiable Information (e.g. email addresses, phone numbers, full name, social security numbers, etc) as the userIdentifier.")
            return
        }

        //Create a new version first
        Kitemetrics.shared.userIdentifier = userIdentifier
        let currentVersion = KMHelper.versionDict()
        KMUserDefaults.setLastVersion(currentVersion)
        postVersion(currentVersion, installType: KFInstallType.userChange)
        
        var request = URLRequest(url: URL(string: Kitemetrics.kEventSignUpsEndpoint)!)
        guard let json = KMHelper.eventSignUpJson(method: method, userIdentifier: userIdentifier) else {
            return
        }
        request.httpBody = json
        
        self.queue.addItem(item: request)
    }
    
    ///Log when a user shares or invites someone to use the app.
    ///- parameter method: The method used to send the invite (e.g. Facebook, Twitter, Email, Text)
    ///- parameter code: Optional. Referral or other invite code used.
    @objc
    public func logInvite(method: String, code: String? = nil) {
        if method.count > 255 {
            KMError.printError("Length of method must be less than 256 characters. Truncating.")
        }
        
        if code != nil && code!.count > 255 {
            KMError.printError("Length of code must be less than 256 characters. Truncating.")
        }
        
        var request = URLRequest(url: URL(string: Kitemetrics.kEventInviteEndpoint)!)
        guard let json = KMHelper.eventInviteJson(method: method, code: code) else {
            return
        }
        request.httpBody = json
        
        self.queue.addItem(item: request)
    }
    
    ///Log when a user redeems an invite code.
    ///- parameter code: Referral or other invite code used.
    @objc
    public func logRedeemInvite(code: String) {
        if code.count > 255 {
            KMError.printError("Length of code must be less than 256 characters. Truncating.")
        }
        
        var request = URLRequest(url: URL(string: Kitemetrics.kEventRedeemInviteEndpoint)!)
        guard let json = KMHelper.eventRedeemInviteJson(code: code) else {
            return
        }
        request.httpBody = json
        
        self.queue.addItem(item: request)
    }
    
    ///Log an error message
    ///- errorMessage: Max size of 1000
    @objc
    public func logError(_ errorMessage: String) {
        postError(errorMessage, isInternal: false)
    }
    
    func postError(_ error: String, isInternal: Bool) {
        if error.count > 1000 {
            KMError.printError("Length of error must be less than 1000 characters. Truncating.")
        }
        
        var request = URLRequest(url: URL(string: Kitemetrics.kErrorsEndpoint)!)
        guard let json = KMHelper.errorJson(error, isInternal: isInternal) else {
            return
        }
        request.httpBody = json
        
        self.queue.addItem(item: request)
    }
    
    ///Log when a user adds an in-app item to their cart
    @objc
    public func logInAppAddToCart(_ product: SKProduct, quantity: Int, purchaseType: KFPurchaseType = .unknown) {
        var request = URLRequest(url: URL(string: Kitemetrics.kPurchasesEndpoint)!)
        guard let json = KMHelper.inAppPurchaseJson(product, quantity: quantity, funnel: KFPurchaseFunnel.addToCart, purchaseType: purchaseType) else {
            return
        }
        request.httpBody = json
        
        self.queue.addItem(item: request)
    }
    
    ///Log when a user adds an item to their cart
    @objc
    public func logAddToCart(productIdentifier: String, price: Decimal, currencyCode: String, quantity: Int, purchaseType: KFPurchaseType) {
        var request = URLRequest(url: URL(string: Kitemetrics.kPurchasesEndpoint)!)
        guard let json = KMHelper.purchaseJson(productIdentifier: productIdentifier, price: price, currencyCode: currencyCode, quantity: quantity, funnel: KFPurchaseFunnel.addToCart, purchaseType: purchaseType) else {
            return
        }
        request.httpBody = json
        
        self.queue.addItem(item: request)
    }
    
    ///Log when a user completes an in-app purchase
    @objc
    public func logInAppPurchase(_ product: SKProduct, quantity: Int) {
        logInAppPurchase(product, quantity:quantity, purchaseType: KFPurchaseType.unknown)
    }
    
    ///Log when a user completes an in-app purchase
    @objc
    public func logInAppPurchase(_ product: SKProduct, quantity: Int, purchaseType: KFPurchaseType) {
        var request = URLRequest(url: URL(string: Kitemetrics.kPurchasesEndpoint)!)
        guard let json = KMHelper.inAppPurchaseJson(product, quantity: quantity, funnel: KFPurchaseFunnel.purchase, purchaseType: purchaseType) else {
            return
        }
        request.httpBody = json
        
        self.queue.addItem(item: request)
    }
    
    ///Log when a user completes a purchase
    @objc
    public func logPurchase(productIdentifier: String, price: Decimal, currencyCode: String, quantity: Int, purchaseType: KFPurchaseType) {
        var request = URLRequest(url: URL(string: Kitemetrics.kPurchasesEndpoint)!)
        guard let json = KMHelper.purchaseJson(productIdentifier: productIdentifier, price: price, currencyCode: currencyCode, quantity: quantity, funnel: KFPurchaseFunnel.purchase, purchaseType: purchaseType) else {
            return
        }
        request.httpBody = json
        
        self.queue.addItem(item: request)
    }
    
    @objc
    public func logPurchaseFunnel(productIdentifier: String, price: Decimal, currencyCode: String, quantity: Int, funnel: KFPurchaseFunnel, purchaseType: KFPurchaseType, expiresDate: Date? = nil, webOrderLineItemId: String = "") {
        var request = URLRequest(url: URL(string: Kitemetrics.kPurchasesEndpoint)!)
        guard let json = KMHelper.purchaseJson(productIdentifier: productIdentifier, price: price, currencyCode: currencyCode, quantity: quantity, funnel: funnel, purchaseType: purchaseType, expiresDate: expiresDate, webOrderLineItemId: webOrderLineItemId) else {
            return
        }
        request.httpBody = json
        
        self.queue.addItem(item: request)
    }
    
    @available(iOS 10, *)
    func postSearchAdsAttribution() {
        let attemptNumber = KMUserDefaults.incrementAttributionRequestAttemptNumber()
        KMLog.p("Requesting attribution details attempt # " + String(attemptNumber))
        ADClient.shared().requestAttributionDetails({ (attributionDetails: [String : NSObject]?, error: Error?) in
            KMLog.p("Requesting attribution details responded.")
            if error != nil {
                let adClientError = error as? ADClientError
                if adClientError != nil {
                    if adClientError!.code == ADClientError.limitAdTracking {
                        KMLog.p("Limit ad tracking is turned on.  ADClientError.limitAdTracking")
                        KMUserDefaults.setNeedsSearchAdsAttribution(false)
                        KMUserDefaults.setAttributionDate()
                    } else {
                        //Apple Search Ads error.  Retry.
                        if attemptNumber < Kitemetrics.kMaxSearchAdAttributionAttempts {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Kitemetrics.kAttributionTryAgainSeconds) {
                                self.postSearchAdsAttribution()
                            }
                        } else {
                            //Cap retries for click latency
                            KMUserDefaults.setNeedsSearchAdsAttribution(false)
                        }
                        KMError.logError(error!)
                    }
                } else {
                    if ASIdentifierManager.shared().isAdvertisingTrackingEnabled == false {
                        KMLog.p("Limit ad tracking is turned on.  isAdvertisingTrackingEnabled == false")
                        KMUserDefaults.setNeedsSearchAdsAttribution(false)
                        KMUserDefaults.setAttributionDate()
                    } else {
                        //Apple Search Ads error.  Retry.
                        if attemptNumber < Kitemetrics.kMaxSearchAdAttributionAttempts {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Kitemetrics.kAttributionTryAgainSeconds) {
                                self.postSearchAdsAttribution()
                            }
                        } else {
                            //Cap retries
                            KMUserDefaults.setNeedsSearchAdsAttribution(false)
                        }
                        KMError.logError(error!)
                    }
                }
            } else if attributionDetails != nil {
                let attribution = attributionDetails!["Version3.1"]
                if attribution != nil {
                    let a = attribution! as! [String : Any]
                    
                    if a["iad-attribution"] != nil && a["iad-attribution"] as? String == "false" {
                        // do nothing
                    } else if (a["iad-campaign-name"] == nil || a["iad-campaign-name"] as! String == "") && (a["iad-org-name"] == nil || a["iad-org-name"] as! String == "") && (a["iad-keyword"] == nil || a["iad-keyword"] as! String == "") {
                        //Empty.  Try again in a few seconds.
                        if attemptNumber < Kitemetrics.kMaxSearchAdAttributionAttempts {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Kitemetrics.kAttributionTryAgainSeconds) {
                                self.postSearchAdsAttribution()
                            }
                        } else {
                            //Cap retries
                            KMUserDefaults.setNeedsSearchAdsAttribution(false)
                        }

                        return
                    }
                }

                guard let jsonData = KMHelper.jsonFromDictionary(attributionDetails!) else {
                    return
                }
                self.postAttribution(jsonData)
                KMUserDefaults.setNeedsSearchAdsAttribution(false)
                KMUserDefaults.setAttribution(attributionDetails!)
            } else {
                KMError.logErrorMessage("nil attribuiton and nil error.")
            }
        })
    }

    
    func postAttribution(_ attribuiton: Data) {
        var request = URLRequest(url: URL(string: Kitemetrics.kAttributionsEndpoint)!)
        request.httpBody = attribuiton
        
        self.queue.addItem(item: request)
        self.timerManager.fireTimerManually()
    }
    
    @objc
    public func kitemetricsDeviceId() -> Int {
        return KMUserDefaults.deviceId()
    }
}

extension Kitemetrics: KMSessionManagerDelegate {
    
    func sessionReadyToPost(launchTime: Date, closeTime: Date) {
        var request = URLRequest(url: URL(string: Kitemetrics.kSessionsEndpoint)!)
        request.httpBody = KMHelper.sessionJson(launchTime: launchTime, closeTime: closeTime)
        
        self.queue.addItem(item: request)
    }
    
}
