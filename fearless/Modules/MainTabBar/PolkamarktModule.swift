import BigInt
import Foundation
import RobinHood
import SoraKeystore
import SSFModels
import SSFRuntimeCodingService
import SSFStorageQueryKit
import SSFUtils
import UIKit

enum PolkamarktConstants {
    static let soraChainId = ReviewedXcmRouteRegistry.soraChainId
    static let collateralAssetId = "0x02000c0000000000000000000000000000000000000000000000000000000000"
    static let collateralSymbol = "KUSD"
    static let feeAssetId = "0x0200000000000000000000000000000000000000000000000000000000000000"
    static let feeSymbol = "XOR"
    static let precision: UInt16 = 18
}

struct PolkamarktAccountCapability: Equatable {
    let hasSoraAccount: Bool
    let collateralAssetKey: AssetKey?
    let feeAssetKey: AssetKey?
    let collateralSpendable: BigUInt?
    let feeSpendable: BigUInt?

    func failureReason(
        requiredCollateral: BigUInt? = nil,
        requiredFee: BigUInt? = nil
    ) -> String? {
        guard hasSoraAccount else {
            return "Add a SORA account to use Polkamarkt."
        }
        guard collateralAssetKey != nil else {
            return "The verified KUSD collateral asset is unavailable in the current SORA registry."
        }
        guard feeAssetKey != nil else {
            return "The verified XOR fee asset is unavailable in the current SORA registry."
        }
        guard let feeSpendable else {
            return "The XOR balance is unavailable. Refresh SORA before submitting an action."
        }
        guard feeSpendable > .zero else {
            return "Fund XOR to pay SORA network fees."
        }
        if let requiredFee, feeSpendable < requiredFee {
            return "Insufficient XOR to pay the current SORA network fee."
        }
        if let requiredCollateral {
            guard let collateralSpendable else {
                return "The KUSD balance is unavailable. Refresh SORA before buying."
            }
            guard collateralSpendable >= requiredCollateral else {
                return "Insufficient KUSD collateral for this buy."
            }
        }
        return nil
    }
}

protocol PolkamarktAccountCapabilityProviding {
    func accountCapability() async -> PolkamarktAccountCapability
}

final class PolkamarktAccountCapabilityProvider: PolkamarktAccountCapabilityProviding {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let accountInfoRemoteService: AccountInfoRemoteService

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        accountInfoRemoteService: AccountInfoRemoteService? = nil
    ) {
        self.wallet = wallet
        self.chain = chain

        if let accountInfoRemoteService {
            self.accountInfoRemoteService = accountInfoRemoteService
        } else {
            let storagePerformer = SSFStorageQueryKit.StorageRequestPerformerDefault(
                chainRegistry: ChainRegistryFacade.sharedRegistry
            )
            self.accountInfoRemoteService = AccountInfoRemoteServiceDefault(
                storagePerformer: storagePerformer
            )
        }
    }

    func accountCapability() async -> PolkamarktAccountCapability {
        let hasAccount = wallet.fetch(for: chain.accountRequest()) != nil
        let collateralMatches = chain.chainAssets.filter {
            $0.asset.currencyId == PolkamarktConstants.collateralAssetId
        }
        let feeMatches = chain.chainAssets.filter {
            $0.asset.currencyId == PolkamarktConstants.feeAssetId
        }
        let collateral = collateralMatches.count == 1 ? collateralMatches[0] : nil
        let fee = feeMatches.count == 1 ? feeMatches[0] : nil

        guard hasAccount, let collateral, let fee else {
            return PolkamarktAccountCapability(
                hasSoraAccount: hasAccount,
                collateralAssetKey: collateral?.assetKey,
                feeAssetKey: fee?.assetKey,
                collateralSpendable: nil,
                feeSpendable: nil
            )
        }

        // Mutations use an authoritative runtime read instead of the portfolio
        // cache. A failed endpoint read therefore fails closed rather than
        // accepting a stale KUSD or XOR balance.
        let accountInfos = try? await accountInfoRemoteService.fetchAccountInfos(
            for: chain,
            wallet: wallet
        )
        let collateralInfo: AccountInfo? = accountInfos.flatMap {
            $0[collateral.chainAssetId] ?? nil
        }
        let feeInfo: AccountInfo? = accountInfos.flatMap {
            $0[fee.chainAssetId] ?? nil
        }
        return PolkamarktAccountCapability(
            hasSoraAccount: true,
            collateralAssetKey: collateral.assetKey,
            feeAssetKey: fee.assetKey,
            collateralSpendable: collateralInfo?.data.sendAvailable,
            feeSpendable: feeInfo?.data.sendAvailable
        )
    }
}

enum PolkamarktOutcome: String, Codable, CaseIterable {
    case yes = "Yes"
    case no = "No"

    init?(caseInsensitive value: String) {
        switch value.lowercased() {
        case "yes": self = .yes
        case "no": self = .no
        default: return nil
        }
    }
}

enum PolkamarktDisplayStatus: String, Equatable {
    case open
    case closed
    case resolved
    case cancelled

    var isOpen: Bool { self == .open }
}

struct PolkamarktMarket: Equatable {
    let marketId: String
    var conditionId: String?
    var creator: String?
    var title: String
    var marketDescription: String
    var category: String
    var closeBlock: String?
    var liquidityUSD: String
    var volumeUSD: String
    var yesProbability: String?
    var indexedStatus: String?
    var mechanism: String?
    var runtimeState: PolkamarktMarketState?

    func displayStatus(currentBlock: String) -> PolkamarktDisplayStatus {
        let normalizedStatus = indexedStatus?.lowercased() ?? ""
        if normalizedStatus.contains("cancel") { return .cancelled }
        if normalizedStatus.contains("resolv") || normalizedStatus.contains("final") { return .resolved }

        guard let closeBlock = closeBlock.flatMap({ BigUInt($0, radix: 10) }),
              let current = BigUInt(currentBlock, radix: 10) else {
            return normalizedStatus == "closed" ? .closed : .open
        }

        return current >= closeBlock ? .closed : .open
    }
}

struct PolkamarktRuntimeMarketEntry: Equatable, Decodable {
    let marketId: String
    let conditionId: String?
    let creator: String?
    let closeBlock: String?
    let status: String?
    let mechanism: String?
    let question: String?
    let category: String?

    private enum CodingKeys: String, CodingKey {
        case marketId, conditionId, creator, closeBlock, status, mechanism, question, category
    }

    init(
        marketId: String,
        conditionId: String?,
        creator: String?,
        closeBlock: String?,
        status: String?,
        mechanism: String?,
        question: String?,
        category: String?
    ) {
        self.marketId = marketId
        self.conditionId = conditionId
        self.creator = creator
        self.closeBlock = closeBlock
        self.status = status
        self.mechanism = mechanism
        self.question = question
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        marketId = try container.polkamarktString(forKey: .marketId) ?? ""
        conditionId = try container.polkamarktString(forKey: .conditionId)
        creator = try container.decodeIfPresent(String.self, forKey: .creator)
        closeBlock = try container.polkamarktString(forKey: .closeBlock)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        mechanism = try container.decodeIfPresent(String.self, forKey: .mechanism)
        question = try container.decodeIfPresent(String.self, forKey: .question)
        category = try container.decodeIfPresent(String.self, forKey: .category)
    }
}

struct PolkamarktMarketState: Equatable, Decodable {
    let marketId: String
    let mechanism: String
    let virtualDepth: String
    let realYesShares: String
    let realNoShares: String
    let dpmCollateral: String
    let marginalYesPriceBps: String
    let marginalNoPriceBps: String
    let impliedYesProbabilityBps: String
    let impliedNoProbabilityBps: String

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case marketId, mechanism, virtualDepth, realYesShares, realNoShares, dpmCollateral
        case marginalYesPriceBps, marginalNoPriceBps, impliedYesProbabilityBps, impliedNoProbabilityBps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        marketId = try container.polkamarktString(forKey: .marketId) ?? ""
        mechanism = try container.decodeIfPresent(String.self, forKey: .mechanism) ?? ""
        virtualDepth = try container.polkamarktString(forKey: .virtualDepth) ?? "0"
        realYesShares = try container.polkamarktString(forKey: .realYesShares) ?? "0"
        realNoShares = try container.polkamarktString(forKey: .realNoShares) ?? "0"
        dpmCollateral = try container.polkamarktString(forKey: .dpmCollateral) ?? "0"
        marginalYesPriceBps = try container.polkamarktString(forKey: .marginalYesPriceBps) ?? "0"
        marginalNoPriceBps = try container.polkamarktString(forKey: .marginalNoPriceBps) ?? "0"
        impliedYesProbabilityBps = try container.polkamarktString(forKey: .impliedYesProbabilityBps) ?? "0"
        impliedNoProbabilityBps = try container.polkamarktString(forKey: .impliedNoProbabilityBps) ?? "0"
    }
}

struct PolkamarktBuyQuote: Equatable, Decodable {
    let marketId: String
    let outcome: String
    let collateralIn: String
    let feeAmount: String
    let pricingCollateral: String
    let sharesOut: String

    private enum CodingKeys: String, CodingKey {
        case marketId, outcome, collateralIn, feeAmount, pricingCollateral, sharesOut
    }

    init(
        marketId: String,
        outcome: String,
        collateralIn: String,
        feeAmount: String,
        pricingCollateral: String,
        sharesOut: String
    ) {
        self.marketId = marketId
        self.outcome = outcome
        self.collateralIn = collateralIn
        self.feeAmount = feeAmount
        self.pricingCollateral = pricingCollateral
        self.sharesOut = sharesOut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        marketId = try container.polkamarktString(forKey: .marketId) ?? ""
        outcome = try container.decode(String.self, forKey: .outcome)
        collateralIn = try container.polkamarktString(forKey: .collateralIn) ?? "0"
        feeAmount = try container.polkamarktString(forKey: .feeAmount) ?? "0"
        pricingCollateral = try container.polkamarktString(forKey: .pricingCollateral) ?? "0"
        sharesOut = try container.polkamarktString(forKey: .sharesOut) ?? "0"
    }
}

struct PolkamarktSellQuote: Equatable, Decodable {
    let marketId: String
    let outcome: String
    let sharesIn: String
    let grossCollateralOut: String
    let feeAmount: String
    let collateralOut: String

    private enum CodingKeys: String, CodingKey {
        case marketId, outcome, sharesIn, grossCollateralOut, feeAmount, collateralOut
    }

    init(
        marketId: String,
        outcome: String,
        sharesIn: String,
        grossCollateralOut: String,
        feeAmount: String,
        collateralOut: String
    ) {
        self.marketId = marketId
        self.outcome = outcome
        self.sharesIn = sharesIn
        self.grossCollateralOut = grossCollateralOut
        self.feeAmount = feeAmount
        self.collateralOut = collateralOut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        marketId = try container.polkamarktString(forKey: .marketId) ?? ""
        outcome = try container.decode(String.self, forKey: .outcome)
        sharesIn = try container.polkamarktString(forKey: .sharesIn) ?? "0"
        grossCollateralOut = try container.polkamarktString(forKey: .grossCollateralOut) ?? "0"
        feeAmount = try container.polkamarktString(forKey: .feeAmount) ?? "0"
        collateralOut = try container.polkamarktString(forKey: .collateralOut) ?? "0"
    }
}

struct PolkamarktClaimable: Equatable, Decodable {
    let marketId: String
    let account: String
    let status: String
    let resolutionOutcome: String?
    let yesShares: String
    let noShares: String
    let netCollateralPaid: String
    let traderPayout: String
    let claimablePayout: String?
    let creatorFees: String
    let isCreator: Bool

