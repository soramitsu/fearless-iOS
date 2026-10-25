//
//  Data+Keccak.swift
//  SFCrypto
//
//  Created by Soramitsu on 02.02.2023.
//

import Foundation
@_implementationOnly import keccak

enum KeccakError: Error {
    case internalFailure
}

public extension Data {
    func keccak256() throws -> Data {
        let inputCount = count
        let outputCount = 32

        var data = Data(count: outputCount)

        let result = data.withUnsafeMutableBytes { output in
            withUnsafeBytes { input in
                keccak_256(
                    output.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    outputCount,
                    input.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    inputCount
                )
            }
        }

        if result != 0 {
            throw KeccakError.internalFailure
        }

        return data
    }
}
