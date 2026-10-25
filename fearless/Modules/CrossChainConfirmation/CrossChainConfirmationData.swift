import BigInt
import Foundation
import RobinHood
import SoraKeystore
import SSFExtrinsicKit
import SSFModels
import SSFRuntimeCodingService
import SSFStorageQueryKit
import SSFUtils
import SSFXCM

struct CrossChainConfirmationData {
    let wallet: MetaAccountModel
    let originChainAsset: ChainAsset
    let destChainModel: ChainModel
    let amount: BigUInt
    let displayAmount: String
    let originChainFee: BalanceViewModelProtocol
    let destChainFee: BalanceViewModelProtocol
    let destChainFeeDecimal: Decimal
    let recipientAddress: String
    let reviewedRoute: ReviewedCrossChainRouteContext
}

enum ReviewedCrossChainSubmissionError: LocalizedError, Equatable {
    case actionsPaused
    case executionAdapterUnavailable
    case unreviewedRoute
    case selectedWalletChanged
    case signerUnavailable
    case runtimeUnavailable
    case wrongNetwork
    case runtimeCallUnavailable
    case invalidRecipient
    case invalidAmount
    case belowMinimum
    case destinationFeeUnavailable
    case destinationFeeChanged
    case destinationFeeTooHigh
    case balanceUnavailable
    case insufficientAssetBalance
    case insufficientFeeBalance

    var errorDescription: String? {
        switch self {
        case .actionsPaused:
            return "Cross-chain actions are temporarily disabled by the remote safety switch."
        case .executionAdapterUnavailable:
            return ReviewedXcmExecutionAuthority.unavailableReason
        case .unreviewedRoute:
            return "This exact origin network, canonical asset, destination network, and runtime call are not in the reviewed route registry."
        case .selectedWalletChanged:
            return "The selected wallet changed. Review the route again before submitting."
        case .signerUnavailable:
            return "A local signing key for the selected origin account is unavailable."
        case .runtimeUnavailable:
            return "The current origin runtime or connection is unavailable."
        case .wrongNetwork:
            return "The connected node does not belong to the reviewed origin network. Reconnect and review the route again."
        case .runtimeCallUnavailable:
            return "The current runtime does not expose the reviewed bridge call at its reviewed pallet and call index, or encodes it differently."
        case .invalidRecipient:
            return "The destination address is invalid for the reviewed destination network, or belongs to a runtime system account that no one can spend from."
        case .invalidAmount:
            return "Enter a positive cross-chain amount."
        case .belowMinimum:
            return "The amount is below the reviewed minimum for this exact route."
        case .destinationFeeUnavailable:
            return "A current destination fee is unavailable for this exact route."
        case .destinationFeeChanged:
            return "The destination fee changed after you reviewed it. Review the route again before submitting."
        case .destinationFeeTooHigh:
            return "The destination fee is larger than the amount itself, which no reviewed bridge charges. The transfer was not sent."
        case .balanceUnavailable:
            return "Current authoritative asset and network-fee balances are unavailable."
        case .insufficientAssetBalance:
            return "The current spendable balance is insufficient for the amount and destination fee."
        case .insufficientFeeBalance:
            return "The current spendable utility balance is insufficient for the freshly estimated origin fee."
        }
    }
}

enum ReviewedCrossChainSubmissionValidator {
    static func validate(
        origin: ChainAsset,
        destination: ChainModel,
        reviewedRoute: ReviewedCrossChainRouteContext,
        mutationsEnabled: Bool,
        executionAdapterAvailable: Bool = ReviewedXcmExecutionAuthority.isAvailable
    ) throws {
        guard mutationsEnabled else {
            throw ReviewedCrossChainSubmissionError.actionsPaused
        }
        try validateReviewedRoute(
            origin: origin,
            destination: destination,
            reviewedRoute: reviewedRoute,
            executionAdapterAvailable: executionAdapterAvailable
        )
    }

    /// The final signed-authority boundary has already checked the policy
    /// under its lock. Re-reading it here would recursively acquire that lock.
    static func validateReviewedRoute(
        origin: ChainAsset,
        destination: ChainModel,
        reviewedRoute: ReviewedCrossChainRouteContext,
        executionAdapterAvailable: Bool = ReviewedXcmExecutionAuthority.isAvailable
    ) throws {
        guard executionAdapterAvailable else {
            throw ReviewedCrossChainSubmissionError.executionAdapterUnavailable
        }

        let definitions = ReviewedXcmRouteRegistry.routes.filter {
            $0.originChainId == origin.chain.chainId &&
                $0.originAssetId == origin.asset.id &&
                $0.originPrecision == origin.asset.precision &&
                $0.destinationChainIds.contains(destination.chainId)
        }
        guard definitions.count == 1, let definition = definitions.first else {
            throw ReviewedCrossChainSubmissionError.unreviewedRoute
        }
        let providerId = definition.originChainId == ReviewedXcmRouteRegistry.liberlandChainId ||
            definition.destinationChainIds.contains(ReviewedXcmRouteRegistry.liberlandChainId)
            ? "sora-liberland-xcm"
            : "polkaswap-sora-substrate"
        let exactCatalogAssets = origin.chain.chainAssets.filter {
            $0.asset.id == definition.originAssetId &&
                $0.asset.precision == definition.originPrecision &&
                definition.execution.asset.validates($0.asset)
        }

        guard reviewedRoute == ReviewedCrossChainRouteContext(
            definition: definition,
            providerId: providerId
        ),
            reviewedRoute.validates(origin: origin, destination: destination),
            exactCatalogAssets.count == 1,
            definition.execution.asset.validates(origin.asset),
            !origin.chain.disabled,
            !origin.chain.isTestnet,
            !destination.disabled,
            !destination.isTestnet,
            let xcm = origin.chain.xcm,
            xcm.xcmVersion == .V3,
            xcm.availableAssets.filter({ $0.id == definition.xcmAssetId }).count == 1,
            xcm.availableDestinations.filter({ route in
                route.chainId == destination.chainId &&
                    route.assets.filter { $0.id == definition.xcmAssetId }.count == 1
            }).count == 1 else {
            throw ReviewedCrossChainSubmissionError.unreviewedRoute
        }
    }
}

struct ReviewedCrossChainRuntimeCapability: Equatable {
    let moduleName: String
    let callName: String
    let specVersion: UInt32
    let callIndex: ReviewedCrossChainCallIndex
}