    private enum CodingKeys: String, CodingKey {
        case marketId, account, status, resolutionOutcome, yesShares, noShares, netCollateralPaid
        case traderPayout, claimablePayout, creatorFees, isCreator
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        marketId = try container.polkamarktString(forKey: .marketId) ?? ""
        account = try container.decodeIfPresent(String.self, forKey: .account) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        resolutionOutcome = try container.decodeIfPresent(String.self, forKey: .resolutionOutcome)
        yesShares = try container.polkamarktString(forKey: .yesShares) ?? "0"
        noShares = try container.polkamarktString(forKey: .noShares) ?? "0"
        netCollateralPaid = try container.polkamarktString(forKey: .netCollateralPaid) ?? "0"
        traderPayout = try container.polkamarktString(forKey: .traderPayout) ?? "0"
        claimablePayout = try container.polkamarktString(forKey: .claimablePayout)
        creatorFees = try container.polkamarktString(forKey: .creatorFees) ?? "0"
        isCreator = try container.decodeIfPresent(Bool.self, forKey: .isCreator) ?? false
    }

    var effectiveTraderPayout: String {
        claimablePayout ?? traderPayout
    }
}

struct PolkamarktHistoryPoint: Equatable, Decodable {
    let id: String
    let marketId: String?
    let timestamp: String?
    let blockHeight: String?
    let probability: String
    let priceYes: String?
    let priceNo: String?
    let liquidityUSD: String?
    let volumeUSD: String?
    let status: String?

    private enum CodingKeys: String, CodingKey {
        case id, marketId, timestamp, blockHeight, probability, priceYes, priceNo, liquidityUSD, volumeUSD, status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        marketId = try container.polkamarktString(forKey: .marketId)
        timestamp = try container.polkamarktString(forKey: .timestamp)
        blockHeight = try container.polkamarktString(forKey: .blockHeight)
        probability = try container.polkamarktString(forKey: .probability) ?? "0"
        priceYes = try container.polkamarktString(forKey: .priceYes)
        priceNo = try container.polkamarktString(forKey: .priceNo)
        liquidityUSD = try container.polkamarktString(forKey: .liquidityUSD)
        volumeUSD = try container.polkamarktString(forKey: .volumeUSD)
        status = try container.decodeIfPresent(String.self, forKey: .status)
    }
}

struct PolkamarktPosition: Equatable, Decodable {
    let id: String
    let marketId: String
    let outcome: String
    let shares: String
    let netCollateralPaid: String
    let status: String

    private enum CodingKeys: String, CodingKey {
        case id, marketId, outcome, shares, netCollateralPaid, status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        marketId = try container.polkamarktString(forKey: .marketId) ?? ""
        outcome = try container.decodeIfPresent(String.self, forKey: .outcome) ?? ""
        shares = try container.polkamarktString(forKey: .shares) ?? "0"
        netCollateralPaid = try container.polkamarktString(forKey: .netCollateralPaid) ?? "0"
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
    }
}

struct PolkamarktTrade: Equatable, Decodable {
    let id: String
    let marketId: String
    let side: String
    let outcome: String
    let collateral: String
    let sharesOut: String
    let fee: String
    let blockNumber: String
    let extrinsicHash: String?

    private enum CodingKeys: String, CodingKey {
        case id, marketId, side, outcome, collateral, sharesOut, fee, blockNumber, extrinsicHash
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        marketId = try container.polkamarktString(forKey: .marketId) ?? ""
        side = try container.decodeIfPresent(String.self, forKey: .side) ?? ""
        outcome = try container.decodeIfPresent(String.self, forKey: .outcome) ?? ""
        collateral = try container.polkamarktString(forKey: .collateral) ?? "0"
        sharesOut = try container.polkamarktString(forKey: .sharesOut) ?? "0"
        fee = try container.polkamarktString(forKey: .fee) ?? "0"
        blockNumber = try container.polkamarktString(forKey: .blockNumber) ?? "0"
        extrinsicHash = try container.decodeIfPresent(String.self, forKey: .extrinsicHash)
    }
}

struct PolkamarktIndexedAccountActivity: Decodable {
    let positions: [PolkamarktPosition]
    let trades: [PolkamarktTrade]
}

private extension KeyedDecodingContainer {
    func polkamarktString(forKey key: Key) throws -> String? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(UInt64.self, forKey: key) { return String(value) }
        if let value = try? decode(Int64.self, forKey: key) { return String(value) }
        if let value = try? decode(Decimal.self, forKey: key) {
            return NSDecimalNumber(decimal: value).stringValue
        }
        return nil
    }
}

enum PolkamarktCatalog {
    static func merge(
        indexed: [PolkamarktMarket],
        runtime: [PolkamarktRuntimeMarketEntry],
        states: [String: PolkamarktMarketState] = [:],
        currentBlock: String
    ) -> [PolkamarktMarket] {
        var indexedById = Dictionary(uniqueKeysWithValues: indexed.map { ($0.marketId, $0) })

        runtime.forEach { entry in
            if var market = indexedById[entry.marketId] {
                market.conditionId = entry.conditionId ?? market.conditionId
                market.creator = entry.creator ?? market.creator
                market.closeBlock = entry.closeBlock ?? market.closeBlock
                market.indexedStatus = entry.status ?? market.indexedStatus
                market.mechanism = entry.mechanism ?? market.mechanism
                market.runtimeState = states[entry.marketId]
                indexedById[entry.marketId] = market
            } else {
                indexedById[entry.marketId] = PolkamarktMarket(
                    marketId: entry.marketId,
                    conditionId: entry.conditionId,
                    creator: entry.creator,
                    title: entry.question ?? "SORA market #\(entry.marketId)",
                    marketDescription: "Read directly from the SORA runtime while the indexer catches up.",
                    category: entry.category ?? "Other",
                    closeBlock: entry.closeBlock,
                    liquidityUSD: states[entry.marketId]?.dpmCollateral ?? "0",
                    volumeUSD: "0",
                    yesProbability: states[entry.marketId].map {
                        decimalProbability(fromBasisPoints: $0.impliedYesProbabilityBps)
                    },
                    indexedStatus: entry.status,
                    mechanism: entry.mechanism,
                    runtimeState: states[entry.marketId]
                )
            }
        }

        states.forEach { marketId, state in
            guard var market = indexedById[marketId] else { return }
            market.runtimeState = state
            market.mechanism = state.mechanism.isEmpty ? market.mechanism : state.mechanism
            market.liquidityUSD = state.dpmCollateral
            market.yesProbability = decimalProbability(fromBasisPoints: state.impliedYesProbabilityBps)
            indexedById[marketId] = market
        }

        return indexedById.values.sorted { lhs, rhs in
            let lhsOpen = lhs.displayStatus(currentBlock: currentBlock).isOpen
            let rhsOpen = rhs.displayStatus(currentBlock: currentBlock).isOpen
            if lhsOpen != rhsOpen { return lhsOpen && !rhsOpen }

            let lhsLiquidity = Decimal(string: lhs.liquidityUSD, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
            let rhsLiquidity = Decimal(string: rhs.liquidityUSD, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
            if lhsLiquidity != rhsLiquidity { return lhsLiquidity > rhsLiquidity }

            let lhsId = BigUInt(lhs.marketId, radix: 10) ?? .zero
            let rhsId = BigUInt(rhs.marketId, radix: 10) ?? .zero
            return lhsId < rhsId
        }
    }

    static func activeMarkets(_ markets: [PolkamarktMarket], currentBlock: String) -> [PolkamarktMarket] {
        markets.filter { $0.displayStatus(currentBlock: currentBlock).isOpen }
    }

    private static func decimalProbability(fromBasisPoints value: String) -> String {
        guard let bps = Decimal(string: value) else { return "0" }
        return NSDecimalNumber(decimal: bps / 10000).stringValue
    }
}

enum PolkamarktRPCParameter: Equatable {
    case unsignedInteger(String)
    case text(String)
}

enum PolkamarktRPCRequestBuilder {
    enum Error: Swift.Error {
        case invalidMethod
        case invalidUnsignedInteger
        case unsignedIntegerOverflow
    }

    private static let maximumU128 = (BigUInt(1) << 128) - 1

    static func parametersJSON(_ parameters: [PolkamarktRPCParameter]) throws -> String {
        let values = try parameters.map { parameter -> String in
            switch parameter {
            case let .unsignedInteger(value):
                guard value.isNotEmpty,
                      value.allSatisfy(\.isNumber),
                      let number = BigUInt(value, radix: 10) else {
                    throw Error.invalidUnsignedInteger
                }
                guard number <= maximumU128 else { throw Error.unsignedIntegerOverflow }
                return number.description
            case let .text(value):
                let data = try JSONSerialization.data(withJSONObject: [value], options: [])
                let array = String(decoding: data, as: UTF8.self)
                return String(array.dropFirst().dropLast())
            }
        }
        return "[\(values.joined(separator: ","))]"
    }

    static func requestData(
        method: String,
        parameters: [PolkamarktRPCParameter],
        identifier: UInt64 = 1
    ) throws -> Data {
        guard method.isNotEmpty,
              method.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            throw Error.invalidMethod
        }
        let params = try parametersJSON(parameters)
        return Data("{\"jsonrpc\":\"2.0\",\"id\":\(identifier),\"method\":\"\(method)\",\"params\":\(params)}".utf8)
    }
}

protocol PolkamarktHTTPTransport {
    func post(_ body: Data, to url: URL) async throws -> Data
}

struct PolkamarktURLSessionTransport: PolkamarktHTTPTransport {
    func post(_ body: Data, to url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data,
                      let http = response as? HTTPURLResponse,
                      (200 ... 299).contains(http.statusCode) else {
                    continuation.resume(throwing: PolkamarktServiceError.invalidResponse)
                    return
                }
                continuation.resume(returning: data)
            }.resume()
        }
    }
}

enum PolkamarktServiceError: LocalizedError {
    case unavailable(String)
    case invalidResponse
    case rpc(String)
    case watchOnly
    case actionsPaused

    var errorDescription: String? {
        switch self {
        case let .unavailable(reason): return reason
        case .invalidResponse: return "The Polkamarkt service returned an invalid response."
        case let .rpc(message): return message
        case .watchOnly: return "A local SORA signing key is required. This wallet is watch-only or uses unsupported external signing."
        case .actionsPaused: return "Polkamarkt actions are temporarily disabled by the remote safety switch."
        }
    }
}

private struct PolkamarktRPCEnvelope<Result: Decodable>: Decodable {
    struct RPCError: Decodable { let message: String }
    let result: Result?
    let error: RPCError?
}

private struct PolkamarktRPCMethods: Decodable { let methods: [String] }
private struct PolkamarktHeader: Decodable { let number: String }

final class PolkamarktRPCClient {
    let endpoint: URL
    private let transport: PolkamarktHTTPTransport

    init(endpoint: URL, transport: PolkamarktHTTPTransport = PolkamarktURLSessionTransport()) {
        self.endpoint = endpoint
        self.transport = transport
    }

    func methods() async throws -> Set<String> {
        let value: PolkamarktRPCMethods = try await send(method: "rpc_methods", parameters: [])
        return Set(value.methods)
    }

    func currentBlock() async throws -> String {
        let header: PolkamarktHeader = try await send(method: "chain_getHeader", parameters: [])
        let raw = header.number.hasPrefix("0x") ? String(header.number.dropFirst(2)) : header.number
        guard let number = BigUInt(raw, radix: 16) else { throw PolkamarktServiceError.invalidResponse }
        return number.description
    }

    func marketState(marketId: String) async throws -> PolkamarktMarketState {
        try await send(
            method: "polkamarkt_marketState",
            parameters: [.unsignedInteger(marketId)]
        )
    }

