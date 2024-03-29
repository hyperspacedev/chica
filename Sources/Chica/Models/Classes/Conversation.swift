//
//  Conversation.swift
//  
//
//  Created by Marquis Kurt on 23/2/22.
//

import Foundation

/// A class representation of a private conversation.
public class Conversation: Codable {

    // MARK: - STORED PROPERTIES

    /// The ID of the conversation.
    // swiftlint:disable:next identifier_name
    public let id: String

    /// The list of accounts that are members of the conversation.
    public let accounts: [Account]

    /// Whether the user hasn't read the latest message.
    public let unread: Bool

    /// The last status in the conversation.
    ///
    /// This is typically used for display purposes.
    public let lastStatus: Status?

    // MARK: - COMPUTED PROPERTIES

    private enum CodingKeys: String, CodingKey {

        // swiftlint:disable:next identifier_name
        case id
        case accounts
        case unread
        case lastStatus = "last_status"
    }

}

/// Grants us conformance to `Hashable` for _free_
extension Conversation: Hashable {
    public static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

