import Foundation

public struct RuntimeVersion: Codable, Equatable {
    public let specVersion: UInt32
    public let transactionVersion: UInt32
}