    func quoteBuy(
        marketId: String,
        outcome: PolkamarktOutcome,
        collateralIn: String
    ) async throws -> PolkamarktBuyQuote {
        try await send(
            method: "polkamarkt_quoteBuy",
            parameters: [.unsignedInteger(marketId), .text(outcome.rawValue), .unsignedInteger(collateralIn)]
        )
    }

    func quoteSell(
        marketId: String,
        outcome: PolkamarktOutcome,
        sharesIn: String
    ) async throws -> PolkamarktSellQuote {
        try await send(
            method: "polkamarkt_quoteSell",
            parameters: [.unsignedInteger(marketId), .text(outcome.rawValue), .unsignedInteger(sharesIn)]
        )
    }

    func claimable(account: String, marketId: String) async throws -> PolkamarktClaimable {
        try await send(
            method: "polkamarkt_claimable",
            parameters: [.text(account), .unsignedInteger(marketId)]
        )
    }

    private func send<Result: Decodable>(
        method: String,
        parameters: [PolkamarktRPCParameter]
    ) async throws -> Result {
        let body = try PolkamarktRPCRequestBuilder.requestData(method: method, parameters: parameters)
        let data = try await transport.post(body, to: endpoint)
        let envelope = try JSONDecoder().decode(PolkamarktRPCEnvelope<Result>.self, from: data)
        if let error = envelope.error { throw PolkamarktServiceError.rpc(error.message) }
        guard let result = envelope.result else { throw PolkamarktServiceError.invalidResponse }
        return result
    }
}

private struct PolkamarktGraphQLError: Decodable { let message: String }

private struct PolkamarktGraphQLResponse<Payload: Decodable>: Decodable {
    let data: Payload?
    let errors: [PolkamarktGraphQLError]?
}

struct PolkamarktMarketNode: Decodable {
    let id: String
    let marketId: String?
    let conditionId: String?
    let creator: String?
    let title: String?
    let description: String?
    let category: String?
    let closeBlock: String?
    let liquidityUSD: String?
    let volumeUSD: String?
    let priceYes: String?
    let probability: String?
    let status: String?
    let mechanism: String?

    private enum CodingKeys: String, CodingKey {
        case id, marketId, conditionId, creator, title, description, category, closeBlock
        case liquidityUSD, volumeUSD, priceYes, probability, status, mechanism
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        marketId = try container.polkamarktString(forKey: .marketId)
        conditionId = try container.polkamarktString(forKey: .conditionId)
        creator = try container.decodeIfPresent(String.self, forKey: .creator)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        closeBlock = try container.polkamarktString(forKey: .closeBlock)
        liquidityUSD = try container.polkamarktString(forKey: .liquidityUSD)
        volumeUSD = try container.polkamarktString(forKey: .volumeUSD)
        priceYes = try container.polkamarktString(forKey: .priceYes)
        probability = try container.polkamarktString(forKey: .probability)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        mechanism = try container.decodeIfPresent(String.self, forKey: .mechanism)
    }

    var market: PolkamarktMarket? {
        guard let title, !title.isEmpty else { return nil }
        return PolkamarktMarket(
            marketId: marketId ?? id,
            conditionId: conditionId,
            creator: creator,
            title: title,
            marketDescription: description ?? "Review the SORA oracle and resolution source before trading.",
            category: category ?? "Other",
            closeBlock: closeBlock,
            liquidityUSD: liquidityUSD ?? "0",
            volumeUSD: volumeUSD ?? "0",
            yesProbability: probability ?? priceYes,
            indexedStatus: status,
            mechanism: mechanism,
            runtimeState: nil
        )
    }
}

private struct PolkamarktMarketEdge: Decodable { let node: PolkamarktMarketNode? }
private struct PolkamarktMarketConnection: Decodable { let edges: [PolkamarktMarketEdge] }
private struct PolkamarktMarketsPayload: Decodable { let markets: PolkamarktMarketConnection }
private struct PolkamarktHistoryEdge: Decodable { let node: PolkamarktHistoryPoint? }
private struct PolkamarktHistoryConnection: Decodable { let edges: [PolkamarktHistoryEdge] }
private struct PolkamarktHistoryPayload: Decodable { let marketSnapshots: PolkamarktHistoryConnection }
private struct PolkamarktPositionEdge: Decodable { let node: PolkamarktPosition? }
private struct PolkamarktPositionConnection: Decodable { let edges: [PolkamarktPositionEdge] }
private struct PolkamarktPositionsPayload: Decodable { let accountPositions: PolkamarktPositionConnection }
private struct PolkamarktTradeEdge: Decodable { let node: PolkamarktTrade? }
private struct PolkamarktTradeConnection: Decodable { let edges: [PolkamarktTradeEdge] }
private struct PolkamarktTradesPayload: Decodable { let trades: PolkamarktTradeConnection }

final class PolkamarktIndexerClient {
    private let endpoint: URL
    private let transport: PolkamarktHTTPTransport

    init(endpoint: URL, transport: PolkamarktHTTPTransport = PolkamarktURLSessionTransport()) {
        self.endpoint = endpoint
        self.transport = transport
    }

    func markets(limit: Int = 48) async throws -> [PolkamarktMarket] {
        do {
            return try await requestMarkets(query: Self.latestMarketsQuery, limit: limit)
        } catch {
            // The deployed indexer schema can lag the UI branch. The legacy
            // retry intentionally omits orderBy as well as new fields, then the
            // shared catalog sorter establishes deterministic client order.
            return try await requestMarkets(query: Self.legacyMarketsQuery, limit: limit)
        }
    }

    func history(marketId: String, limit: Int = 96) async throws -> [PolkamarktHistoryPoint] {
        guard let numericMarketId = Int(marketId) else { return [] }
        let payload: PolkamarktHistoryPayload = try await request(
            query: Self.historyQuery,
            variables: ["marketId": numericMarketId, "limit": limit]
        )
        return payload.marketSnapshots.edges.compactMap(\.node).sorted {
            (BigUInt($0.blockHeight ?? "0", radix: 10) ?? .zero) <
                (BigUInt($1.blockHeight ?? "0", radix: 10) ?? .zero)
        }
    }

    func positions(account: String, limit: Int = 50) async throws -> [PolkamarktPosition] {
        let payload: PolkamarktPositionsPayload = try await request(
            query: Self.positionsQuery,
            variables: ["account": account, "limit": limit]
        )
        return payload.accountPositions.edges.compactMap(\.node)
    }

    func trades(account: String, limit: Int = 50) async throws -> [PolkamarktTrade] {
        let payload: PolkamarktTradesPayload = try await request(
            query: Self.tradesQuery,
            variables: ["account": account, "limit": limit]
        )
        return payload.trades.edges.compactMap(\.node).sorted {
            (BigUInt($0.blockNumber, radix: 10) ?? .zero) >
                (BigUInt($1.blockNumber, radix: 10) ?? .zero)
        }
    }

    private func requestMarkets(query: String, limit: Int) async throws -> [PolkamarktMarket] {
        let payload: PolkamarktMarketsPayload = try await request(
            query: query,
            variables: ["limit": limit]
        )
        return payload.markets.edges.compactMap { $0.node?.market }
    }

    private func request<Payload: Decodable>(
        query: String,
        variables: [String: Any]
    ) async throws -> Payload {
        let body = try JSONSerialization.data(
            withJSONObject: ["query": query, "variables": variables],
            options: []
        )
        let data = try await transport.post(body, to: endpoint)
        let envelope = try JSONDecoder().decode(PolkamarktGraphQLResponse<Payload>.self, from: data)
        if let error = envelope.errors?.first {
            throw PolkamarktServiceError.unavailable(error.message)
        }
        guard let payload = envelope.data else { throw PolkamarktServiceError.invalidResponse }
        return payload
    }

    private static let latestMarketsQuery = """
    query PolkamarktLatestMarkets($limit: Int = 48) {
      markets(first: $limit, orderBy: [VOLUME_USD_DESC]) { edges { node {
        id marketId conditionId creator title description category closeBlock status mechanism
        liquidityUSD volumeUSD probability priceYes dpmCollateral realYesShares realNoShares
        marginalYesPriceBps marginalNoPriceBps impliedYesProbabilityBps impliedNoProbabilityBps
      } } }
    }
    """

    private static let legacyMarketsQuery = """
    query PolkamarktLegacyMarkets($limit: Int = 48) {
      markets(first: $limit) { edges { node {
        id marketId conditionId creator title description category closeBlock status mechanism
        liquidityUSD volumeUSD probability priceYes
      } } }
    }
    """

    private static let historyQuery = """
    query PolkamarktMarketHistory($marketId: Int!, $limit: Int = 96) {
      marketSnapshots(first: $limit, filter: { marketId: { equalTo: $marketId } }) { edges { node {
        id marketId timestamp blockHeight probability priceYes priceNo liquidityUSD volumeUSD status
      } } }
    }
    """

    private static let positionsQuery = """
    query PolkamarktAccountPositions($account: String!, $limit: Int = 50) {
      accountPositions(first: $limit, filter: { account: { equalTo: $account } }) { edges { node {
        id marketId outcome shares netCollateralPaid status
      } } }
    }
    """

    private static let tradesQuery = """
    query PolkamarktAccountTrades($account: String!, $limit: Int = 50) {
      trades(first: $limit, filter: { account: { equalTo: $account } }) { edges { node {
        id marketId side outcome collateral sharesOut fee blockNumber extrinsicHash
      } } }
    }
    """
}

struct PolkamarktRuntimeCapabilities: Equatable {
    let palletAvailable: Bool
    let storage: Set<String>
    let rpc: Set<String>
    let calls: Set<String>
    let claimablePayoutFieldAvailable: Bool

    private func normalized(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "polkamarkt", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    func hasStorage(_ name: String) -> Bool {
        storage.contains { normalized($0) == normalized(name) }
    }

    func hasRPC(_ name: String) -> Bool {
        rpc.contains { normalized($0) == normalized(name) }
    }

    func hasCall(_ name: String) -> Bool {
        calls.contains { normalized($0) == normalized(name) }
    }

    var canBrowseRuntime: Bool {
        palletAvailable && hasStorage("markets") && hasStorage("conditions")
    }

    var canTrade: Bool {
        palletAvailable &&
            hasRPC("quoteBuy") && hasRPC("quoteSell") && hasRPC("marketState") &&
            hasCall("buy") && hasCall("sell")
    }

    var canReadClaims: Bool { hasRPC("claimable") }
    var canClaimTrader: Bool { canReadClaims && hasCall("claimMarket") }
    var canClaimCreator: Bool { canReadClaims && hasCall("claimCreatorFees") }

    var tradingUnavailableReason: String? {
        guard !canTrade else { return nil }
        if !palletAvailable { return "The connected SORA runtime does not expose the Polkamarkt pallet." }
        if !hasRPC("marketState") { return "Market state RPC is unavailable; browse and history remain available." }
        return "Required Polkamarkt quote or trade capabilities are unavailable on this runtime."
    }

    func resolvedCallName(_ requested: String) -> String? {
        calls.first { normalized($0) == normalized(requested) }
    }
}

enum PolkamarktCapabilityNegotiator {
    static func negotiate(chain: ChainModel, rpcClient: PolkamarktRPCClient?) async -> PolkamarktRuntimeCapabilities {
        var storage = Set<String>()
        var calls = Set<String>()
        var palletAvailable = false

        if let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chain.chainId),
           let factory = try? await runtimeService.fetchCoderFactory(),
           let module = factory.metadata.modules.first(where: { $0.name.lowercased() == "polkamarkt" }) {
            palletAvailable = true
            ["Markets", "Conditions", "MarketState"].forEach { item in
                if factory.metadata.getStorageMetadata(in: module.name, storageName: item) != nil {
                    storage.insert(item)
                }
            }
            if let metadataCalls = try? module.calls(using: factory.metadata.schemaResolver) {
                calls.formUnion(metadataCalls.map(\.name))
            }
        }