protocol ReviewedCrossChainRuntimeNegotiating {
    func negotiate(
        runtime: RuntimeProviderProtocol,
        descriptor: ReviewedCrossChainExecutionDescriptor
    ) async throws -> ReviewedCrossChainRuntimeCapability
}

/// Node-supplied metadata decides which bytes encode a call, so names alone do not identify the reviewed call. The
/// negotiator also requires the reviewed pallet and call index, and encodes a probe of the call to compare with the
/// reviewed layout byte for byte.
struct ReviewedCrossChainRuntimeNegotiator: ReviewedCrossChainRuntimeNegotiating {
    private let callBuilder: ReviewedCrossChainCallBuilding

    init(callBuilder: ReviewedCrossChainCallBuilding = ReviewedCrossChainCallBuilder()) {
        self.callBuilder = callBuilder
    }

    func negotiate(
        runtime: RuntimeProviderProtocol,
        descriptor: ReviewedCrossChainExecutionDescriptor
    ) async throws -> ReviewedCrossChainRuntimeCapability {
        guard let snapshot = runtime.snapshot else {
            throw ReviewedCrossChainSubmissionError.runtimeUnavailable
        }
        let factory = try await runtime.fetchCoderFactory()
        return try negotiate(factory: factory, specVersion: snapshot.specVersion, descriptor: descriptor)
    }

    func negotiate(
        factory: RuntimeCoderFactoryProtocol,
        specVersion: UInt32,
        descriptor: ReviewedCrossChainExecutionDescriptor
    ) throws -> ReviewedCrossChainRuntimeCapability {
        guard let expectedIndex = descriptor.callIndex else {
            throw ReviewedCrossChainSubmissionError.runtimeCallUnavailable
        }
        let metadata = factory.metadata
        let modules = metadata.modules.filter {
            normalize($0.name) == normalize(descriptor.runtimeCall.requestedModuleName)
        }
        guard modules.count == 1, let module = modules.first,
              module.index == expectedIndex.palletIndex,
              let calls = try module.calls(using: metadata.schemaResolver) else {
            throw ReviewedCrossChainSubmissionError.runtimeCallUnavailable
        }
        let matchingCalls = calls.filter {
            normalize($0.name) == normalize(descriptor.runtimeCall.requestedCallName)
        }
        guard matchingCalls.count == 1, let call = matchingCalls.first else {
            throw ReviewedCrossChainSubmissionError.runtimeCallUnavailable
        }
        let arguments = call.arguments.map { normalize($0.name) }
        // The index the encoder writes is the call's position in this listing, which equals the variant index only
        // while the pallet's calls have no gaps.
        guard arguments == ["networkid", "assetid", "recipient", "amount"],
              try metadata.getCallIndex(in: module.name, callName: call.name) == expectedIndex.callIndex else {
            throw ReviewedCrossChainSubmissionError.runtimeCallUnavailable
        }
        let capability = ReviewedCrossChainRuntimeCapability(
            moduleName: module.name,
            callName: call.name,
            specVersion: specVersion,
            callIndex: expectedIndex
        )

        let probeRecipient = Data(repeating: 1, count: SubstrateConstants.accountIdLength)
        let probeAmount = BigUInt(1)
        let encoded = try callBuilder.encodedCall(
            execution: descriptor,
            capability: capability,
            destinationAccountId: probeRecipient,
            amount: probeAmount,
            factory: factory
        )
        let expected = try ReviewedCrossChainCallLayout.expected(
            execution: descriptor,
            destinationAccountId: probeRecipient,
            amount: probeAmount
        )
        guard encoded == expected else {
            throw ReviewedCrossChainSubmissionError.runtimeCallUnavailable
        }
        return capability
    }

    private func normalize(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "_", with: "")
    }
}

/// The bytes the origin runtime decodes as the reviewed call, written without the runtime's metadata. Liberland
/// (spec 34): `SoraBridgeApp.burn(network_id: SubNetworkId, asset_id: LiberlandAssetId, recipient: GenericAccount,
/// amount: u128)` with `SubNetworkId::Mainnet` = 0, `LiberlandAssetId::LLD` = 0, `LiberlandAssetId::Asset(u32)` = 1 and
/// `GenericAccount::Sora(AccountId32)` = 1. A call without a reviewed layout cannot be submitted.
enum ReviewedCrossChainCallLayout {
    static let maximumAmount = (BigUInt(1) << 128) - 1

    static func expected(
        execution: ReviewedCrossChainExecutionDescriptor,
        destinationAccountId: AccountId,
        amount: BigUInt
    ) throws -> Data {
        guard execution.runtimeCall == .liberlandSoraBridgeAppBurn,
              execution.network == .soraMainnet,
              execution.recipient == .sora,
              let index = execution.callIndex else {
            throw ReviewedCrossChainSubmissionError.runtimeCallUnavailable
        }
        guard destinationAccountId.count == SubstrateConstants.accountIdLength else {
            throw ReviewedCrossChainSubmissionError.invalidRecipient
        }
        guard amount > .zero, amount <= maximumAmount else {
            throw ReviewedCrossChainSubmissionError.invalidAmount
        }

        var bytes = Data([index.palletIndex, index.callIndex, 0x00])
        switch execution.asset {
        case .liberlandNativeLLD:
            bytes.append(0x00)
        case let .liberlandAsset(currencyId):
            guard let assetId = UInt32(currencyId, radix: 10) else {
                throw ReviewedCrossChainSubmissionError.runtimeCallUnavailable
            }
            bytes.append(0x01)
            bytes.append(contentsOf: (0 ..< 4).map { UInt8(truncatingIfNeeded: assetId >> (8 * $0)) })
        case .soraAsset:
            throw ReviewedCrossChainSubmissionError.runtimeCallUnavailable
        }
        bytes.append(0x01)
        bytes.append(destinationAccountId)
        let amountBytes = Array(amount.serialize().reversed())
        bytes.append(contentsOf: amountBytes + Array(repeating: 0, count: 16 - amountBytes.count))
        return bytes
    }
}

/// Recipients that no person controls: the all-zero account, pallet (`modl`) accounts, and parachain (`para`) and
/// sibling (`sibl`) sovereign accounts. Funds sent to them cannot be spent by the person who typed the address.
enum ReviewedCrossChainRecipientPolicy {
    private static let systemPrefixes = ["modl", "para", "sibl"].map { Data($0.utf8) }

