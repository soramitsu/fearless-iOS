import Foundation
import BigInt
import FearlessUtils

struct CandidateBondLessRequest: Decodable, Equatable {
    @StringCodable var amount: BigUInt
    let whenExecutable: String
}

enum CollatorStatus: String, Decodable, Equatable {
    case active = "Active"
    case idle = "Idle"
    case leaving = "Leaving"

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case Self.active.rawValue:
            self = .active
        case Self.idle.rawValue:
            self = .idle
        case Self.leaving.rawValue:
            self = .leaving
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected type"
            )
        }
    }
}

enum CapacityStatus: String, Decodable, Equatable {
    case full = "Full"
    case empty = "Empty"
    case partial = "Partial"

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case Self.full.rawValue:
            self = .full
        case Self.empty.rawValue:
            self = .empty
        case Self.partial.rawValue:
            self = .partial
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected type"
            )
        }
    }
}

struct ParachainStakingCandidateMetadata: Decodable, Equatable {
    enum CodingKeys: String, CodingKey {
        case bond
        case delegationCount
        case totalCounted
        case lowestTopDelegationAmount
        case highestBottomDelegationAmount
        case lowestBottomDelegationAmount
        case topCapacity
        case bottomCapacity
        case request
        case status
    }

    @StringCodable var bond: BigUInt
    @StringCodable var delegationCount: UInt32
    @StringCodable var totalCounted: BigUInt
    @StringCodable var lowestTopDelegationAmount: BigUInt
    @StringCodable var highestBottomDelegationAmount: BigUInt
    @StringCodable var lowestBottomDelegationAmount: BigUInt
    let topCapacity: CapacityStatus
    let bottomCapacity: CapacityStatus
    let request: CandidateBondLessRequest?
    let status: CollatorStatus
}