        let rpc: Set<String>
        if let rpcClient {
            rpc = (try? await rpcClient.methods()) ?? []
        } else {
            rpc = []
        }
        return PolkamarktRuntimeCapabilities(
            palletAvailable: palletAvailable,
            storage: storage,
            rpc: rpc,
            calls: calls,
            claimablePayoutFieldAvailable: true
        )
    }
}

enum PolkamarktMutation {
    case buy(marketId: String, outcome: PolkamarktOutcome, collateralIn: String, minSharesOut: String)
    case sell(marketId: String, outcome: PolkamarktOutcome, sharesIn: String, minCollateralOut: String)
    case claimTrader(marketId: String)
    case claimCreator(marketId: String)

    var requiredCollateral: BigUInt? {
        guard case let .buy(_, _, collateralIn, _) = self else { return nil }
        return BigUInt(collateralIn, radix: 10)
    }

    var marketId: String {
        switch self {
        case let .buy(marketId, _, _, _),
             let .sell(marketId, _, _, _),
             let .claimTrader(marketId),
             let .claimCreator(marketId):
            return marketId
        }
    }
}

enum PolkamarktSubmissionError: LocalizedError, Equatable {
    case runtimeUnavailable
    case signerUnavailable
    case selectedWalletChanged
    case marketUnavailable
    case marketClosed
    case quoteMismatch
    case collateralFeeMismatch
    case insufficientShares
    case claimUnavailable
    case balanceUnavailable
    case insufficientCollateral
    case insufficientFee

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            return "The authoritative SORA Polkamarkt runtime is unavailable."
        case .signerUnavailable:
            return "A local SORA signing key is required. Watch-only and unsupported external signing cannot submit this action."
        case .selectedWalletChanged:
            return "The selected wallet changed. Review the Polkamarkt action again."
        case .marketUnavailable:
            return "The market is unavailable in the current SORA runtime."
        case .marketClosed:
            return "The market is not open at the current SORA block."
        case .quoteMismatch:
            return "The fresh runtime quote no longer matches this request. Request a new quote."
        case .collateralFeeMismatch:
            return "The runtime quote returned inconsistent KUSD collateral or market-fee values."
        case .insufficientShares:
            return "The authoritative runtime position has insufficient outcome shares for this sale."
        case .claimUnavailable:
            return "The authoritative runtime reports no valid claim for this account and market."
        case .balanceUnavailable:
            return "The exact KUSD or XOR balance is unavailable. Refresh SORA before submitting."
        case .insufficientCollateral:
            return "The current spendable KUSD balance is insufficient for this purchase."
        case .insufficientFee:
            return "The current spendable XOR balance is insufficient for the exact network fee."
        }
    }
}

enum PolkamarktMutationQuoteValidator {
    static func validateBuy(
        marketId: String,
        outcome: PolkamarktOutcome,
        collateralIn: String,
        minSharesOut: String,
        quote: PolkamarktBuyQuote
    ) throws {
        guard nonnegative(marketId) != nil,
              let collateral = positive(collateralIn),
              let minimum = positive(minSharesOut),
              quote.marketId == marketId,
              PolkamarktOutcome(caseInsensitive: quote.outcome) == outcome,
              quote.collateralIn == collateralIn,
              let quoteCollateral = positive(quote.collateralIn),
              let marketFee = nonnegative(quote.feeAmount),
              let pricingCollateral = positive(quote.pricingCollateral),
              let sharesOut = positive(quote.sharesOut),
              collateral == quoteCollateral,
              minimum <= sharesOut,
              minimum >= sharesOut * 99 / 100 else {
            throw PolkamarktSubmissionError.quoteMismatch
        }
        guard pricingCollateral + marketFee == collateral else {
            throw PolkamarktSubmissionError.collateralFeeMismatch
        }
    }

    static func validateSell(
        marketId: String,
        outcome: PolkamarktOutcome,
        sharesIn: String,
        minCollateralOut: String,
        quote: PolkamarktSellQuote
    ) throws {
        guard nonnegative(marketId) != nil,
              let shares = positive(sharesIn),
              let minimum = positive(minCollateralOut),
              quote.marketId == marketId,
              PolkamarktOutcome(caseInsensitive: quote.outcome) == outcome,
              quote.sharesIn == sharesIn,
              let quoteShares = positive(quote.sharesIn),
              let gross = positive(quote.grossCollateralOut),
              let marketFee = nonnegative(quote.feeAmount),
              let collateralOut = positive(quote.collateralOut),
              shares == quoteShares,
              minimum <= collateralOut,
              minimum >= collateralOut * 99 / 100 else {
            throw PolkamarktSubmissionError.quoteMismatch
        }
        guard gross >= marketFee, gross - marketFee == collateralOut else {
            throw PolkamarktSubmissionError.collateralFeeMismatch
        }
    }

    private static func positive(_ value: String) -> BigUInt? {
        guard let value = BigUInt(value, radix: 10), value > .zero else { return nil }
        return value
    }

    private static func nonnegative(_ value: String) -> BigUInt? {
        BigUInt(value, radix: 10)
    }
}

struct PolkamarktBuyCall: Codable {
    let marketId: String
    let outcome: String
    let collateralIn: String
    let minSharesOut: String

    enum CodingKeys: String, CodingKey {
        case marketId = "market_id"
        case outcome
        case collateralIn = "collateral_in"
        case minSharesOut = "min_shares_out"
    }
}

struct PolkamarktSellCall: Codable {
    let marketId: String
    let outcome: String
    let sharesIn: String
    let minCollateralOut: String

    enum CodingKeys: String, CodingKey {
        case marketId = "market_id"
        case outcome
        case sharesIn = "shares_in"
        case minCollateralOut = "min_collateral_out"
    }
}

struct PolkamarktMarketActionCall: Codable {
    let marketId: String

    enum CodingKeys: String, CodingKey {
        case marketId = "market_id"
    }
}

protocol PolkamarktMutationCallBuilding {
    func builder(
        for mutation: PolkamarktMutation,
        capabilities: PolkamarktRuntimeCapabilities
    ) throws -> ExtrinsicBuilderClosure
}

struct PolkamarktMutationCallBuilder: PolkamarktMutationCallBuilding {
    private let moduleName = "Polkamarkt"

    func builder(
        for mutation: PolkamarktMutation,
        capabilities: PolkamarktRuntimeCapabilities
    ) throws -> ExtrinsicBuilderClosure {
        switch mutation {
        case let .buy(marketId, outcome, collateralIn, minSharesOut):
            guard capabilities.canTrade,
                  let callName = capabilities.resolvedCallName("buy") else {
                throw PolkamarktServiceError.unavailable(
                    capabilities.tradingUnavailableReason ?? "Buy is unavailable."
                )
            }
            let call = RuntimeCall(
                moduleName: moduleName,
                callName: callName,
                args: PolkamarktBuyCall(
                    marketId: marketId,
                    outcome: outcome.rawValue,
                    collateralIn: collateralIn,
                    minSharesOut: minSharesOut
                )
            )
            return { try $0.adding(call: call) }
        case let .sell(marketId, outcome, sharesIn, minCollateralOut):
            guard capabilities.canTrade,
                  let callName = capabilities.resolvedCallName("sell") else {
                throw PolkamarktServiceError.unavailable(
                    capabilities.tradingUnavailableReason ?? "Sell is unavailable."
                )
            }
            let call = RuntimeCall(
                moduleName: moduleName,
                callName: callName,
                args: PolkamarktSellCall(
                    marketId: marketId,
                    outcome: outcome.rawValue,
                    sharesIn: sharesIn,
                    minCollateralOut: minCollateralOut
                )
            )
            return { try $0.adding(call: call) }
        case let .claimTrader(marketId):
            guard capabilities.canClaimTrader,
                  let callName = capabilities.resolvedCallName("claimMarket") else {
                throw PolkamarktServiceError.unavailable("Trader claim is unavailable on this runtime.")
            }
            let call = RuntimeCall(
                moduleName: moduleName,
                callName: callName,
                args: PolkamarktMarketActionCall(marketId: marketId)
            )
            return { try $0.adding(call: call) }
        case let .claimCreator(marketId):
            guard capabilities.canClaimCreator,
                  let callName = capabilities.resolvedCallName("claimCreatorFees") else {
                throw PolkamarktServiceError.unavailable("Creator claim is unavailable on this runtime.")
            }
            let call = RuntimeCall(
                moduleName: moduleName,
                callName: callName,
                args: PolkamarktMarketActionCall(marketId: marketId)
            )
            return { try $0.adding(call: call) }
        }
    }
}