    static func rejects(_ accountId: AccountId) -> Bool {
        guard accountId.count == SubstrateConstants.accountIdLength else { return true }
        return accountId.allSatisfy { $0 == 0 } || systemPrefixes.contains { accountId.starts(with: $0) }
    }
}

protocol ReviewedCrossChainGenesisReading {
    func genesisHash(connection: JSONRPCEngine) async throws -> String
}

/// Reads block 0's hash from the node the extrinsic would be sent to. The signature commits to that hash, so a node of
/// another network would get an extrinsic only that network accepts while the user believes it went to the origin.
struct ReviewedCrossChainGenesisReader: ReviewedCrossChainGenesisReading {
    func genesisHash(connection: JSONRPCEngine) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            do {
                _ = try connection.callMethod(
                    RPCMethod.getBlockHash,
                    params: [BlockNumber(0).toHex()]
                ) { (result: Result<String, Error>) in
                    continuation.resume(with: result)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    static func matches(genesisHash: String, chainId: ChainModel.Id) -> Bool {
        let normalized = genesisHash.lowercased()
        let hash = normalized.hasPrefix("0x") ? String(normalized.dropFirst(2)) : normalized
        return hash.count == 64 && hash == chainId.lowercased()
    }
}

struct ReviewedCrossChainAuthoritativeBalances: Equatable {
    let originAssetKey: AssetKey?
    let feeAssetKey: AssetKey?
    let originSpendable: BigUInt?
    let feeSpendable: BigUInt?
}

protocol ReviewedCrossChainBalanceProviding {
    func balances() async -> ReviewedCrossChainAuthoritativeBalances
}

final class ReviewedCrossChainBalanceProvider: ReviewedCrossChainBalanceProviding {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let definition: ReviewedXcmRouteDefinition
    private let accountInfoRemoteService: AccountInfoRemoteService

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        definition: ReviewedXcmRouteDefinition,
        accountInfoRemoteService: AccountInfoRemoteService? = nil
    ) {
        self.wallet = wallet
        self.chain = chain
        self.definition = definition
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

    func balances() async -> ReviewedCrossChainAuthoritativeBalances {
        let originMatches = chain.chainAssets.filter {
            $0.asset.id == definition.originAssetId &&
                $0.asset.precision == definition.originPrecision &&
                definition.execution.asset.validates($0.asset)
        }
        let feeMatches = chain.chainAssets.filter(\.isUtility)
        let originAsset = originMatches.count == 1 ? originMatches[0] : nil
        let feeAsset = feeMatches.count == 1 ? feeMatches[0] : nil
        guard let originAsset, let feeAsset,
              wallet.fetch(for: chain.accountRequest()) != nil,
              let accountInfos = try? await accountInfoRemoteService.fetchAccountInfos(
                  for: chain,
                  wallet: wallet
              ) else {
            return ReviewedCrossChainAuthoritativeBalances(
                originAssetKey: originAsset?.assetKey,
                feeAssetKey: feeAsset?.assetKey,
                originSpendable: nil,
                feeSpendable: nil
            )
        }
        let originInfo: AccountInfo? = accountInfos[originAsset.chainAssetId] ?? nil
        let feeInfo: AccountInfo? = accountInfos[feeAsset.chainAssetId] ?? nil
        return ReviewedCrossChainAuthoritativeBalances(
            originAssetKey: originAsset.assetKey,
            feeAssetKey: feeAsset.assetKey,
            originSpendable: originInfo?.data.sendAvailable,
            feeSpendable: feeInfo?.data.sendAvailable
        )
    }
}

enum ReviewedCrossChainSubmissionBoundaryValidator {
    /// The destination fee comes from an unsigned remote file and is fetched again at submission. Only the fee the
    /// user reviewed may be added to the burn: a different value, higher or lower, is a stale or tampered quote.
    static func requireConfirmedDestinationFee(
        fresh: BigUInt,
        confirmed: Decimal,
        originPrecision: UInt16
    ) throws {
        guard let confirmedPlanks = confirmed.toSubstrateAmount(precision: Int16(originPrecision)),
              fresh == confirmedPlanks else {
            throw ReviewedCrossChainSubmissionError.destinationFeeChanged
        }
    }

    static func validate(
        definition: ReviewedXcmRouteDefinition,
        requestedAmount: BigUInt,
        burnAmount: BigUInt,
        balances: ReviewedCrossChainAuthoritativeBalances,
        originFee: BigUInt
    ) throws {
        guard requestedAmount > .zero, burnAmount >= requestedAmount, originFee > .zero else {
            throw ReviewedCrossChainSubmissionError.invalidAmount
        }
        // The destination fee is added to the burn and comes from an unsigned remote file. A fee above the amount
        // itself is far outside what the reviewed bridges charge.
        guard burnAmount - requestedAmount <= requestedAmount else {
            throw ReviewedCrossChainSubmissionError.destinationFeeTooHigh
        }
        if let minimum = definition.execution.minimumAmount {
            guard let minimumValue = BigUInt(minimum, radix: 10),
                  requestedAmount >= minimumValue else {
                throw ReviewedCrossChainSubmissionError.belowMinimum
            }
        }
        let expectedOriginKey = AssetKey(
            ecosystem: "substrate",
            chainId: definition.originChainId,
            assetId: definition.execution.asset.canonicalAssetId(
                originCatalogId: definition.originAssetId
            )
        )
        guard balances.originAssetKey == expectedOriginKey,
              let feeKey = balances.feeAssetKey,
              feeKey.chainId == definition.originChainId.lowercased(),
              let originSpendable = balances.originSpendable,
              let feeSpendable = balances.feeSpendable else {
            throw ReviewedCrossChainSubmissionError.balanceUnavailable
        }

        if balances.originAssetKey == balances.feeAssetKey {
            guard originSpendable >= burnAmount + originFee else {
                throw ReviewedCrossChainSubmissionError.insufficientAssetBalance
            }
        } else {
            guard originSpendable >= burnAmount else {
                throw ReviewedCrossChainSubmissionError.insufficientAssetBalance
            }
            guard feeSpendable >= originFee else {
                throw ReviewedCrossChainSubmissionError.insufficientFeeBalance
            }
        }
    }
}

private enum ReviewedBridgeDecodingError {
    static func unsupported<T>(_ type: T.Type, decoder: Decoder) -> Error {
        DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "\(type) is an encode-only reviewed runtime argument"
            )
        )
    }
}

