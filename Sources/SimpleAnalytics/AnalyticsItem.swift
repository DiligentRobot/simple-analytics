//
//  AnalyticsItem.swift
//  App Analytics
//
//  Created by Dennis Birch on 3/20/21.
//

import Foundation

struct AnalyticsItem: Hashable, Codable {
    public static func == (lhs: AnalyticsItem, rhs: AnalyticsItem) -> Bool {
        return lhs.eventName == rhs.eventName &&
            lhs.timestamp == rhs.timestamp
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(eventName.hashValue & timestamp.hashValue)
    }
    
    let timestamp: Date
    let eventName: String
    let sessionID: String
    let eventDetails: [String : String]?
    let deviceID: String
    let appName: String
    let appVersion: String
    let systemVersion: String
    let platform: String
    let userProps: [String: String]

    
    enum CodingKeys: String, CodingKey {
        case eventName
        case timestamp
        case sessionID
        case eventDetails
        case deviceID
        case appName
        case appVersion
        case systemVersion
        case platform
        case userProps
    }
    
    init(timestamp: Date, eventName: String, eventDetails: [String : String]?, sessionID: String, deviceID: String, appName: String, appVersion: String, platform: String, systemVersion: String, userProps: [String: String]) {
        self.timestamp = timestamp
        self.eventName = eventName
        self.eventDetails = eventDetails
        self.sessionID = sessionID
        self.deviceID = deviceID
        self.appName = appName
        self.appVersion = appVersion
        self.platform = platform
        self.systemVersion = systemVersion
        self.userProps = userProps
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        eventName = try values.decode(String.self, forKey: .eventName)
        let dateString = try values.decode(String.self, forKey: .timestamp)
        timestamp = dateString.dateFromISOString() ?? Date()
        eventDetails = try values.decodeIfPresent([String : String].self, forKey: .eventDetails)
        sessionID = try values.decode(String.self, forKey: .sessionID)
        deviceID = try values.decode(String.self, forKey: .deviceID)
        appName = try values.decode(String.self, forKey: .appName)
        appVersion = try values.decode(String.self, forKey: .appVersion)
        platform = try values.decode(String.self, forKey: .platform)
        systemVersion = try values.decode(String.self, forKey: .systemVersion)
        userProps = try values.decode([String: String].self, forKey: .userProps)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventName, forKey: .eventName)
        try container.encode(timestamp.toISOString(), forKey: .timestamp)
        if let eventDetails = self.eventDetails {
            try container.encode(eventDetails, forKey: .eventDetails)
        }
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(deviceID, forKey: .deviceID)
        try container.encode(appName, forKey: .appName)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(platform, forKey: .platform)
        try container.encode(systemVersion, forKey: .systemVersion)
        try container.encode(userProps, forKey: .userProps)
    }
}

extension Date {
    func toISOString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
}

extension String {
    func dateFromISOString() -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: self)
    }
}