protocol PolkamarktMutationExtrinsicExecuting: AnyObject {
    func estimateFee(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo
    func submit(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> String
}

final class PolkamarktMutationExtrinsicExecutor: PolkamarktMutationExtrinsicExecuting {
    private let service: ExtrinsicServiceProtocol
    private let signer: SigningWrapperProtocol

    init(service: ExtrinsicServiceProtocol, signer: SigningWrapperProtocol) {
        self.service = service
        self.signer = signer
    }

    func estimateFee(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo {
        try await withCheckedThrowingContinuation { continuation in
            service.estimateFee(builder, runningIn: .main) { continuation.resume(with: $0) }
        }
    }

    func submit(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            service.submit(builder, signer: signer, runningIn: .main) { continuation.resume(with: $0) }
        }
    }
}

struct PolkamarktAuthorizedSubmission {
    let builder: ExtrinsicBuilderClosure
    let executor: PolkamarktMutationExtrinsicExecuting
    let finalGuard: () throws -> Void
}

protocol PolkamarktMutationSubmissionAuthorizing {
    func authorize(_ mutation: PolkamarktMutation) async throws -> PolkamarktAuthorizedSubmission
}

final class PolkamarktMutationSubmissionAuthorizer: PolkamarktMutationSubmissionAuthorizing {
    private let expectedWalletId: MetaAccountId
    private let chainId: ChainModel.Id
    private let callBuilder: PolkamarktMutationCallBuilding
    private let chainRegistry: ChainRegistryProtocol
    private let settings: SettingsManagerProtocol
    private let keystore: KeystoreProtocol
    private let selectedWallet: () -> MetaAccountModel?

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        callBuilder: PolkamarktMutationCallBuilding,
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        settings: SettingsManagerProtocol = SettingsManager.shared,
        keystore: KeystoreProtocol = Keychain(),
        selectedWallet: @escaping () -> MetaAccountModel? = { SelectedWalletSettings.shared.value }
    ) {
        expectedWalletId = wallet.metaId
        chainId = chain.chainId
        self.callBuilder = callBuilder
        self.chainRegistry = chainRegistry
        self.settings = settings
        self.keystore = keystore
        self.selectedWallet = selectedWallet
    }

    func authorize(_ mutation: PolkamarktMutation) async throws -> PolkamarktAuthorizedSubmission {
        try validatePolicyAndWallet()
        let context = try await makeFreshContext()
        try await validateMutation(mutation, context: context)
        let builder = try callBuilder.builder(
            for: mutation,
            capabilities: context.capabilities
        )
        let dispatchInfo = try await context.executor.estimateFee(builder)
        guard let requiredFee = BigUInt(dispatchInfo.fee, radix: 10),
              requiredFee > .zero else {
            throw PolkamarktSubmissionError.runtimeUnavailable
        }

        let balances = await PolkamarktAccountCapabilityProvider(
            wallet: context.wallet,
            chain: context.chain
        ).accountCapability()
        guard balances.collateralAssetKey != nil,
              balances.feeAssetKey != nil,
              balances.feeSpendable != nil else {
            throw PolkamarktSubmissionError.balanceUnavailable
        }
        if let collateral = mutation.requiredCollateral {
            guard let available = balances.collateralSpendable else {
                throw PolkamarktSubmissionError.balanceUnavailable
            }
            guard available >= collateral else {
                throw PolkamarktSubmissionError.insufficientCollateral
            }
        }
        guard let feeBalance = balances.feeSpendable,
              feeBalance >= requiredFee else {
            throw PolkamarktSubmissionError.insufficientFee
        }

        try validateCurrentContext(context)
        // Re-read runtime market status, quote/position or claim after fee and
        // balance work so caller-built mutations cannot bypass the final state.
        try await validateMutation(mutation, context: context)
        try validateCurrentContext(context)
        return PolkamarktAuthorizedSubmission(
            builder: builder,
            executor: context.executor,
            finalGuard: { [weak self] in
                guard let self else { throw PolkamarktSubmissionError.runtimeUnavailable }
                try self.validateCurrentContext(context)
            }
        )
    }

    private struct Context {
        let wallet: MetaAccountModel
        let chain: ChainModel
        let account: ChainAccountResponse
        let runtime: RuntimeProviderProtocol
        let connection: JSONRPCEngine
        let runtimeSpecVersion: UInt32
        let address: String
        let rpc: PolkamarktRPCClient
        let catalog: PolkamarktRuntimeCatalogProviding
        let capabilities: PolkamarktRuntimeCapabilities
        let executor: PolkamarktMutationExtrinsicExecuting
    }

    private func makeFreshContext() async throws -> Context {
        guard chainId == PolkamarktConstants.soraChainId,
              let wallet = selectedWallet(),
              wallet.metaId == expectedWalletId,
              let chain = chainRegistry.getChain(for: chainId),
              !chain.disabled,
              !chain.isTestnet,
              let runtime = chainRegistry.getRuntimeProvider(for: chainId),
              let snapshot = runtime.snapshot,
              let connection = chainRegistry.getConnection(for: chainId),
              let rpcURL = PolkamarktEndpointResolver.rpcHTTPURL(for: chain),
              let catalog = PolkamarktRuntimeStorageCatalogProvider(chain: chain) else {
            if selectedWallet()?.metaId != expectedWalletId {
                throw PolkamarktSubmissionError.selectedWalletChanged
            }
            throw PolkamarktSubmissionError.runtimeUnavailable
        }
        let account = try validateSigningAccount(wallet: wallet, on: chain)
        guard let address = account.toAddress() else {
            throw PolkamarktSubmissionError.signerUnavailable
        }
        let rpc = PolkamarktRPCClient(endpoint: rpcURL)
        let capabilities = await PolkamarktCapabilityNegotiator.negotiate(
            chain: chain,
            rpcClient: rpc
        )
        let signer = SigningWrapper(
            keystore: keystore,
            metaId: wallet.metaId,
            accountResponse: account
        )
        let extrinsic = ExtrinsicService(
            accountId: account.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: account.cryptoType,
            runtimeRegistry: runtime,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )
        return Context(
            wallet: wallet,
            chain: chain,
            account: account,
            runtime: runtime,
            connection: connection,
            runtimeSpecVersion: snapshot.specVersion,
            address: address,
            rpc: rpc,
            catalog: catalog,
            capabilities: capabilities,
            executor: PolkamarktMutationExtrinsicExecutor(service: extrinsic, signer: signer)
        )
    }

    private func validateMutation(_ mutation: PolkamarktMutation, context: Context) async throws {
        guard BigUInt(mutation.marketId, radix: 10) != nil else {
            throw PolkamarktSubmissionError.marketUnavailable
        }
        let runtimeMarkets = try await context.catalog.markets()
        let entries = runtimeMarkets.filter {
            $0.marketId == mutation.marketId
        }
        guard entries.count == 1, let market = entries.first else {
            throw PolkamarktSubmissionError.marketUnavailable
        }
        let status = market.status?.lowercased() ?? ""

        switch mutation {
        case let .buy(marketId, outcome, collateralIn, minSharesOut):
            try await validateOpenMarket(market, status: status, context: context)
            let quote = try await context.rpc.quoteBuy(
                marketId: marketId,
                outcome: outcome,
                collateralIn: collateralIn
            )
            try PolkamarktMutationQuoteValidator.validateBuy(
                marketId: marketId,
                outcome: outcome,
                collateralIn: collateralIn,
                minSharesOut: minSharesOut,
                quote: quote
            )
        case let .sell(marketId, outcome, sharesIn, minCollateralOut):
            try await validateOpenMarket(market, status: status, context: context)
            let quote = try await context.rpc.quoteSell(
                marketId: marketId,
                outcome: outcome,
                sharesIn: sharesIn
            )
            try PolkamarktMutationQuoteValidator.validateSell(
                marketId: marketId,
                outcome: outcome,
                sharesIn: sharesIn,
                minCollateralOut: minCollateralOut,
                quote: quote
            )
            let position = try await context.rpc.claimable(
                account: context.address,
                marketId: marketId
            )
            guard position.marketId == marketId,
                  position.account == context.address,
                  !position.status.lowercased().contains("resolv"),
                  !position.status.lowercased().contains("cancel"),
                  let held = BigUInt(
                      outcome == .yes ? position.yesShares : position.noShares,
                      radix: 10
                  ),
                  let requested = BigUInt(sharesIn, radix: 10),
                  requested > .zero,
                  held >= requested else {
                throw PolkamarktSubmissionError.insufficientShares
            }
        case let .claimTrader(marketId):
            guard status == "resolved" else {
                throw PolkamarktSubmissionError.claimUnavailable
            }
            let claim = try await context.rpc.claimable(
                account: context.address,
                marketId: marketId
            )
            guard claim.marketId == marketId,
                  claim.account == context.address,
                  claim.status.lowercased() == "resolved",
                  (BigUInt(claim.effectiveTraderPayout, radix: 10) ?? .zero) > .zero else {
                throw PolkamarktSubmissionError.claimUnavailable
            }
        case let .claimCreator(marketId):
            guard status == "resolved" else {
                throw PolkamarktSubmissionError.claimUnavailable
            }
            let claim = try await context.rpc.claimable(
                account: context.address,
                marketId: marketId
            )
            guard claim.marketId == marketId,
                  claim.account == context.address,
                  claim.status.lowercased() == "resolved",
                  claim.isCreator,
                  market.creator == context.address,
                  (BigUInt(claim.creatorFees, radix: 10) ?? .zero) > .zero else {
                throw PolkamarktSubmissionError.claimUnavailable
            }
        }
    }

    private func validateOpenMarket(
        _ market: PolkamarktRuntimeMarketEntry,
        status: String,
        context: Context
    ) async throws {
        guard status == "open",
              let close = market.closeBlock.flatMap({ BigUInt($0, radix: 10) }),
              let current = BigUInt(try await context.rpc.currentBlock(), radix: 10),
              current < close else {
            throw PolkamarktSubmissionError.marketClosed
        }
        let state = try await context.rpc.marketState(marketId: market.marketId)
        guard state.marketId == market.marketId else {
            throw PolkamarktSubmissionError.marketUnavailable
        }
    }

    private func validatePolicies() throws {
        guard MultiChainFeaturePolicy.current.polkamarktMutationsEnabled else {
            throw PolkamarktServiceError.actionsPaused
        }
        guard PolkaswapDisclaimerPolicy.isAccepted(in: settings) else {
            throw PolkamarktServiceError.unavailable(
                "Read and accept the current Polkaswap disclaimer before submitting a Polkamarkt transaction on SORA."
            )
        }
    }

    private func validatePolicyAndWallet() throws {
        try validatePolicies()
        guard selectedWallet()?.metaId == expectedWalletId else {
            throw PolkamarktSubmissionError.selectedWalletChanged
        }
    }

    private func validateCurrentContext(_ context: Context) throws {
        try validatePolicyAndWallet()
        guard let wallet = selectedWallet(),
              wallet.metaId == context.wallet.metaId,
              let chain = chainRegistry.getChain(for: chainId),
              chain == context.chain,
              !chain.disabled,
              !chain.isTestnet,
              let runtime = chainRegistry.getRuntimeProvider(for: chainId),
              ObjectIdentifier(runtime) == ObjectIdentifier(context.runtime),
              runtime.snapshot?.specVersion == context.runtimeSpecVersion,
              let connection = chainRegistry.getConnection(for: chainId),
              ObjectIdentifier(connection) == ObjectIdentifier(context.connection) else {
            throw PolkamarktSubmissionError.runtimeUnavailable
        }
        _ = try validateSigningAccount(wallet: wallet, on: chain, expected: context.account)
    }

    private func validateSigningAccount(
        wallet: MetaAccountModel,
        on chain: ChainModel,
        expected: ChainAccountResponse? = nil
    ) throws -> ChainAccountResponse {
        guard let account = wallet.fetch(for: chain.accountRequest()),
              expected.map({
                  $0.chainId == account.chainId &&
                      $0.walletId == account.walletId &&
                      $0.isChainAccount == account.isChainAccount &&
                      $0.accountId == account.accountId &&
                      $0.publicKey == account.publicKey &&
                      $0.cryptoType == account.cryptoType
              }) ?? true else {
            throw PolkamarktSubmissionError.signerUnavailable
        }
        let accountId = account.isChainAccount ? account.accountId : nil
        let tag = chain.keystoreTag(metaId: wallet.metaId, accountId: accountId)
        guard (try? keystore.checkKey(for: tag)) == true else {
            throw PolkamarktSubmissionError.signerUnavailable
        }
        return account
    }
}

final class PolkamarktMutationService {
    private let initialCapabilities: PolkamarktRuntimeCapabilities
    private let callBuilder: PolkamarktMutationCallBuilding
    private let submissionAuthorizer: PolkamarktMutationSubmissionAuthorizing
    private let initialExecutor: PolkamarktMutationExtrinsicExecuting
    private let mutationsEnabled: () -> Bool
    private let disclaimerAccepted: () -> Bool

    init?(
        wallet: MetaAccountModel,
        chain: ChainModel,
        capabilities: PolkamarktRuntimeCapabilities
    ) {
        let registry = ChainRegistryFacade.sharedRegistry
        guard let account = wallet.fetch(for: chain.accountRequest()),
              let runtimeService = registry.getRuntimeProvider(for: chain.chainId),
              let connection = registry.getConnection(for: chain.chainId) else {
            return nil
        }

        let accountId = account.isChainAccount ? account.accountId : nil
        let tag = KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)
        guard (try? Keychain().checkKey(for: tag)) == true else { return nil }

        let signer = SigningWrapper(
            keystore: Keychain(),
            metaId: wallet.metaId,
            accountResponse: account
        )
        let extrinsicService = ExtrinsicService(
            accountId: account.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: account.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )
        let callBuilder = PolkamarktMutationCallBuilder()
        initialCapabilities = capabilities
        self.callBuilder = callBuilder
        initialExecutor = PolkamarktMutationExtrinsicExecutor(
            service: extrinsicService,
            signer: signer
        )
        submissionAuthorizer = PolkamarktMutationSubmissionAuthorizer(
            wallet: wallet,
            chain: chain,
            callBuilder: callBuilder
        )
        mutationsEnabled = { MultiChainFeaturePolicy.current.polkamarktMutationsEnabled }
        disclaimerAccepted = { PolkaswapDisclaimerPolicy.isAccepted() }
    }