private enum ReviewedBridgeSubNetworkId: Codable {
    case mainnet
    case kusama
    case polkadot
    case liberland

    init(_ descriptor: ReviewedCrossChainSubNetwork) throws {
        switch descriptor {
        case .soraMainnet: self = .mainnet
        case .kusama: self = .kusama
        case .polkadot: self = .polkadot
        case .liberland: self = .liberland
        }
    }

    init(from decoder: Decoder) throws {
        throw ReviewedBridgeDecodingError.unsupported(Self.self, decoder: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .mainnet: try container.encode("Mainnet")
        case .kusama: try container.encode("Kusama")
        case .polkadot: try container.encode("Polkadot")
        case .liberland: try container.encode("Liberland")
        }
        try container.encodeNil()
    }
}

private enum ReviewedBridgeGenericNetworkId: Codable {
    case sub(ReviewedBridgeSubNetworkId)

    init(from decoder: Decoder) throws {
        throw ReviewedBridgeDecodingError.unsupported(Self.self, decoder: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case let .sub(network):
            try container.encode("Sub")
            try container.encode(network)
        }
    }
}

enum ReviewedBridgeJunctionNetworkId: Codable {
    case any
    case kusama
    case polkadot

    init(_ descriptor: ReviewedCrossChainSubNetwork) {
        switch descriptor {
        case .kusama: self = .kusama
        case .polkadot: self = .polkadot
        case .liberland, .soraMainnet: self = .any
        }
    }

    init(from decoder: Decoder) throws {
        throw ReviewedBridgeDecodingError.unsupported(Self.self, decoder: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .any: try container.encode("Any")
        case .kusama: try container.encode("Kusama")
        case .polkadot: try container.encode("Polkadot")
        }
        try container.encodeNil()
    }
}

struct ReviewedBridgeAccountId32: Codable {
    let network: ReviewedBridgeJunctionNetworkId
    @BytesCodable var id: AccountId
}

enum ReviewedBridgeJunction: Codable {
    case parachain(UInt32)
    case accountId32(ReviewedBridgeAccountId32)

    init(from decoder: Decoder) throws {
        throw ReviewedBridgeDecodingError.unsupported(Self.self, decoder: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case let .parachain(paraId):
            try container.encode("Parachain")
            try container.encode(StringCodable(wrappedValue: paraId))
        case let .accountId32(account):
            try container.encode("AccountId32")
            try container.encode(account)
        }
    }
}

struct ReviewedBridgeJunctions: Codable {
    let items: [ReviewedBridgeJunction]

    init(items: [ReviewedBridgeJunction]) {
        self.items = items
    }

    init(from decoder: Decoder) throws {
        throw ReviewedBridgeDecodingError.unsupported(Self.self, decoder: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        guard !items.isEmpty else {
            try container.encode("Here")
            try container.encodeNil()
            return
        }
        try container.encode("X\(items.count)")
        if items.count == 1 {
            try container.encode(items[0])
        } else {
            try container.encode(items)
        }
    }
}

struct ReviewedBridgeMultiLocation: Codable {
    @StringCodable var parents: UInt8
    let interior: ReviewedBridgeJunctions
}

enum ReviewedBridgeVersionedMultiLocation: Codable {
    case v3(ReviewedBridgeMultiLocation)

    init(from decoder: Decoder) throws {
        throw ReviewedBridgeDecodingError.unsupported(Self.self, decoder: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case let .v3(location):
            try container.encode("V3")
            try container.encode(location)
        }
    }
}

enum ReviewedBridgeGenericAccount: Codable {
    case sora(AccountId)
    case liberland(AccountId)
    case parachain(ReviewedBridgeVersionedMultiLocation)

    init(from decoder: Decoder) throws {
        throw ReviewedBridgeDecodingError.unsupported(Self.self, decoder: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case let .sora(accountId):
            try container.encode("Sora")
            try container.encode(accountId)
        case let .liberland(accountId):
            try container.encode("Liberland")
            try container.encode(accountId)
        case let .parachain(location):
            try container.encode("Parachain")
            try container.encode(location)
        }
    }
}

private enum ReviewedLiberlandAssetId: Codable {
    case asset(String)
    case lld

    init(from decoder: Decoder) throws {
        throw ReviewedBridgeDecodingError.unsupported(Self.self, decoder: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case let .asset(value):
            try container.encode("Asset")
            try container.encode(value)
        case .lld:
            try container.encode("LLD")
            try container.encodeNil()
        }
    }
}

private struct ReviewedSoraBridgeProxyBurnCall: Codable {
    let networkId: ReviewedBridgeGenericNetworkId
    let assetId: SoraAssetId
    let recipient: ReviewedBridgeGenericAccount
    @StringCodable var amount: BigUInt
}

private struct ReviewedLiberlandSoraBridgeAppBurnCall: Codable {
    let networkId: ReviewedBridgeSubNetworkId
    let assetId: ReviewedLiberlandAssetId
    let recipient: ReviewedBridgeGenericAccount
    @StringCodable var amount: BigUInt
}

protocol ReviewedCrossChainCallBuilding {
    func builder(
        definition: ReviewedXcmRouteDefinition,
        capability: ReviewedCrossChainRuntimeCapability,
        destinationAccountId: AccountId,
        amount: BigUInt
    ) throws -> ExtrinsicBuilderClosure

    /// The call bytes the runtime's encoder produces for the same arguments as `builder`.
    func encodedCall(
        execution: ReviewedCrossChainExecutionDescriptor,
        capability: ReviewedCrossChainRuntimeCapability,
        destinationAccountId: AccountId,
        amount: BigUInt,
        factory: RuntimeCoderFactoryProtocol
    ) throws -> Data
}

struct ReviewedCrossChainCallBuilder: ReviewedCrossChainCallBuilding {
    func builder(
        definition: ReviewedXcmRouteDefinition,
        capability: ReviewedCrossChainRuntimeCapability,
        destinationAccountId: AccountId,
        amount: BigUInt
    ) throws -> ExtrinsicBuilderClosure {
        let call = try makeCall(
            execution: definition.execution,
            capability: capability,
            destinationAccountId: destinationAccountId,
            amount: amount
        )
        return { try $0.adding(call: call) }
    }

