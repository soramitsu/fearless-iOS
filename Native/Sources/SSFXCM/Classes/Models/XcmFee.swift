import BigInt
import Foundation
import SSFUtils

// MARK: - WelcomeElement

public struct XcmFee: Codable, Equatable {
    public let chainId: String
    public let destChain: String
    public let destXcmFee: [DestXcmFee]
    @StringCodable public var weight: BigUInt
}

// MARK: - DestXcmFee

public struct DestXcmFee: Codable, Equatable {
    @OptionStringCodable public var feeInPlanks: BigUInt?
    public let symbol: String
    public let precision: String?
}