    init(
        initialCapabilities: PolkamarktRuntimeCapabilities,
        callBuilder: PolkamarktMutationCallBuilding,
        submissionAuthorizer: PolkamarktMutationSubmissionAuthorizing,
        initialExecutor: PolkamarktMutationExtrinsicExecuting,
        mutationsEnabled: @escaping () -> Bool,
        disclaimerAccepted: @escaping () -> Bool
    ) {
        self.initialCapabilities = initialCapabilities
        self.callBuilder = callBuilder
        self.submissionAuthorizer = submissionAuthorizer
        self.initialExecutor = initialExecutor
        self.mutationsEnabled = mutationsEnabled
        self.disclaimerAccepted = disclaimerAccepted
    }

    func submit(_ mutation: PolkamarktMutation) async throws -> String {
        guard mutationsEnabled() else {
            throw PolkamarktServiceError.actionsPaused
        }
        guard disclaimerAccepted() else {
            throw PolkamarktServiceError.unavailable(
                "Read and accept the current Polkaswap disclaimer before submitting a Polkamarkt transaction on SORA."
            )
        }

        let authorized = try await submissionAuthorizer.authorize(mutation)
        guard mutationsEnabled() else {
            throw PolkamarktServiceError.actionsPaused
        }
        guard disclaimerAccepted() else {
            throw PolkamarktServiceError.unavailable(
                "The current Polkaswap disclaimer has not been accepted."
            )
        }
        // All asynchronous market, quote, balance and fee checks have
        // completed. This synchronous object/spec/account check is the final
        // statement before invoking the fresh authorized executor.
        try authorized.finalGuard()
        return try await authorized.executor.submit(authorized.builder)
    }

    func estimateFee(for mutation: PolkamarktMutation) async throws -> RuntimeDispatchInfo {
        let builder = try callBuilder.builder(
            for: mutation,
            capabilities: initialCapabilities
        )
        return try await initialExecutor.estimateFee(builder)
    }
}

protocol PolkamarktRuntimeCatalogProviding {
    func markets() async throws -> [PolkamarktRuntimeMarketEntry]
}

struct EmptyPolkamarktRuntimeCatalogProvider: PolkamarktRuntimeCatalogProviding {
    func markets() async throws -> [PolkamarktRuntimeMarketEntry] { [] }
}

private enum PolkamarktStoredStatus: String, Decodable {
    case open = "Open"
    case locked = "Locked"
    case resolved = "Resolved"
    case cancelled = "Cancelled"

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let value = try container.decode(String.self)
        guard let status = Self(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported Polkamarkt status \(value)"
            )
        }
        self = status
    }
}

private struct PolkamarktStoredMarket: Decodable {
    let creator: AccountId
    let conditionId: UInt32
    let closeBlock: UInt32
    let status: PolkamarktStoredStatus

    private enum CodingKeys: String, CodingKey {
        case creator, conditionId, closeBlock, status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        creator = try container.decode(AccountId.self, forKey: .creator)
        conditionId = try container.decode(StringScaleMapper<UInt32>.self, forKey: .conditionId).value
        closeBlock = try container.decode(StringScaleMapper<UInt32>.self, forKey: .closeBlock).value
        status = try container.decode(PolkamarktStoredStatus.self, forKey: .status)
    }
}

private struct PolkamarktStoredCondition: Decodable {
    let question: Data

    private enum CodingKeys: String, CodingKey { case question }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let bytes = try container.decode([StringScaleMapper<UInt8>].self, forKey: .question)
        question = Data(bytes.map(\.value))
    }
}

private struct PolkamarktStoredConditionDetails: Decodable {
    let category: Data?

    private enum CodingKeys: String, CodingKey { case category }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let bytes = try? container.decode([StringScaleMapper<UInt8>].self, forKey: .category)
        category = bytes.map { Data($0.map(\.value)) }
    }
}

/// Runtime-backed catalog used alongside the indexer so newly created and
/// already-finalized markets remain discoverable during indexer lag. Reads are
/// performed through the registry's existing scoped SORA connection and never
/// create or retain a second websocket.
final class PolkamarktRuntimeStorageCatalogProvider: PolkamarktRuntimeCatalogProviding {
    private let chain: ChainModel
    private let runtimeService: RuntimeCodingServiceProtocol
    private let connection: JSONRPCEngine
    private let storageFactory: AsyncStorageRequestFactory

    init?(
        chain: ChainModel,
        storageFactory: AsyncStorageRequestFactory = AsyncStorageRequestDefault()
    ) {
        let registry = ChainRegistryFacade.sharedRegistry
        guard let runtimeService = registry.getRuntimeProvider(for: chain.chainId),
              let connection = registry.getConnection(for: chain.chainId) else {
            return nil
        }
        self.chain = chain
        self.runtimeService = runtimeService
        self.connection = connection
        self.storageFactory = storageFactory
    }

    func markets() async throws -> [PolkamarktRuntimeMarketEntry] {
        let factory = try await runtimeService.fetchCoderFactory()
        guard let module = factory.metadata.modules.first(where: {
            $0.name.caseInsensitiveCompare("Polkamarkt") == .orderedSame
        }),
            factory.metadata.getStorageMetadata(in: module.name, storageName: "Markets") != nil,
            factory.metadata.getStorageMetadata(in: module.name, storageName: "Conditions") != nil else {
            return []
        }

        let prefix = try StorageKeyFactory().createStorageKey(
            moduleName: module.name,
            storageName: "Markets"
        )
        let responses: [StorageResponse<PolkamarktStoredMarket>] = try await storageFactory.queryItemsByPrefix(
            engine: connection,
            keys: [prefix],
            factory: factory,
            storagePath: .polkamarktMarkets
        )
        let marketIdMapper = StorageKeySuffixMapper<StringScaleMapper<UInt32>>(
            type: "u32",
            suffixLength: MemoryLayout<UInt32>.size,
            coderFactoryClosure: { factory }
        )
        let decodedMarkets = responses.compactMap { response -> (UInt32, PolkamarktStoredMarket)? in
            guard let id = marketIdMapper.map(input: response.key)?.value,
                  let market = response.value else { return nil }
            return (id, market)
        }
        guard decodedMarkets.isNotEmpty else { return [] }

        let conditionIds = decodedMarkets.map { StringScaleMapper(value: $0.1.conditionId) }
        let conditionResponses: [StorageResponse<PolkamarktStoredCondition>] = try await storageFactory.queryItems(
            engine: connection,
            keyParams: conditionIds,
            factory: factory,
            storagePath: .polkamarktConditions
        )
        let conditions = Dictionary(
            uniqueKeysWithValues: zip(conditionIds, conditionResponses).compactMap { id, response in
                response.value.map { (id.value, $0) }
            }
        )

        var details = [UInt32: PolkamarktStoredConditionDetails]()
        if factory.metadata.getStorageMetadata(in: module.name, storageName: "ConditionDetails") != nil {
            let detailResponses: [StorageResponse<PolkamarktStoredConditionDetails>] = try await storageFactory.queryItems(
                engine: connection,
                keyParams: conditionIds,
                factory: factory,
                storagePath: .polkamarktConditionDetails
            )
            details = Dictionary(
                uniqueKeysWithValues: zip(conditionIds, detailResponses).compactMap { id, response in
                    response.value.map { (id.value, $0) }
                }
            )
        }

        return decodedMarkets.map { marketId, market in
            let condition = conditions[market.conditionId]
            let question = condition.flatMap { String(data: $0.question, encoding: .utf8) }
            let category = details[market.conditionId]?.category.flatMap {
                String(data: $0, encoding: .utf8)
            }
            return PolkamarktRuntimeMarketEntry(
                marketId: String(marketId),
                conditionId: String(market.conditionId),
                creator: try? market.creator.toAddress(using: chain.chainFormat),
                closeBlock: String(market.closeBlock),
                status: market.status.rawValue,
                mechanism: "DynamicPariMutuel",
                question: question,
                category: category
            )
        }
    }
}

struct PolkamarktSnapshot {
    let markets: [PolkamarktMarket]
    let currentBlock: String
    let capabilities: PolkamarktRuntimeCapabilities
}

enum PolkamarktEndpointResolver {
    static func rpcHTTPURL(for chain: ChainModel) -> URL? {
        guard let node = chain.selectedNode ?? chain.nodes.sorted(by: {
            $0.url.absoluteString < $1.url.absoluteString
        }).first else {
            return nil
        }
        var components = URLComponents(url: node.url, resolvingAgainstBaseURL: false)
        switch components?.scheme?.lowercased() {
        case "wss": components?.scheme = "https"
        case "ws": components?.scheme = "http"
        case "https", "http": break
        default: return nil
        }
        if let path = components?.path, path.hasSuffix("public-ws") {
            components?.path = String(path.dropLast(3))
        }
        return components?.url
    }
}

final class PolkamarktLiveService {
    let wallet: MetaAccountModel
    let chain: ChainModel
    let rpcClient: PolkamarktRPCClient?
    let indexerClient: PolkamarktIndexerClient?
    private let runtimeCatalog: PolkamarktRuntimeCatalogProviding
    private let accountCapabilityProvider: PolkamarktAccountCapabilityProviding

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        runtimeCatalog: PolkamarktRuntimeCatalogProviding? = nil,
        accountCapabilityProvider: PolkamarktAccountCapabilityProviding? = nil,
        rpcTransport: PolkamarktHTTPTransport = PolkamarktURLSessionTransport(),
        indexerTransport: PolkamarktHTTPTransport = PolkamarktURLSessionTransport()
    ) {
        self.wallet = wallet
        self.chain = chain
        if let runtimeCatalog {
            self.runtimeCatalog = runtimeCatalog
        } else if let runtimeCatalog = PolkamarktRuntimeStorageCatalogProvider(chain: chain) {
            self.runtimeCatalog = runtimeCatalog
        } else {
            self.runtimeCatalog = EmptyPolkamarktRuntimeCatalogProvider()
        }
        self.accountCapabilityProvider = accountCapabilityProvider ?? PolkamarktAccountCapabilityProvider(
            wallet: wallet,
            chain: chain
        )
        rpcClient = PolkamarktEndpointResolver.rpcHTTPURL(for: chain).map {
            PolkamarktRPCClient(endpoint: $0, transport: rpcTransport)
        }
        if let endpoint = chain.externalApi?.history?.url {
            indexerClient = PolkamarktIndexerClient(endpoint: endpoint, transport: indexerTransport)
        } else {
            indexerClient = nil
        }
    }

    func snapshot() async throws -> PolkamarktSnapshot {
        let currentBlock: String
        if let rpcClient {
            currentBlock = (try? await rpcClient.currentBlock()) ?? "0"
        } else {
            currentBlock = "0"
        }
        let capabilities = await PolkamarktCapabilityNegotiator.negotiate(
            chain: chain,
            rpcClient: rpcClient
        )

        var indexerFailure: Error?
        let indexed: [PolkamarktMarket]
        do {
            indexed = try await indexerClient?.markets() ?? []
        } catch {
            indexerFailure = error
            indexed = []
        }
        let runtime = (try? await runtimeCatalog.markets()) ?? []

        var states = [String: PolkamarktMarketState]()
        if capabilities.hasRPC("marketState"), let rpcClient {
            let ids = Set(indexed.map(\.marketId) + runtime.map(\.marketId))
            await withTaskGroup(of: (String, PolkamarktMarketState)?.self) { group in
                ids.prefix(64).forEach { marketId in
                    group.addTask {
                        guard let state = try? await rpcClient.marketState(marketId: marketId) else { return nil }
                        return (marketId, state)
                    }
                }
                for await result in group {
                    if let result { states[result.0] = result.1 }
                }
            }
        }

        if indexed.isEmpty, runtime.isEmpty, let indexerFailure {
            throw indexerFailure
        }

        return PolkamarktSnapshot(
            markets: PolkamarktCatalog.merge(
                indexed: indexed,
                runtime: runtime,
                states: states,
                currentBlock: currentBlock
            ),
            currentBlock: currentBlock,
            capabilities: capabilities
        )
    }

    func history(marketId: String) async -> [PolkamarktHistoryPoint] {
        (try? await indexerClient?.history(marketId: marketId)) ?? []
    }

    func positions() async -> [PolkamarktPosition] {
        guard let account = wallet.fetch(for: chain.accountRequest())?.toAddress() else { return [] }
        return (try? await indexerClient?.positions(account: account)) ?? []
    }

    func indexedActivity() async -> PolkamarktIndexedAccountActivity {
        (try? await indexedActivityResult()) ?? PolkamarktIndexedAccountActivity(
            positions: [],
            trades: []
        )
    }

    func indexedActivityResult() async throws -> PolkamarktIndexedAccountActivity {
        guard let account = wallet.fetch(for: chain.accountRequest())?.toAddress() else {
            throw PolkamarktServiceError.unavailable("Add a SORA account to load Polkamarkt positions.")
        }
        guard let indexerClient else {
            throw PolkamarktServiceError.unavailable("The SORA account indexer is unavailable.")
        }
        async let positions = indexerClient.positions(account: account)
        async let trades = indexerClient.trades(account: account)
        let values = try await(positions, trades)
        return PolkamarktIndexedAccountActivity(positions: values.0, trades: values.1)
    }

    func claimable(marketId: String) async -> PolkamarktClaimable? {
        guard let account = wallet.fetch(for: chain.accountRequest())?.toAddress() else { return nil }
        return try? await rpcClient?.claimable(account: account, marketId: marketId)
    }

    func accountCapability() async -> PolkamarktAccountCapability {
        await accountCapabilityProvider.accountCapability()
    }
}