    func encodedCall(
        execution: ReviewedCrossChainExecutionDescriptor,
        capability: ReviewedCrossChainRuntimeCapability,
        destinationAccountId: AccountId,
        amount: BigUInt,
        factory: RuntimeCoderFactoryProtocol
    ) throws -> Data {
        let call = try makeCall(
            execution: execution,
            capability: capability,
            destinationAccountId: destinationAccountId,
            amount: amount
        )
        let encoder = factory.createEncoder()
        try encoder.append(json: call.toScaleCompatibleJSON(), type: GenericType.call.name)
        return try encoder.encode()
    }

    private func makeCall(
        execution: ReviewedCrossChainExecutionDescriptor,
        capability: ReviewedCrossChainRuntimeCapability,
        destinationAccountId: AccountId,
        amount: BigUInt
    ) throws -> RuntimeCall<JSON> {
        guard destinationAccountId.count == SubstrateConstants.accountIdLength else {
            throw ReviewedCrossChainSubmissionError.invalidRecipient
        }
        // The dynamic encoder pads an integer to its width but never rejects one that is wider.
        guard amount > .zero, amount <= ReviewedCrossChainCallLayout.maximumAmount else {
            throw ReviewedCrossChainSubmissionError.invalidAmount
        }

        let args: JSON
        switch execution.runtimeCall {
        case .soraBridgeProxyBurn:
            guard case let .soraAsset(currencyId) = execution.asset else {
                throw ReviewedCrossChainSubmissionError.unreviewedRoute
            }
            let networkId = try ReviewedBridgeSubNetworkId(execution.network)
            let recipient = try makeSoraRecipient(
                execution.recipient,
                accountId: destinationAccountId
            )
            args = try ReviewedSoraBridgeProxyBurnCall(
                networkId: .sub(networkId),
                assetId: SoraAssetId(wrappedValue: currencyId),
                recipient: recipient,
                amount: amount
            ).toScaleCompatibleJSON()
        case .liberlandSoraBridgeAppBurn:
            guard execution.network == .soraMainnet,
                  execution.recipient == .sora else {
                throw ReviewedCrossChainSubmissionError.unreviewedRoute
            }
            let assetId: ReviewedLiberlandAssetId
            switch execution.asset {
            case let .liberlandAsset(currencyId):
                assetId = .asset(currencyId)
            case .liberlandNativeLLD:
                assetId = .lld
            case .soraAsset:
                throw ReviewedCrossChainSubmissionError.unreviewedRoute
            }
            args = try ReviewedLiberlandSoraBridgeAppBurnCall(
                networkId: .mainnet,
                assetId: assetId,
                recipient: .sora(destinationAccountId),
                amount: amount
            ).toScaleCompatibleJSON()
        }
        return RuntimeCall(moduleName: capability.moduleName, callName: capability.callName, args: args)
    }

