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
    
    enum CodingKeys: String, CodingKey {
        case description
        case timestamp
        case sessionID
        case parameters
    }
    
    init(timestamp: Date, description: String, parameters: [String : String]?, sessionID: String) {
        self.timestamp = timestamp
        self.description = description
        self.parameters = parameters
        self.sessionID = sessionID
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        description = try values.decode(String.self, forKey: .description)
        let dateString = try values.decode(String.self, forKey: .timestamp)
        timestamp = dateString.dateFromISOString() ?? Date()
        parameters = try values.decodeIfPresent([String : String].self, forKey: .parameters)
        sessionID = try values.decode(String.self, forKey: .sessionID)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
        try container.encode(timestamp.toISOString(), forKey: .timestamp)
        if let parameters = self.parameters {
            try container.encode(parameters, forKey: .parameters)
        }
        try container.encode(sessionID, forKey: .sessionID)
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
