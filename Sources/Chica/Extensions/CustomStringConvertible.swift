//
//  CustomStringConvertible.swift
//  
//
//  Created by Alex Modroño Vara on 14/7/21.
//

import Foundation

/// Allows to debug objects by printing its description.
public extension CustomStringConvertible {
    var description: String {
        var description = "START OF \((type(of: self)))".uppercased()
        let selfMirror = Mirror(reflecting: self)
        for child in selfMirror.children {
            if let propertyName = child.label {
                description += "\n\t–\(propertyName): \(child.value)"
            }
        }
        description += "\nEND OF \(type(of: self))".uppercased()
        return description
    }
}
