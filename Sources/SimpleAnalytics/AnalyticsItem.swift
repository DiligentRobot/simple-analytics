//
//  AnalyticsItem.swift
//  App Analytics
//
//  Created by Dennis Birch on 3/20/21.
//

import Foundation

struct AnalyticsItem: Hashable, Codable {
    public static func == (lhs: AnalyticsItem, rhs: AnalyticsItem) -> Bool {
        return lhs.description == rhs.description &&
            lhs.timestamp == rhs.timestamp
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(description.hashValue & timestamp.hashValue)
    }
    
    let timestamp: Date
    let description: String
    let sessionID: String
    let parameters: [String : String]?
    let deviceID: String
    let appName: String
    let appVersion: String
    let systemVersion: String
    let platform: String
    let userProps: [String: String]

    
    enum CodingKeys: String, CodingKey {
        case description
        case timestamp
        case sessionID
        case parameters
        case deviceID = "device_id"
        case appName = "app_name"
        case appVersion = "app_version"
        case systemVersion = "system_version"
        case platform
        case userProps
    }
    
    init(timestamp: Date, description: String, parameters: [String : String]?, sessionID: String, deviceID: String, appName: String, appVersion: String, platform: String, systemVersion: String, userProps: [String: String]) {
        self.timestamp = timestamp
        self.description = description
        self.parameters = parameters
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
        description = try values.decode(String.self, forKey: .description)
        let dateString = try values.decode(String.self, forKey: .timestamp)
        timestamp = dateString.dateFromISOString() ?? Date()
        parameters = try values.decodeIfPresent([String : String].self, forKey: .parameters)
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
        try container.encode(description, forKey: .description)
        try container.encode(timestamp.toISOString(), forKey: .timestamp)
        if let parameters = self.parameters {
            try container.encode(parameters, forKey: .parameters)
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