final class PolkamarktMarketListViewController: UIViewController, UISearchResultsUpdating {
    private enum Section: Int, CaseIterable { case open, finalized }

    private let service: PolkamarktLiveService
    private let initialMarketId: String?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let activity = UIActivityIndicatorView(style: .medium)
    private var snapshot: PolkamarktSnapshot?
    private var query = ""
    private var openedInitialMarket = false

    init(wallet: MetaAccountModel, chain: ChainModel, marketId: String? = nil) {
        service = PolkamarktLiveService(wallet: wallet, chain: chain)
        initialMarketId = marketId
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Polkamarkt"
        view.backgroundColor = R.color.colorBlack19()
        configureTable()
        configureSearch()
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Positions", style: .plain, target: self, action: #selector(openPositions)),
            UIBarButtonItem(customView: activity)
        ]
        reload()
    }

    func updateSearchResults(for searchController: UISearchController) {
        query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        tableView.reloadData()
    }

    private func configureTable() {
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PolkamarktMarket")
        let header = UILabel(frame: CGRect(x: 0, y: 0, width: 1, height: 62))
        header.text = "  SORA prediction markets · KUSD collateral · XOR network fees"
        header.textColor = R.color.colorLightGray()
        header.font = .systemFont(ofSize: 13, weight: .medium)
        header.numberOfLines = 2
        tableView.tableHeaderView = header
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func configureSearch() {
        let controller = UISearchController(searchResultsController: nil)
        controller.obscuresBackgroundDuringPresentation = false
        controller.searchResultsUpdater = self
        controller.searchBar.placeholder = "Search title, category, or market ID"
        navigationItem.searchController = controller
        definesPresentationContext = true
    }

    private func reload() {
        activity.startAnimating()
        Task { [weak self] in
            guard let self else { return }
            do {
                let value = try await service.snapshot()
                await MainActor.run {
                    self.snapshot = value
                    self.activity.stopAnimating()
                    self.tableView.reloadData()
                    self.openInitialMarketIfNeeded()
                }
            } catch {
                await MainActor.run {
                    self.activity.stopAnimating()
                    self.presentMessage(title: "Polkamarkt unavailable", message: error.localizedDescription)
                }
            }
        }
    }

    private func filteredMarkets(for section: Section) -> [PolkamarktMarket] {
        guard let snapshot else { return [] }
        return snapshot.markets.filter { market in
            let isOpen = market.displayStatus(currentBlock: snapshot.currentBlock).isOpen
            guard (section == .open) == isOpen else { return false }
            guard query.isNotEmpty else { return true }
            let value = [market.marketId, market.title, market.category].joined(separator: " ")
            return value.localizedCaseInsensitiveContains(query)
        }
    }

    private func openInitialMarketIfNeeded() {
        guard !openedInitialMarket,
              let initialMarketId,
              let market = snapshot?.markets.first(where: { $0.marketId == initialMarketId }) else { return }
        openedInitialMarket = true
        open(market)
    }

    private func open(_ market: PolkamarktMarket) {
        guard let snapshot else { return }
        let controller = PolkamarktMarketDetailViewController(
            market: market,
            currentBlock: snapshot.currentBlock,
            capabilities: snapshot.capabilities,
            service: service
        )
        controller.hidesBottomBarWhenPushed = false
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openPositions() {
        let controller = PolkamarktPositionsViewController(service: service)
        controller.hidesBottomBarWhenPushed = false
        navigationController?.pushViewController(controller, animated: true)
    }

    private func presentMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension PolkamarktMarketListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in _: UITableView) -> Int { Section.allCases.count }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        return section == .open ? "Open markets" : "Closed and resolved"
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        let count = filteredMarkets(for: section).count
        return section == .open ? max(count, 1) : count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PolkamarktMarket", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.color = R.color.colorWhite() ?? .white
        config.secondaryTextProperties.color = R.color.colorLightGray() ?? .lightGray
        cell.backgroundColor = R.color.colorWhite8()

        guard let section = Section(rawValue: indexPath.section),
              let market = filteredMarkets(for: section)[safe: indexPath.row] else {
            config.text = snapshot == nil ? "Loading markets…" : "No active markets"
            config.secondaryText = "Closed markets and positions remain available below."
            cell.selectionStyle = .none
            cell.accessoryType = .none
            cell.contentConfiguration = config
            return cell
        }

        let probability = market.yesProbability.flatMap { Decimal(string: $0) }.map {
            "YES \(NSDecimalNumber(decimal: $0 * 100).stringValue)%"
        } ?? "Probability unavailable"
        config.text = market.title
        config.secondaryText = "#\(market.marketId) · \(market.category) · \(probability) · KUSD"
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        cell.contentConfiguration = config
        return cell
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section),
              let market = filteredMarkets(for: section)[safe: indexPath.row] else { return }
        open(market)
    }
}

final class PolkamarktMarketDetailViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case network, details, history, trade, claims
    }

    private let market: PolkamarktMarket
    private let currentBlock: String
    private let capabilities: PolkamarktRuntimeCapabilities
    private let service: PolkamarktLiveService
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var history: [PolkamarktHistoryPoint] = []
    private var claimable: PolkamarktClaimable?
    private var accountCapability: PolkamarktAccountCapability?

    init(
        market: PolkamarktMarket,
        currentBlock: String,
        capabilities: PolkamarktRuntimeCapabilities,
        service: PolkamarktLiveService
    ) {
        self.market = market
        self.currentBlock = currentBlock
        self.capabilities = capabilities
        self.service = service
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Market #\(market.marketId)"
        view.backgroundColor = R.color.colorBlack19()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareMarket)
        )
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PolkamarktDetail")
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
        loadSupplementalData()
    }

    private func loadSupplementalData() {
        Task { [weak self] in
            guard let self else { return }
            async let history = service.history(marketId: market.marketId)
            async let claimable = service.claimable(marketId: market.marketId)
            async let accountCapability = service.accountCapability()
            let values = await(history, claimable, accountCapability)
            await MainActor.run {
                self.history = values.0
                self.claimable = values.1
                self.accountCapability = values.2
                self.tableView.reloadData()
            }
        }
    }

    @objc private func shareMarket() {
        var components = URLComponents()
        components.scheme = "fearless"
        components.host = "defi"
        components.path = "/polkamarkt/\(market.marketId)"
        guard let url = components.url else { return }
        let controller = UIActivityViewController(
            activityItems: [market.title, url],
            applicationActivities: nil
        )
        present(controller, animated: true)
    }

    private func requestTrade(isBuy: Bool, outcome: PolkamarktOutcome) {
        guard market.displayStatus(currentBlock: currentBlock).isOpen else {
            presentMessage(title: "Market closed", message: "This market is closed at the current SORA block.")
            return
        }
        guard capabilities.canTrade else {
            presentMessage(
                title: "Trading unavailable",
                message: capabilities.tradingUnavailableReason ?? "No supported runtime route is available."
            )
            return
        }
        guard MultiChainFeaturePolicy.current.polkamarktMutationsEnabled else {
            presentMessage(title: "Actions paused", message: PolkamarktServiceError.actionsPaused.localizedDescription)
            return
        }
        guard let accountCapability else {
            presentMessage(
                title: "Balances unavailable",
                message: "Wait for the current SORA KUSD and XOR balances to finish loading."
            )
            return
        }
        let initialCollateralRequirement = isBuy ? BigUInt(1) : nil
        if let reason = accountCapability.failureReason(requiredCollateral: initialCollateralRequirement) {
            presentMessage(title: "Action unavailable", message: reason)
            return
        }
        guard let rpc = service.rpcClient,
              let mutationService = PolkamarktMutationService(
                  wallet: service.wallet,
                  chain: service.chain,
                  capabilities: capabilities
              ) else {
            presentMessage(title: "Cannot sign", message: PolkamarktServiceError.watchOnly.localizedDescription)
            return
        }

        let alert = UIAlertController(
            title: isBuy ? "Buy \(outcome.rawValue)" : "Sell \(outcome.rawValue)",
            message: isBuy ? "Enter KUSD collateral." : "Enter outcome shares.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.keyboardType = .decimalPad
            field.placeholder = isBuy ? "KUSD amount" : "Share amount"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Get quote", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let text = alert?.textFields?.first?.text,
                  let decimal = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
                  decimal > .zero,
                  let planks = decimal.toSubstrateAmount(precision: Int16(PolkamarktConstants.precision)) else {
                self?.presentMessage(title: "Invalid amount", message: "Enter a positive decimal amount.")
                return
            }
            Task {
                do {
                    let mutation: PolkamarktMutation
                    let quoteSummary: String
                    if isBuy {
                        let quote = try await rpc.quoteBuy(
                            marketId: self.market.marketId,
                            outcome: outcome,
                            collateralIn: planks.description
                        )
                        let minimum = ((BigUInt(quote.sharesOut, radix: 10) ?? .zero) * 99 / 100).description
                        mutation = .buy(
                            marketId: self.market.marketId,
                            outcome: outcome,
                            collateralIn: quote.collateralIn,
                            minSharesOut: minimum
                        )
                        quoteSummary = "Receive about \(Self.natural(quote.sharesOut)) shares\nMarket fee: \(Self.natural(quote.feeAmount)) KUSD"
                    } else {
                        let quote = try await rpc.quoteSell(
                            marketId: self.market.marketId,
                            outcome: outcome,
                            sharesIn: planks.description
                        )
                        let minimum = ((BigUInt(quote.collateralOut, radix: 10) ?? .zero) * 99 / 100).description
                        mutation = .sell(
                            marketId: self.market.marketId,
                            outcome: outcome,
                            sharesIn: quote.sharesIn,
                            minCollateralOut: minimum
                        )
                        quoteSummary = "Receive about \(Self.natural(quote.collateralOut)) KUSD\nMarket fee: \(Self.natural(quote.feeAmount)) KUSD"
                    }
                    let fee = try await mutationService.estimateFee(for: mutation)
                    await MainActor.run {
                        self.confirm(
                            mutation: mutation,
                            mutationService: mutationService,
                            requiredFee: BigUInt(fee.fee, radix: 10) ?? .zero,
                            summary: "\(quoteSummary)\nSORA network fee: \(Self.natural(fee.fee)) XOR"
                        )
                    }
                } catch {
                    await MainActor.run {
                        self.presentMessage(title: "Quote unavailable", message: error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func confirm(
        mutation: PolkamarktMutation,
        mutationService: PolkamarktMutationService,
        requiredFee: BigUInt,
        summary: String
    ) {
        let alert = UIAlertController(
            title: "Confirm on SORA",
            message: "KUSD collateral · XOR fees\n\n\(summary)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Confirm", style: .default) { [weak self] _ in
            Task {
                do {
                    guard MultiChainFeaturePolicy.current.polkamarktMutationsEnabled else {
                        throw PolkamarktServiceError.actionsPaused
                    }
                    guard let self else { return }
                    let capability = await self.service.accountCapability()
                    if let reason = capability.failureReason(
                        requiredCollateral: mutation.requiredCollateral,
                        requiredFee: requiredFee
                    ) {
                        throw PolkamarktServiceError.unavailable(reason)
                    }
                    let hash = try await mutationService.submit(mutation)
                    await MainActor.run {
                        self.presentMessage(title: "Submitted", message: "SORA extrinsic \(hash)")
                    }
                } catch {
                    await MainActor.run {
                        self?.presentMessage(title: "Transaction failed", message: error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func requestClaim(creator: Bool) {
        guard MultiChainFeaturePolicy.current.polkamarktMutationsEnabled else {
            presentMessage(title: "Actions paused", message: PolkamarktServiceError.actionsPaused.localizedDescription)
            return
        }
        guard let accountCapability else {
            presentMessage(
                title: "Balances unavailable",
                message: "Wait for the current SORA KUSD and XOR balances to finish loading."
            )
            return
        }
        if let reason = accountCapability.failureReason() {
            presentMessage(title: "Claim unavailable", message: reason)
            return
        }
        guard let claimable else {
            presentMessage(title: "Claim unavailable", message: "No authoritative runtime claim is available for this account.")
            return
        }
        let amount = creator ? claimable.creatorFees : claimable.effectiveTraderPayout
        guard (BigUInt(amount, radix: 10) ?? .zero) > .zero else {
            presentMessage(title: "Nothing to claim", message: "The runtime reports no claimable KUSD for this action.")
            return
        }
        guard !creator || claimable.isCreator else {
            presentMessage(title: "Creator claim unavailable", message: "This SORA account is not the market creator.")
            return
        }
        guard let mutationService = PolkamarktMutationService(
            wallet: service.wallet,
            chain: service.chain,
            capabilities: capabilities
        ) else {
            presentMessage(title: "Cannot sign", message: PolkamarktServiceError.watchOnly.localizedDescription)
            return
        }
        let mutation: PolkamarktMutation = creator
            ? .claimCreator(marketId: market.marketId)
            : .claimTrader(marketId: market.marketId)

        Task {
            do {
                let fee = try await mutationService.estimateFee(for: mutation)
                await MainActor.run {
                    self.confirm(
                        mutation: mutation,
                        mutationService: mutationService,
                        requiredFee: BigUInt(fee.fee, radix: 10) ?? .zero,
                        summary: "Claim \(Self.natural(amount)) KUSD\nSORA network fee: \(Self.natural(fee.fee)) XOR"
                    )
                }
            } catch {
                await MainActor.run {
                    self.presentMessage(title: "Claim unavailable", message: error.localizedDescription)
                }
            }
        }
    }

    private func presentMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    static func natural(_ planks: String) -> String {
        guard let value = BigUInt(planks, radix: 10),
              let decimal = Decimal.fromSubstrateAmount(value, precision: Int16(PolkamarktConstants.precision)) else {
            return planks
        }
        return NSDecimalNumber(decimal: decimal).stringValue
    }
}

extension PolkamarktMarketDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in _: UITableView) -> Int { Section.allCases.count }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .network: return "Network and collateral"
        case .details: return market.title
        case .history: return "YES probability history"
        case .trade: return "Trade"
        case .claims: return "Claims"
        case .none: return nil
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .network: return 1
        case .details: return 4
        case .history: return max(min(history.count, 5), 1)
        case .trade: return 4
        case .claims: return 2
        case .none: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PolkamarktDetail", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.color = R.color.colorWhite() ?? .white
        config.secondaryTextProperties.color = R.color.colorLightGray() ?? .lightGray
        cell.backgroundColor = R.color.colorWhite8()
        cell.accessoryType = .none
        cell.selectionStyle = .none

        switch Section(rawValue: indexPath.section) {
        case .network:
            config.text = "SORA · KUSD collateral · XOR fees"
            if let accountCapability,
               let collateral = accountCapability.collateralSpendable,
               let fee = accountCapability.feeSpendable {
                config.secondaryText = "Spendable: \(Self.natural(collateral.description)) KUSD · \(Self.natural(fee.description)) XOR"
            } else if let reason = accountCapability?.failureReason() {
                config.secondaryText = reason
            } else {
                config.secondaryText = capabilities.tradingUnavailableReason ?? "Loading authoritative SORA balances…"
            }
        case .details:
            let rows: [(String, String)] = [
                ("Status", market.displayStatus(currentBlock: currentBlock).rawValue.capitalized),
                ("Category", market.category),
                ("YES probability", market.yesProbability.map { "\((Decimal(string: $0) ?? .zero) * 100)%" } ?? "Unavailable"),
                ("Liquidity", "\(market.liquidityUSD) KUSD")
            ]
            config.text = rows[indexPath.row].0
            config.secondaryText = rows[indexPath.row].1
        case .history:
            guard let point = Array(history.suffix(5))[safe: indexPath.row] else {
                config.text = "Probability history unavailable"
                config.secondaryText = "The indexer has not returned snapshots for this market."
                break
            }
            config.text = "Block \(point.blockHeight ?? "—")"
            config.secondaryText = "YES \((Decimal(string: point.probability) ?? .zero) * 100)%"
        case .trade:
            let rows = ["Buy YES with KUSD", "Buy NO with KUSD", "Sell YES for KUSD", "Sell NO for KUSD"]
            config.text = rows[indexPath.row]
            config.secondaryText = capabilities.canTrade ? "Quote from the SORA runtime" : capabilities.tradingUnavailableReason
            cell.accessoryType = capabilities.canTrade ? .disclosureIndicator : .none
            cell.selectionStyle = .default
        case .claims:
            let creator = indexPath.row == 1
            let amount = creator ? claimable?.creatorFees : claimable?.effectiveTraderPayout
            config.text = creator ? "Claim creator fees" : "Claim trader payout"
            config.secondaryText = amount.map { "\(Self.natural($0)) KUSD · fee paid in XOR" } ??
                (creator ? "Requires creator claim runtime capability" : "Uses claimable payout or trader payout fallback")
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        case .none:
            break
        }
        cell.contentConfiguration = config
        return cell
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .trade:
            let isBuy = indexPath.row < 2
            let outcome: PolkamarktOutcome = indexPath.row.isMultiple(of: 2) ? .yes : .no
            requestTrade(isBuy: isBuy, outcome: outcome)
        case .claims:
            requestClaim(creator: indexPath.row == 1)
        default:
            break
        }
    }
}

final class PolkamarktPositionsViewController: UITableViewController {
    private enum Section: Int, CaseIterable { case positions, activity }

    private let service: PolkamarktLiveService
    private var positions: [PolkamarktPosition] = []
    private var trades: [PolkamarktTrade] = []

    init(service: PolkamarktLiveService) {
        self.service = service
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Positions & activity"
        tableView.backgroundColor = R.color.colorBlack19()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PolkamarktPosition")
        let header = UILabel(frame: CGRect(x: 0, y: 0, width: 1, height: 56))
        header.text = "  SORA positions · values in KUSD · claims pay XOR fees"
        header.textColor = R.color.colorLightGray()
        header.numberOfLines = 2
        header.font = .systemFont(ofSize: 13, weight: .medium)
        tableView.tableHeaderView = header

        Task { [weak self] in
            guard let self else { return }
            let activity = await service.indexedActivity()
            await MainActor.run {
                self.positions = activity.positions
                self.trades = activity.trades
                self.tableView.reloadData()
            }
        }
    }

    override func numberOfSections(in _: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section) == .positions ? "Your positions" : "Indexed trade activity"
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section(rawValue: section) == .positions ? max(positions.count, 1) : max(trades.count, 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PolkamarktPosition", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.color = R.color.colorWhite() ?? .white
        config.secondaryTextProperties.color = R.color.colorLightGray() ?? .lightGray
        cell.backgroundColor = R.color.colorWhite8()
        if Section(rawValue: indexPath.section) == .positions {
            if let position = positions[safe: indexPath.row] {
                config.text = "Market #\(position.marketId) · \(position.outcome.uppercased())"
                config.secondaryText = "\(PolkamarktMarketDetailViewController.natural(position.shares)) shares · \(position.status)"
            } else {
                config.text = "No Polkamarkt positions"
                config.secondaryText = "Positions will appear after an indexed SORA trade."
            }
        } else if let trade = trades[safe: indexPath.row] {
            config.text = "\(trade.side.capitalized) \(trade.outcome.uppercased()) · market #\(trade.marketId)"
            config.secondaryText = "\(PolkamarktMarketDetailViewController.natural(trade.collateral)) KUSD · \(PolkamarktMarketDetailViewController.natural(trade.sharesOut)) shares · fee \(PolkamarktMarketDetailViewController.natural(trade.fee)) KUSD · block \(trade.blockNumber)"
        } else {
            config.text = "No indexed trade activity"
            config.secondaryText = "Completed buys and sells appear here when the indexer catches up."
        }
        cell.contentConfiguration = config
        return cell
    }
}

struct PolkamarktDeepLinkRequested: EventProtocol {
    let marketId: String

    func accept(visitor: EventVisitorProtocol) {
        visitor.processPolkamarktDeepLinkRequested(event: self)
    }
}

final class PolkamarktDeepLinkHandler: URLHandlingServiceProtocol {
    private static let pendingKey = "polkamarkt.deep_link.pending_market_id"
    private let eventCenter: EventCenterProtocol
    private let userDefaults: UserDefaults

    init(
        eventCenter: EventCenterProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.eventCenter = eventCenter
        self.userDefaults = userDefaults
    }

    func handle(url: URL) -> Bool {
        guard url.scheme?.lowercased() == "fearless",
              url.host?.lowercased() == "defi" else { return false }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 2,
              components[0].lowercased() == "polkamarkt",
              let id = BigUInt(components[1], radix: 10),
              id <= BigUInt(UInt32.max) else { return false }

        let marketId = id.description
        userDefaults.set(marketId, forKey: Self.pendingKey)
        eventCenter.notify(with: PolkamarktDeepLinkRequested(marketId: marketId))
        return true
    }

    static func consumePending(userDefaults: UserDefaults = .standard) -> String? {
        guard let marketId = userDefaults.string(forKey: pendingKey) else { return nil }
        userDefaults.removeObject(forKey: pendingKey)
        return marketId
    }
}
