//
//  PrivateKey.swift
//  
//
//  Created by Grigory on 22.6.23..
//

import Foundation

public struct PrivateKey: Key, Equatable, Codable {
    public let data: Data
    
    public init(data: Data) {
        self.data = data
    }
}
