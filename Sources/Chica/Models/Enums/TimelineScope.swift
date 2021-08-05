//
//  TimelineScope.swift
//  Chica
//
//  Created by Marquis Kurt on 5/8/21.
//

import Foundation

/// An enumeration that represents the different types of timelines.
public enum TimelineScope {
    
    /// The public, federated timeline.
    case `public`
    
    /// The local timeline relative to the current user's instance.
    case local
    
    /// The user's timeline.
    case home
    
    /// The user's direct messages.
    case messages
    
    /// A timeline from a given list.
    case list(id: String)
    
    /// A timeline of posts that correspond to a hashtag.
    case tag(tag: String)
    
    /// The full path to a timeline endpoint
    var path: String {
        switch self {
        case .home:
            return "/api/v1/timelines/home"
        case .public:
            return "/api/v1/timelines/public"
        case .local:
            return "/api/v1/timelines/public?local=true"
        case .messages:
            return "/api/v1/conversations"
        case .list(let id):
            return "/api/v1/timelines/list/\(id)"
        case .tag(let tag):
            return "/api/v1/timelines/tag/\(tag)"
        }
    }
}
