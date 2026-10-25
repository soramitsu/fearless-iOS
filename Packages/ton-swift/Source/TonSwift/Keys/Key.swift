//
//  Key.swift
//  
//
//  Created by Grigory on 22.6.23..
//

import Foundation

public protocol Key {
    var data: Data { get }
    var hexString: String { get }
}

public extension Key {
    var hexString: String { data.hexString() }
}
