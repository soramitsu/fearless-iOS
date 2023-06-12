import Foundation
import SSFUtils
import Web3

enum TrieOrFundIndex: Codable, ScaleEncodable, Equatable, Hashable {
    enum Error: Swift.Error {
        case invalidCase
        case scaleDecodingFailure(CodingKeys)
    }

    enum CodingKeys: String, CodingKey {
        case trieIndex
        case fundIndex
    }

    case trieIndex(TrieIndex)
    case fundIndex(FundIndex)

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringValue = try? container.decode(String.self, forKey: .trieIndex) {
            if let value = TrieIndex(stringValue) {
                self = .trieIndex(value)
            } else {
                throw Error.scaleDecodingFailure(.trieIndex)
            }
        } else if let stringValue = try? container.decode(String.self, forKey: .fundIndex) {
            if let value = FundIndex(stringValue) {
                self = .fundIndex(value)
            } else {
                throw Error.scaleDecodingFailure(.fundIndex)
            }
        } else {
            throw Error.invalidCase
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .trieIndex(trieIndex):
            try container.encode(trieIndex, forKey: .trieIndex)
        case let .fundIndex(fundIndex):
            try container.encode(fundIndex, forKey: .fundIndex)
        }
    }

    // MARK: - ScaleEncodable

    // In fact, it seems that decoding from SCALE is not needed, and yet is implicit

    func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case let .trieIndex(trieIndex):
            try trieIndex.encode(scaleEncoder: scaleEncoder)
        case let .fundIndex(fundIndex):
            try fundIndex.encode(scaleEncoder: scaleEncoder)
        }
    }
}

private struct CrowdloanFundsNotIndexed: Codable, Equatable {
    let depositor: AccountId
    var verifier: MultiSigner?
    @StringCodable var deposit: BigUInt
    @StringCodable var raised: BigUInt
    @StringCodable var end: UInt32
    @StringCodable var cap: BigUInt
    let lastContribution: CrowdloanLastContribution
    @StringCodable var firstPeriod: UInt32
    @StringCodable var lastPeriod: UInt32
}

struct CrowdloanFunds: Codable, Equatable {
    let depositor: AccountId
    var verifier: MultiSigner?
    var deposit: BigUInt
    var raised: BigUInt
    var end: UInt32
    var cap: BigUInt
    let lastContribution: CrowdloanLastContribution
    var firstPeriod: UInt32
    var lastPeriod: UInt32
    var trieOrFundIndex: TrieOrFundIndex

    init(from decoder: Decoder) throws {
        let funds = try CrowdloanFundsNotIndexed(from: decoder)
        depositor = funds.depositor
        verifier = funds.verifier
        deposit = funds.deposit
        raised = funds.raised
        end = funds.end
        cap = funds.cap
        lastContribution = funds.lastContribution
        firstPeriod = funds.firstPeriod
        lastPeriod = funds.lastPeriod

        trieOrFundIndex = try TrieOrFundIndex(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        let funds = CrowdloanFundsNotIndexed(
            depositor: depositor,
            verifier: verifier,
            deposit: deposit,
            raised: raised,
            end: end,
            cap: cap,
            lastContribution: lastContribution,
            firstPeriod: firstPeriod,
            lastPeriod: lastPeriod
        )

        try funds.encode(to: encoder)
        try trieOrFundIndex.encode(to: encoder)
    }
}