    /// Internal so a test can encode the recipient and pin its multilocation shape.
    func makeSoraRecipient(
        _ descriptor: ReviewedCrossChainRecipientDescriptor,
        accountId: AccountId
    ) throws -> ReviewedBridgeGenericAccount {
        switch descriptor {
        case .liberland:
            return .liberland(accountId)
        case let .relay(network):
            return .parachain(
                .v3(
                    ReviewedBridgeMultiLocation(
                        parents: 1,
                        interior: ReviewedBridgeJunctions(items: [
                            .accountId32(
                                ReviewedBridgeAccountId32(
                                    network: ReviewedBridgeJunctionNetworkId(network),
                                    id: accountId
                                )
                            )
                        ])
                    )
                )
            )
        case let .parachain(paraId, network):
            // The SORA parachain reads the recipient relative to itself: one level up to the relay chain, then down
            // to the destination parachain. It rejects `parents: 0` (InvalidDestinationParams), and every historical
            // SORA transfer to a parachain used 1.
            return .parachain(
                .v3(
                    ReviewedBridgeMultiLocation(
                        parents: 1,
                        interior: ReviewedBridgeJunctions(items: [
                            .parachain(paraId),
                            .accountId32(
                                ReviewedBridgeAccountId32(
                                    network: ReviewedBridgeJunctionNetworkId(network),
                                    id: accountId
                                )
                            )
                        ])
                    )
                )
            )
        case .sora:
            throw ReviewedCrossChainSubmissionError.unreviewedRoute
        }
    }
}

/// What the node returned for an accepted submission.
struct ReviewedCrossChainSubmissionReceipt: Equatable {
    /// The `author_submitAndWatchExtrinsic` subscription that reports the extrinsic's status.
    let subscriptionId: String
    /// blake2b-256 of the submitted extrinsic, the hash block explorers show.
    let extrinsicHash: String?
}

protocol ReviewedCrossChainExtrinsicExecuting: AnyObject {
    func estimateFee(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo
    func submit(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> ReviewedCrossChainSubmissionReceipt
    /// Waits for the block that includes the submission and reads whether it dispatched.
    func dispatchOutcome(for receipt: ReviewedCrossChainSubmissionReceipt) async -> ReviewedCrossChainDispatchOutcome
}

final class ReviewedCrossChainExtrinsicExecutor: ReviewedCrossChainExtrinsicExecuting {
    private let service: ExtrinsicServiceProtocol
    private let signer: SigningWrapperProtocol?
    private let dispatchWatcher: ReviewedCrossChainDispatchWatching?

    init(
        service: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol? = nil,
        dispatchWatcher: ReviewedCrossChainDispatchWatching? = nil
    ) {
        self.service = service
        self.signer = signer
        self.dispatchWatcher = dispatchWatcher
    }

    func estimateFee(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo {
        try await withCheckedThrowingContinuation { continuation in
            service.estimateFee(builder, runningIn: .main) { continuation.resume(with: $0) }
        }
    }

    func submit(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> ReviewedCrossChainSubmissionReceipt {
        guard let signer, signer.mutationAuthorization != nil else { throw MutationAuthorizationError.denied }
        return try await withCheckedThrowingContinuation { continuation in
            service.submitAndWatch(builder, signer: signer, runningIn: .main) { result, extrinsicHex in
                switch result {
                case let .success(subscriptionId):
                    let extrinsicHash = extrinsicHex
                        .flatMap { try? Data(hexStringSSF: $0).blake2b32() }
                        .map { $0.toHex(includePrefix: true) }
                    continuation.resume(
                        returning: ReviewedCrossChainSubmissionReceipt(
                            subscriptionId: subscriptionId,
                            extrinsicHash: extrinsicHash
                        )
                    )
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func dispatchOutcome(for receipt: ReviewedCrossChainSubmissionReceipt) async -> ReviewedCrossChainDispatchOutcome {
        guard let dispatchWatcher, let extrinsicHash = receipt.extrinsicHash else {
            return .unknown
        }
        return await dispatchWatcher.outcome(
            subscriptionId: receipt.subscriptionId,
            extrinsicHash: extrinsicHash
        )
    }
}

struct ReviewedCrossChainAuthorizedSubmission {
    let builder: ExtrinsicBuilderClosure
    let executor: ReviewedCrossChainExtrinsicExecuting
    let finalGuard: () throws -> Void
    /// The stable identity of this transfer (wallet, origin account, route, recipient and amount): the part of the
    /// authorization digest that does not change when only the fee or the runtime does.
    let transferKey: String
    let intentSha256: String
}

protocol ReviewedCrossChainSubmissionAuthorizing {
    func authorize() async throws -> ReviewedCrossChainAuthorizedSubmission
}

final class ReviewedCrossChainSubmissionAuthorizer: ReviewedCrossChainSubmissionAuthorizing {
    private struct Context {
        let wallet: MetaAccountModel
        let origin: ChainAsset
        let destination: ChainModel
        let definition: ReviewedXcmRouteDefinition
        let account: ChainAccountResponse
        let destinationAccountId: AccountId
        let runtime: RuntimeProviderProtocol
        let connection: JSONRPCEngine
        let runtimeSpecVersion: UInt32
        let balanceProvider: ReviewedCrossChainBalanceProviding
        let service: ExtrinsicServiceProtocol
        let executor: ReviewedCrossChainExtrinsicExecuting
        let dispatchWatcher: ReviewedCrossChainDispatchWatching
    }

    private struct Round {
        let builder: ExtrinsicBuilderClosure
        let capability: ReviewedCrossChainRuntimeCapability
        let encodedCall: Data
        let burnAmount: BigUInt
        let originFee: BigUInt
    }

    private let data: CrossChainConfirmationData
    private let expectedWalletId: MetaAccountId
    private let expectedRouteFingerprint: String
    private let destinationFeeProvider: XcmDestinationFeeFetching
    private let callBuilder: ReviewedCrossChainCallBuilding
    private let runtimeNegotiator: ReviewedCrossChainRuntimeNegotiating
    private let genesisReader: ReviewedCrossChainGenesisReading
    private let chainRegistry: ChainRegistryProtocol
    private let keystore: KeystoreProtocol
    private let selectedWallet: () -> MetaAccountModel?
    private let mutationsEnabled: () -> Bool

    init(
        data: CrossChainConfirmationData,
        destinationFeeProvider: XcmDestinationFeeFetching,
        callBuilder: ReviewedCrossChainCallBuilding = ReviewedCrossChainCallBuilder(),
        runtimeNegotiator: ReviewedCrossChainRuntimeNegotiating = ReviewedCrossChainRuntimeNegotiator(),
        genesisReader: ReviewedCrossChainGenesisReading = ReviewedCrossChainGenesisReader(),
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        keystore: KeystoreProtocol = Keychain(),
        selectedWallet: @escaping () -> MetaAccountModel? = { SelectedWalletSettings.shared.value },
        mutationsEnabled: @escaping () -> Bool = {
            MultiChainFeaturePolicy.current.crossChainMutationsEnabled
        }
    ) {
        self.data = data
        expectedWalletId = data.wallet.metaId
        expectedRouteFingerprint = data.reviewedRoute.routeId
        self.destinationFeeProvider = destinationFeeProvider
        self.callBuilder = callBuilder
        self.runtimeNegotiator = runtimeNegotiator
        self.genesisReader = genesisReader
        self.chainRegistry = chainRegistry
        self.keystore = keystore
        self.selectedWallet = selectedWallet
        self.mutationsEnabled = mutationsEnabled
    }

    func authorize() async throws -> ReviewedCrossChainAuthorizedSubmission {
        try validatePolicyAndWallet()
        let context = try makeFreshContext()

        let genesisHash = try await genesisReader.genesisHash(connection: context.connection)
        guard ReviewedCrossChainGenesisReader.matches(
            genesisHash: genesisHash,
            chainId: context.origin.chain.chainId
        ) else {
            throw ReviewedCrossChainSubmissionError.wrongNetwork
        }

        // Two independent passes deliberately repeat current runtime-call
        // negotiation, destination fee, exact balance, minimum and origin-fee
        // checks. Only the second pass's exact builder may be submitted.
        _ = try await authorizeRound(context)
        try validateCurrentContext(context)
        let final = try await authorizeRound(context)
        try validateCurrentContext(context)
        let transferKey = try ReviewedCrossChainTransferKey.make(
            walletId: context.wallet.metaId,
            originChainId: context.origin.chain.chainId,
            originAccountId: context.account.accountId,
            routeId: expectedRouteFingerprint,
            destinationChainId: context.destination.chainId,
            destinationAccountId: context.destinationAccountId,
            amount: data.amount
        )
        let intent = try MutationIntentDigest.make([
            MutationCapability.xcm.rawValue, context.wallet.metaId,
            context.origin.chain.chainId, context.account.accountId.toHex(),
            context.account.publicKey.toHex(), String(context.account.cryptoType.rawValue),
            String(context.runtimeSpecVersion), expectedRouteFingerprint,
            context.origin.asset.id, String(context.origin.asset.precision),
            context.destination.chainId, context.destinationAccountId.toHex(),
            data.amount.description, final.burnAmount.description, final.originFee.description,
            genesisHash.lowercased(), final.capability.moduleName, final.capability.callName,
            String(final.capability.callIndex.palletIndex), String(final.capability.callIndex.callIndex),
            final.encodedCall.toHex(), transferKey
        ])
        let authorization = try MultiChainFeaturePolicy.authorization(for: .xcm, intentSha256: intent) {
            try self.validateCurrentContext(context, checkPolicy: false)
        }
        let signer = SigningWrapper(
            keystore: keystore,
            metaId: context.wallet.metaId,
            accountResponse: context.account,
            mutationAuthorization: authorization
        )
        return ReviewedCrossChainAuthorizedSubmission(
            builder: final.builder,
            executor: ReviewedCrossChainExtrinsicExecutor(
                service: context.service,
                signer: signer,
                dispatchWatcher: context.dispatchWatcher
            ),
            finalGuard: { [weak self] in
                guard let self else {
                    throw ReviewedCrossChainSubmissionError.runtimeUnavailable
                }
                try self.validateCurrentContext(context)
            },
            transferKey: transferKey,
            intentSha256: intent
        )
    }

    private func authorizeRound(_ context: Context) async throws -> Round {
        try validateCurrentContext(context)
        let capability = try await runtimeNegotiator.negotiate(
            runtime: context.runtime,
            descriptor: context.definition.execution
        )
        guard capability.specVersion == context.runtimeSpecVersion else {
            throw ReviewedCrossChainSubmissionError.runtimeUnavailable
        }
        let destinationFee = try await destinationFeeInOriginUnits(context)
        try ReviewedCrossChainSubmissionBoundaryValidator.requireConfirmedDestinationFee(
            fresh: destinationFee,
            confirmed: data.destChainFeeDecimal,
            originPrecision: context.definition.originPrecision
        )
        let burnAmount = data.amount + destinationFee
        let builder = try callBuilder.builder(
            definition: context.definition,
            capability: capability,
            destinationAccountId: context.destinationAccountId,
            amount: burnAmount
        )
        // The exact call that will be signed, encoded by the same runtime, must match the reviewed layout.
        let factory = try await context.runtime.fetchCoderFactory()
        let encodedCall = try callBuilder.encodedCall(
            execution: context.definition.execution,
            capability: capability,
            destinationAccountId: context.destinationAccountId,
            amount: burnAmount,
            factory: factory
        )
        let expectedCall = try ReviewedCrossChainCallLayout.expected(
            execution: context.definition.execution,
            destinationAccountId: context.destinationAccountId,
            amount: burnAmount
        )
        guard encodedCall == expectedCall else {
            throw ReviewedCrossChainSubmissionError.runtimeCallUnavailable
        }
        let dispatchInfo = try await context.executor.estimateFee(builder)
        guard let originFee = BigUInt(dispatchInfo.fee, radix: 10), originFee > .zero else {
            throw ReviewedCrossChainSubmissionError.runtimeUnavailable
        }
        let balances = await context.balanceProvider.balances()
        try ReviewedCrossChainSubmissionBoundaryValidator.validate(
            definition: context.definition,
            requestedAmount: data.amount,
            burnAmount: burnAmount,
            balances: balances,
            originFee: originFee
        )
        try validateCurrentContext(context)
        return Round(
            builder: builder,
            capability: capability,
            encodedCall: encodedCall,
            burnAmount: burnAmount,
            originFee: originFee
        )
    }

    private func destinationFeeInOriginUnits(_ context: Context) async throws -> BigUInt {
        let result = await destinationFeeProvider.estimateFee(
            destinationChainId: context.destination.chainId,
            token: context.definition.originSymbol
        )
        guard case let .success(response) = result,
              response.symbol.caseInsensitiveCompare(context.definition.originSymbol) == .orderedSame,
              let fee = response.feeInPlanks else {
            throw ReviewedCrossChainSubmissionError.destinationFeeUnavailable
        }
        // Without its precision the fee cannot be scaled to origin units; guessing the origin's could be off by 10^n.
        guard let destinationPrecision = response.precision.flatMap({ UInt16($0) }) else {
            throw ReviewedCrossChainSubmissionError.destinationFeeUnavailable
        }
        let originPrecision = context.definition.originPrecision
        if destinationPrecision == originPrecision { return fee }
        if destinationPrecision < originPrecision {
            return fee * BigUInt(10).power(Int(originPrecision - destinationPrecision))
        }
        let divisor = BigUInt(10).power(Int(destinationPrecision - originPrecision))
        guard fee % divisor == .zero else {
            throw ReviewedCrossChainSubmissionError.destinationFeeUnavailable
        }
        return fee / divisor
    }

    private func makeFreshContext() throws -> Context {
        guard let wallet = selectedWallet(), wallet.metaId == expectedWalletId else {
            throw ReviewedCrossChainSubmissionError.selectedWalletChanged
        }
        guard data.reviewedRoute.routeId == expectedRouteFingerprint,
              let definition = ReviewedXcmRouteRegistry.definition(for: data.reviewedRoute),
              let originChain = chainRegistry.getChain(for: definition.originChainId),
              let destination = chainRegistry.getChain(for: definition.execution.destinationChainId),
              let origin = exactOrigin(definition: definition, chain: originChain) else {
            throw ReviewedCrossChainSubmissionError.unreviewedRoute
        }
        try ReviewedCrossChainSubmissionValidator.validate(
            origin: origin,
            destination: destination,
            reviewedRoute: data.reviewedRoute,
            mutationsEnabled: mutationsEnabled()
        )
        let account = try validateSigningAccount(wallet: wallet, chain: originChain)
        guard let destinationAccountId = try? AddressFactory.accountId(
            from: data.recipientAddress,
            chain: destination
        ), destinationAccountId.count == SubstrateConstants.accountIdLength,
        !ReviewedCrossChainRecipientPolicy.rejects(destinationAccountId) else {
            throw ReviewedCrossChainSubmissionError.invalidRecipient
        }
        guard let runtime = chainRegistry.getRuntimeProvider(for: originChain.chainId),
              let snapshot = runtime.snapshot,
              let connection = chainRegistry.getConnection(for: originChain.chainId) else {
            throw ReviewedCrossChainSubmissionError.runtimeUnavailable
        }
        let extrinsic = ExtrinsicService(
            accountId: account.accountId,
            chainFormat: originChain.chainFormat,
            cryptoType: account.cryptoType,
            runtimeRegistry: runtime,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )
        return Context(
            wallet: wallet,
            origin: origin,
            destination: destination,
            definition: definition,
            account: account,
            destinationAccountId: destinationAccountId,
            runtime: runtime,
            connection: connection,
            runtimeSpecVersion: snapshot.specVersion,
            balanceProvider: ReviewedCrossChainBalanceProvider(
                wallet: wallet,
                chain: originChain,
                definition: definition
            ),
            service: extrinsic,
            executor: ReviewedCrossChainExtrinsicExecutor(service: extrinsic),
            dispatchWatcher: ReviewedCrossChainDispatchWatcher(connection: connection, runtime: runtime)
        )
    }

    private func validatePolicyAndWallet() throws {
        guard mutationsEnabled() else {
            throw ReviewedCrossChainSubmissionError.actionsPaused
        }
        guard selectedWallet()?.metaId == expectedWalletId else {
            throw ReviewedCrossChainSubmissionError.selectedWalletChanged
        }
    }

    private func validateCurrentContext(_ context: Context, checkPolicy: Bool = true) throws {
        if checkPolicy { try validatePolicyAndWallet() }
        guard data.reviewedRoute.routeId == expectedRouteFingerprint,
              let wallet = selectedWallet(),
              wallet.metaId == context.wallet.metaId,
              let originChain = chainRegistry.getChainForMutationAuthorization(for: context.origin.chain.chainId),
              originChain == context.origin.chain,
              let destination = chainRegistry.getChainForMutationAuthorization(for: context.destination.chainId),
              destination == context.destination,
              let currentOrigin = exactOrigin(definition: context.definition, chain: originChain),
              let runtime = chainRegistry.getRuntimeProvider(for: originChain.chainId),
              ObjectIdentifier(runtime) == ObjectIdentifier(context.runtime),
              (runtime as? RuntimeProvider)?.mutationAuthorizationSpecVersion == context.runtimeSpecVersion,
              let connection = chainRegistry.getConnection(for: originChain.chainId),
              ObjectIdentifier(connection) == ObjectIdentifier(context.connection),
              let destinationAccountId = try? AddressFactory.accountId(
                  from: data.recipientAddress,
                  chain: destination
              ),
              destinationAccountId == context.destinationAccountId,
              !ReviewedCrossChainRecipientPolicy.rejects(destinationAccountId) else {
            throw ReviewedCrossChainSubmissionError.runtimeUnavailable
        }
        try ReviewedCrossChainSubmissionValidator.validateReviewedRoute(
            origin: currentOrigin,
            destination: destination,
            reviewedRoute: data.reviewedRoute
        )
        _ = try validateSigningAccount(
            wallet: wallet,
            chain: originChain,
            expected: context.account
        )
    }

    private func exactOrigin(
        definition: ReviewedXcmRouteDefinition,
        chain: ChainModel
    ) -> ChainAsset? {
        let matches = chain.chainAssets.filter {
            $0.asset.id == definition.originAssetId &&
                $0.asset.precision == definition.originPrecision &&
                definition.execution.asset.validates($0.asset)
        }
        return matches.count == 1 ? matches[0] : nil
    }

    private func validateSigningAccount(
        wallet: MetaAccountModel,
        chain: ChainModel,
        expected: ChainAccountResponse? = nil
    ) throws -> ChainAccountResponse {
        guard let account = wallet.fetch(for: chain.accountRequest()),
              expected.map({
                  $0.accountId == account.accountId &&
                      $0.publicKey == account.publicKey &&
                      $0.cryptoType == account.cryptoType
              }) ?? true else {
            throw ReviewedCrossChainSubmissionError.signerUnavailable
        }
        let chainAccountId = account.isChainAccount ? account.accountId : nil
        let keyTag = chain.keystoreTag(metaId: wallet.metaId, accountId: chainAccountId)
        guard (try? keystore.checkKey(for: keyTag)) == true else {
            throw ReviewedCrossChainSubmissionError.signerUnavailable
        }
        return account
    }
}

protocol ReviewedCrossChainOriginFeeEstimating {
    func estimateOriginFee(
        definition: ReviewedXcmRouteDefinition,
        wallet: MetaAccountModel,
        amount: BigUInt
    ) async throws -> BigUInt
}

/// Quotes the origin network fee for the form with the call the confirmation signs: the same runtime negotiation,
/// layout check and builder, instead of SSFXCM's symbol-based call. Neither the recipient nor the amount changes the
/// fee, because both are fixed-width fields, so a probe recipient is used until the user enters one.
final class ReviewedCrossChainOriginFeeEstimator: ReviewedCrossChainOriginFeeEstimating {
    private let chainRegistry: ChainRegistryProtocol
    private let callBuilder: ReviewedCrossChainCallBuilding
    private let runtimeNegotiator: ReviewedCrossChainRuntimeNegotiating
    private let operationManager: OperationManagerProtocol

    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        callBuilder: ReviewedCrossChainCallBuilding = ReviewedCrossChainCallBuilder(),
        runtimeNegotiator: ReviewedCrossChainRuntimeNegotiating = ReviewedCrossChainRuntimeNegotiator(),
        operationManager: OperationManagerProtocol = OperationManagerFacade.sharedManager
    ) {
        self.chainRegistry = chainRegistry
        self.callBuilder = callBuilder
        self.runtimeNegotiator = runtimeNegotiator
        self.operationManager = operationManager
    }

    func estimateOriginFee(
        definition: ReviewedXcmRouteDefinition,
        wallet: MetaAccountModel,
        amount: BigUInt
    ) async throws -> BigUInt {
        guard let chain = chainRegistry.getChain(for: definition.originChainId),
              let account = wallet.fetch(for: chain.accountRequest()),
              let runtime = chainRegistry.getRuntimeProvider(for: chain.chainId),
              let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw ReviewedCrossChainSubmissionError.runtimeUnavailable
        }
        let capability = try await runtimeNegotiator.negotiate(
            runtime: runtime,
            descriptor: definition.execution
        )
        let builder = try callBuilder.builder(
            definition: definition,
            capability: capability,
            destinationAccountId: Data(repeating: 1, count: SubstrateConstants.accountIdLength),
            amount: max(amount, 1)
        )
        let service = ExtrinsicService(
            accountId: account.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: account.cryptoType,
            runtimeRegistry: runtime,
            engine: connection,
            operationManager: operationManager
        )
        let dispatchInfo = try await ReviewedCrossChainExtrinsicExecutor(service: service).estimateFee(builder)
        guard let fee = BigUInt(dispatchInfo.fee, radix: 10), fee > .zero else {
            throw ReviewedCrossChainSubmissionError.runtimeUnavailable
        }
        return fee
    }
}
