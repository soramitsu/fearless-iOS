//
//  KeyPair.swift
//  
//
//  Created by Grigory on 22.6.23..
//

import Foundation

public struct KeyPair: Codable {
    public let publicKey: PublicKey
    public let privateKey: PrivateKey
    
    public init(publicKey: PublicKey,
                privateKey: PrivateKey) {
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
}
