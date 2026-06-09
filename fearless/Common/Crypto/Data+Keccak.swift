import Foundation
import keccak

enum KeccakError: Error {
    case internalFailure
}

// Local bridge for the C keccak package used by Ethereum address derivation.
extension Data {
    func keccak256() throws -> Data {
        let inputCount = count
        let outputCount = 32

        var data = Data(count: outputCount)

        let result = data.withUnsafeMutableBytes { (output: UnsafeMutableRawBufferPointer) in
            withUnsafeBytes { (input: UnsafeRawBufferPointer) in
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
