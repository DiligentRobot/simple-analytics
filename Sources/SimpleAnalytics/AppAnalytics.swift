//
//  AppAnalytics.swift
//  App Analytics
//
//  Created by Dennis Birch on 3/20/21.
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import os.log

@objc public class AppAnalytics: NSObject {
    // MARK: - Public & Accessible Properties

    /// Getter for the count of all active items to be submitted.
    @objc public static var itemCount: Int {
        return shared.items.count
    }
    
    /// Property defining an increment value to be added to the maximum number of items to accumulate before submitting to your service. To add a delay before attempting to reach your server again, this value is automatically added to the *maxItemCount* if a submission fails so that the next item added does not prompt another submission. If desired, you can adjust this value with by calling the `setSubmitFailureIncrement` function.
    var maxCountResetValue = 20
    
    /// The value used to set the maximum number of items to accumulate before submitting items to your service. If the *maxItemCount* has been increased because of submission failures, it is reset to this base value upon the next successful submission. You can adjust this value by calling the `setMaximumItemCount` method
    private var baseItemCount = 100
    
    /// Property defining the time which should be considered idle for ending a session automatically if no actions are taken Default value is 600
    @objc public var sessionTimeoutValue: TimeInterval = 600
    
    // MARK: - Private Properties
    
    private(set) var items = [AnalyticsItem]()
    
    /// An instance of a type that conforms to the `AnalyticsSubmitting` protocol. This has internal scope to allow testing. An instance of the `AnalyticsSubmitter` struct is used automatically unless this property has been set to something else.
    var submitter: AnalyticsSubmitting?
    
    private var maxItemCount = 0

    var endpoint: String = ""
    var appName: String
    var appVersion: String
    var platform: String
    private var deviceID: String
    private var systemVersion: String
    private var shouldSubmitAtAppDismiss = true

    private var userProps: [String: String] = [:]
    
    private static var shared = AppAnalytics()
    private static let persistenceFileName = "PersistedAnalytics"
    
    #if os(iOS)
    private var backgroundTaskID = UIBackgroundTaskIdentifier(rawValue: 5000)
    #endif
    
    private var sessionID: String?

    private var sessionStartTime: Date?
    
    private var idleTimer: Timer?
    
    // MARK: - Public Methods
    
    // MARK: - Recording analytics data
    
    /// Static method to add an item to record
    /// - Parameters:
    ///   - description: String describing the action or user interaction
    ///   - params: An optional String:String dictionary of additional details to record (e.g. certain app state observations) for more refined analysis
    @objc public static func addItem(_ eventName: String, eventDetails: [String : String] = [:]) {
        shared.addAnalyticsItem(eventName, eventDetails: eventDetails)
    }

    @objc public static func addUserProp(key: String, value: String) {
        shared.userProps[key] = value
    }

    
    // MARK: - Configuring output and behavior
    
    /// Static method to set the *endPoint* property
    /// - Parameter urlString: String for the endpoint's URL
    @objc public static func setEndpoint(_ urlString: String) {
        shared.endpoint = urlString
    }
    
    /// A static method to set the *platform* property
    /// - Parameter platformName: String with a platform name. The framework automatically assigns the values *iOS* and *macOS* for those platforms, but if your app is running in a hybrid environment (e.g. iOS app running on Mac), you can override that assignment with this method.
    @objc public static func setPlatform(_ platformName: String) {
        shared.platform = platformName
    }
    
    /// A static method to change the base count for maximum number of items to accumulate
    /// - Parameter count: Int defining the base maximum number of items to accumulate before attempting to submit them to your server. The default value is 100. This number is incremented by the value of the *maxCountResetValue* property in cases of submissions failing.
    @objc public static func setMaxItemCount(_ count: Int) {
        shared.setMaxCount(count)
    }
    
    /// A static method to change the value of the property added to the maximum count after a submission failure.
    /// - Parameter increment: Int defining the amount to be added to the maximum item count before again attempting to submit entries. This value is used when a submission fails to add a delay before again attempting to reach your server.
    @objc public static func setSubmitFailureIncrement(_ increment: Int) {
        shared.maxCountResetValue = increment
    }
    
    /// A static method to allow overriding the *submitAtDismiss* functionality
    /// - Parameter shouldSubmit: AppAnalytics listens for *appWillResign* and *appWillTerminate* notifications. It responds to those when possible by attempting to submit current entries. If you want to override that behavior, you can call this method with an argument of *false*, or re-enable it with an argument of *true*.
    @objc public static func overrideSubmitAtDismiss(shouldSubmit: Bool) {
        shared.shouldSubmitAtAppDismiss = shouldSubmit
    }
    
    // MARK: - Submitting data and persistence support
    
    /// A static method to trigger submission of collected analytics
    ///
    /// **NOTE**: The framework automatically submits analytics to the server when sufficient numbers have accumulated. You may want to arbitrarily submit entries at other times with this method.
    @objc public static func submitNow() {
        shared.clearAndSubmitItems()
    }
    
    /// A static method to write current contents to disk.
    ///
    /// This method can be called from your app to capture the current analytics values. It should probably only be used when the app is being backgrounded or terminated, and in that case with the *shouldSubmitAtAppDismiss* value set to false to avoid duplicating entries.
    @objc public static func persistContents() {
        let fileMgr = FileManager()
        let url = fileMgr.temporaryDirectory.appendingPathComponent(persistenceFileName)
        if fileMgr.fileExists(atPath: url.path) {
            try? fileMgr.removeItem(at: url)
        }
        let model = PersistenceModel(items: shared.items)
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(model)
            do {
                try data.write(to: url, options: .atomicWrite)
            } catch {
                SimpleAnalytics.debugLog("Error writing persistence file to temporary directory: %@", error.localizedDescription)
            }
        } catch {
            SimpleAnalytics.debugLog("Error encoding persistence model: %@", error.localizedDescription)
        }
    }
    
    /// A static method to restore values persisted with the `persistContents` method
    ///
    /// This method can be called from your app to restore values persisted to disk. It should probably only be called when the app is being activated, and in that case with the *shouldSubmitAtAppDismiss* value set to false to avoid duplicating entries.
    @objc public static func restorePersistenceContents() {
        let fileMgr = FileManager()
        let url = fileMgr.temporaryDirectory.appendingPathComponent(persistenceFileName)
        let path = url.path
        if fileMgr.fileExists(atPath: path) == false { return }
        do {
            let data = try Data(contentsOf: url)
            try? fileMgr.removeItem(at: url)
            let decoder = JSONDecoder()
            do {
                let model = try decoder.decode(PersistenceModel.self, from: data)
                let items = model.items
                if items.isEmpty == false {
                    let itemsHash = items.hashValue
                    if itemsHash != shared.items.hashValue {
                        shared.items.insert(contentsOf: items, at: 0)
                    }
                }
            } catch {
                SimpleAnalytics.debugLog("Error decoding persisted model data: %@", error.localizedDescription)
            }
        } catch {
            SimpleAnalytics.debugLog("Error reading persisted analytics file: %@", error.localizedDescription)
        }
    }
    
    @objc public func startSession() {
        sessionStartTime = Date()
        sessionID = UUID().uuidString
        resetTimer()
    }
    
    @objc public func endSession() {
        // TODO: Optional log session ended?
        sessionID = nil
        sessionStartTime = nil
        idleTimer?.invalidate()
    }
    
    // MARK: - Internal & Private Methods
    // MARK: - 
    
    init(endpoint: String = "", appName: String = "", applicationVersion: String = "") {
        self.endpoint = endpoint

        var name = appName
        if appName.isEmpty == true {
            if let info = Bundle.main.infoDictionary {
                if let bundleName = info["CFBundleName"] as? String {
                    name = bundleName
                }
            }
        }
        if name.isEmpty == true {
            name = "App name N/A"
        }
      
        self.appName = name

        var version = applicationVersion
        if version.isEmpty == true {
            if let info = Bundle.main.infoDictionary {
                if let bundleName = info["CFBundleVersion"] as? String {
                    version = bundleName
                }
            }
        }
        if version.isEmpty == true {
            name = "App version N/A"
        }
        
        self.appVersion = version

        let analyticsID = "App Analytics Identifier"
        if let identifier = UserDefaults.standard.string(forKey: analyticsID) {
            self.deviceID = identifier
        } else {
            let identifier = UUID().uuidString
            UserDefaults.standard.set(identifier, forKey: analyticsID)
            self.deviceID = identifier
        }
        
        maxItemCount = baseItemCount
        
        #if os(iOS)
        let deviceType: String
        if UIDevice.current.userInterfaceIdiom == .phone {
            deviceType = "iPhone"
        } else {
            deviceType = "iPad"
        }
        platform = "iOS (\(deviceType))"
        systemVersion = UIDevice.current.systemVersion

        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(receivedDismissNotification(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivedDismissNotification(_:)), name: UIApplication.willTerminateNotification, object: nil)
        #elseif os(macOS)
        platform = "macOS"
        let vers = ProcessInfo().operatingSystemVersion
        systemVersion = "\(vers.majorVersion).\(vers.minorVersion).\(vers.patchVersion)"
        userProps = [:]
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(receivedDismissNotification(_:)), name: NSApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivedDismissNotification(_:)), name: NSApplication.willTerminateNotification, object: nil)
        #endif
    }
    
    func addAnalyticsItem(_ eventName: String, eventDetails: [String : String] = [:]) {
        // If there's no active session, start one
        if sessionID == nil {
            startSession()
        }
        // Reset the idle timer
        resetTimer()
        let sessionID = self.sessionID!
        let item = AnalyticsItem(timestamp: Date(),
                                 eventName: eventName,
                                 eventDetails: eventDetails,
                                 sessionID: sessionID,
                                 deviceID: deviceID,
                                 appName: appName,
                                 appVersion: appVersion,
                                 platform: platform,
                                 systemVersion: systemVersion,
                                 userProps: userProps)
        items.append(item)
    
        let total = items.count
        if total >= maxItemCount {
            // submit and clear items if successful or otherwise restore items
            clearAndSubmitItems()
        }
    }
    
    func setMaxCount(_ count: Int) {
        baseItemCount = count
        maxItemCount = baseItemCount
    }
    
    func clearAndSubmitItems() {
        let items = self.items
        
        guard items.isEmpty == false else {
            SimpleAnalytics.debugLog("Nothing to submit")
            #if os(iOS)
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
            #endif
            return
        }

        let submitter = self.submitter ?? AnalyticsSubmitter(endpoint: endpoint)
        self.submitter = submitter

        self.items.removeAll()

        DispatchQueue.global().async { [weak self] in
            self?.submitItems(items, with: submitter)
        }
    }
    
    private func submitItems(_ items: [AnalyticsItem], with submitter: AnalyticsSubmitting) {
        submitter.submitItems(items, successHandler: { [weak self] message in
            DispatchQueue.main.async {
                SimpleAnalytics.debugLog("Success submitting analytics: %@", message)
                if let base = self?.baseItemCount {
                    self?.maxItemCount = base
                }
            }
            #if os(iOS)
            if let task = self?.backgroundTaskID,
               task != .invalid {
                UIApplication.shared.endBackgroundTask(task)
            }
            #endif
        }) { [weak self] (errorItems) in
            // restore to respective properties
            DispatchQueue.main.async {
                SimpleAnalytics.debugLog("Analytics submission failed. Restoring items.")
                self?.resetItems(errorItems)
                #if os(iOS)
                if let task = self?.backgroundTaskID,
                   task != .invalid {
                    UIApplication.shared.endBackgroundTask(task)
                }
                #endif
            }
        }
    }
    
    private func resetItems(_ items: [AnalyticsItem]) {
        self.items.insert(contentsOf: items, at: 0)
        
        // add to maxCount so there's a delay before retrying
        let resetValue = self.maxCountResetValue
        self.maxItemCount += resetValue
    }
    
    private func resetTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: sessionTimeoutValue, repeats: false, block: { _ in
            self.endSession()
        })
    }
    
    @objc private func receivedDismissNotification(_ notification: Notification) {
        endSession()
        if shouldSubmitAtAppDismiss == true {
            #if os(iOS)
            backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Submit Analytics Data", expirationHandler: { [weak self] in
                if let task = self?.backgroundTaskID {
                    UIApplication.shared.endBackgroundTask(task)
                    self?.backgroundTaskID = .invalid
                }
            })
            DispatchQueue.main.async { [weak self] in
                self?.clearAndSubmitItems()
            }
            #elseif os(macOS)
            DispatchQueue.main.async { [weak self] in
                self?.clearAndSubmitItems()
            }
            #endif
        }
    }
}


struct PersistenceModel: Codable {
    let items: [AnalyticsItem]
}
