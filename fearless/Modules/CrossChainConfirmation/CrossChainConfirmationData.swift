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
    case runtimeCallUnavailable
    case invalidRecipient
    case invalidAmount
    case belowMinimum
    case destinationFeeUnavailable
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
        case .runtimeCallUnavailable:
            return "The current runtime does not expose the reviewed bridge call and argument shape."
        case .invalidRecipient:
            return "The destination address is invalid for the reviewed destination network."
        case .invalidAmount:
            return "Enter a positive cross-chain amount."
        case .belowMinimum:
            return "The amount is below the reviewed minimum for this exact route."
        case .destinationFeeUnavailable:
            return "A current destination fee is unavailable for this exact route."
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
        mutationsEnabled: Bool = MultiChainFeaturePolicy.current.crossChainMutationsEnabled,
        executionAdapterAvailable: Bool = ReviewedXcmExecutionAuthority.isAvailable
    ) throws {
        guard mutationsEnabled else {
            throw ReviewedCrossChainSubmissionError.actionsPaused
        }
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
}

protocol ReviewedCrossChainRuntimeNegotiating {
    func negotiate(
        runtime: RuntimeProviderProtocol,
        descriptor: ReviewedCrossChainExecutionDescriptor
    ) async throws -> ReviewedCrossChainRuntimeCapability
}

struct ReviewedCrossChainRuntimeNegotiator: ReviewedCrossChainRuntimeNegotiating {
    func negotiate(
        runtime: RuntimeProviderProtocol,
        descriptor: ReviewedCrossChainExecutionDescriptor
    ) async throws -> ReviewedCrossChainRuntimeCapability {
        guard let snapshot = runtime.snapshot else {
            throw ReviewedCrossChainSubmissionError.runtimeUnavailable
        }
        let factory = try await runtime.fetchCoderFactory()
        let modules = factory.metadata.modules.filter {
            normalize($0.name) == normalize(descriptor.runtimeCall.requestedModuleName)
        }
        guard modules.count == 1, let module = modules.first,
              let calls = try module.calls(using: factory.metadata.schemaResolver) else {
            throw ReviewedCrossChainSubmissionError.runtimeCallUnavailable
        }
        let matchingCalls = calls.filter {
            normalize($0.name) == normalize(descriptor.runtimeCall.requestedCallName)
        }
        guard matchingCalls.count == 1, let call = matchingCalls.first else {
            throw ReviewedCrossChainSubmissionError.runtimeCallUnavailable
        }
        let arguments = call.arguments.map { normalize($0.name) }
        guard arguments == ["networkid", "assetid", "recipient", "amount"] else {
            throw ReviewedCrossChainSubmissionError.runtimeCallUnavailable
        }
        return ReviewedCrossChainRuntimeCapability(
            moduleName: module.name,
            callName: call.name,
            specVersion: snapshot.specVersion
        )
    }

    private func normalize(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "_", with: "")
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

private enum ReviewedBridgeJunctionNetworkId: Codable {
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

private struct ReviewedBridgeAccountId32: Codable {
    let network: ReviewedBridgeJunctionNetworkId
    @BytesCodable var id: AccountId
}

private enum ReviewedBridgeJunction: Codable {
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

private struct ReviewedBridgeJunctions: Codable {
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

private struct ReviewedBridgeMultiLocation: Codable {
    @StringCodable var parents: UInt8
    let interior: ReviewedBridgeJunctions
}

private enum ReviewedBridgeVersionedMultiLocation: Codable {
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

private enum ReviewedBridgeGenericAccount: Codable {
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
}

struct ReviewedCrossChainCallBuilder: ReviewedCrossChainCallBuilding {
    func builder(
        definition: ReviewedXcmRouteDefinition,
        capability: ReviewedCrossChainRuntimeCapability,
        destinationAccountId: AccountId,
        amount: BigUInt
    ) throws -> ExtrinsicBuilderClosure {
        guard destinationAccountId.count == SubstrateConstants.accountIdLength,
              amount > .zero else {
            throw ReviewedCrossChainSubmissionError.invalidRecipient
        }

        switch definition.execution.runtimeCall {
        case .soraBridgeProxyBurn:
            guard case let .soraAsset(currencyId) = definition.execution.asset else {
                throw ReviewedCrossChainSubmissionError.unreviewedRoute
            }
            let networkId = try ReviewedBridgeSubNetworkId(definition.execution.network)
            let recipient = try makeSoraRecipient(
                definition.execution.recipient,
                accountId: destinationAccountId
            )
            let call = RuntimeCall(
                moduleName: capability.moduleName,
                callName: capability.callName,
                args: ReviewedSoraBridgeProxyBurnCall(
                    networkId: .sub(networkId),
                    assetId: SoraAssetId(wrappedValue: currencyId),
                    recipient: recipient,
                    amount: amount
                )
            )
            return { try $0.adding(call: call) }
        case .liberlandSoraBridgeAppBurn:
            guard definition.execution.network == .soraMainnet,
                  definition.execution.recipient == .sora else {
                throw ReviewedCrossChainSubmissionError.unreviewedRoute
            }
            let assetId: ReviewedLiberlandAssetId
            switch definition.execution.asset {
            case let .liberlandAsset(currencyId):
                assetId = .asset(currencyId)
            case .liberlandNativeLLD:
                assetId = .lld
            case .soraAsset:
                throw ReviewedCrossChainSubmissionError.unreviewedRoute
            }
            let call = RuntimeCall(
                moduleName: capability.moduleName,
                callName: capability.callName,
                args: ReviewedLiberlandSoraBridgeAppBurnCall(
                    networkId: .mainnet,
                    assetId: assetId,
                    recipient: .sora(destinationAccountId),
                    amount: amount
                )
            )
            return { try $0.adding(call: call) }
        }
    }

    private func makeSoraRecipient(
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
            return .parachain(
                .v3(
                    ReviewedBridgeMultiLocation(
                        parents: 0,
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

protocol ReviewedCrossChainExtrinsicExecuting: AnyObject {
    func estimateFee(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo
    func submit(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> String
}

final class ReviewedCrossChainExtrinsicExecutor: ReviewedCrossChainExtrinsicExecuting {
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

struct ReviewedCrossChainAuthorizedSubmission {
    let builder: ExtrinsicBuilderClosure
    let executor: ReviewedCrossChainExtrinsicExecuting
    let finalGuard: () throws -> Void
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
        let executor: ReviewedCrossChainExtrinsicExecuting
    }

    private let data: CrossChainConfirmationData
    private let expectedWalletId: MetaAccountId
    private let expectedRouteFingerprint: String
    private let destinationFeeProvider: XcmDestinationFeeFetching
    private let callBuilder: ReviewedCrossChainCallBuilding
    private let runtimeNegotiator: ReviewedCrossChainRuntimeNegotiating
    private let chainRegistry: ChainRegistryProtocol
    private let keystore: KeystoreProtocol
    private let selectedWallet: () -> MetaAccountModel?
    private let mutationsEnabled: () -> Bool

    init(
        data: CrossChainConfirmationData,
        destinationFeeProvider: XcmDestinationFeeFetching,
        callBuilder: ReviewedCrossChainCallBuilding = ReviewedCrossChainCallBuilder(),
        runtimeNegotiator: ReviewedCrossChainRuntimeNegotiating = ReviewedCrossChainRuntimeNegotiator(),
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
        self.chainRegistry = chainRegistry
        self.keystore = keystore
        self.selectedWallet = selectedWallet
        self.mutationsEnabled = mutationsEnabled
    }

    func authorize() async throws -> ReviewedCrossChainAuthorizedSubmission {
        try validatePolicyAndWallet()
        let context = try makeFreshContext()

        // Two independent passes deliberately repeat current runtime-call
        // negotiation, destination fee, exact balance, minimum and origin-fee
        // checks. Only the second pass's exact builder may be submitted.
        _ = try await authorizeRound(context)
        try validateCurrentContext(context)
        let builder = try await authorizeRound(context)
        try validateCurrentContext(context)

        return ReviewedCrossChainAuthorizedSubmission(
            builder: builder,
            executor: context.executor,
            finalGuard: { [weak self] in
                guard let self else {
                    throw ReviewedCrossChainSubmissionError.runtimeUnavailable
                }
                try self.validateCurrentContext(context)
            }
        )
    }

    private func authorizeRound(_ context: Context) async throws -> ExtrinsicBuilderClosure {
        try validateCurrentContext(context)
        let capability = try await runtimeNegotiator.negotiate(
            runtime: context.runtime,
            descriptor: context.definition.execution
        )
        guard capability.specVersion == context.runtimeSpecVersion else {
            throw ReviewedCrossChainSubmissionError.runtimeUnavailable
        }
        let destinationFee = try await destinationFeeInOriginUnits(context)
        let burnAmount = data.amount + destinationFee
        let builder = try callBuilder.builder(
            definition: context.definition,
            capability: capability,
            destinationAccountId: context.destinationAccountId,
            amount: burnAmount
        )
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
        return builder
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
        let destinationPrecision: UInt16
        if let rawPrecision = response.precision,
           let parsedPrecision = UInt16(rawPrecision) {
            destinationPrecision = parsedPrecision
        } else {
            destinationPrecision = context.definition.originPrecision
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
            reviewedRoute: data.reviewedRoute
        )
        let account = try validateSigningAccount(wallet: wallet, chain: originChain)
        guard let destinationAccountId = try? AddressFactory.accountId(
            from: data.recipientAddress,
            chain: destination
        ), destinationAccountId.count == SubstrateConstants.accountIdLength else {
            throw ReviewedCrossChainSubmissionError.invalidRecipient
        }
        guard let runtime = chainRegistry.getRuntimeProvider(for: originChain.chainId),
              let snapshot = runtime.snapshot,
              let connection = chainRegistry.getConnection(for: originChain.chainId) else {
            throw ReviewedCrossChainSubmissionError.runtimeUnavailable
        }
        let signer = SigningWrapper(
            keystore: keystore,
            metaId: wallet.metaId,
            accountResponse: account
        )
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
            executor: ReviewedCrossChainExtrinsicExecutor(service: extrinsic, signer: signer)
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

    private func validateCurrentContext(_ context: Context) throws {
        try validatePolicyAndWallet()
        guard data.reviewedRoute.routeId == expectedRouteFingerprint,
              let wallet = selectedWallet(),
              wallet.metaId == context.wallet.metaId,
              let originChain = chainRegistry.getChain(for: context.origin.chain.chainId),
              originChain == context.origin.chain,
              let destination = chainRegistry.getChain(for: context.destination.chainId),
              destination == context.destination,
              let currentOrigin = exactOrigin(definition: context.definition, chain: originChain),
              let runtime = chainRegistry.getRuntimeProvider(for: originChain.chainId),
              ObjectIdentifier(runtime) == ObjectIdentifier(context.runtime),
              runtime.snapshot?.specVersion == context.runtimeSpecVersion,
              let connection = chainRegistry.getConnection(for: originChain.chainId),
              ObjectIdentifier(connection) == ObjectIdentifier(context.connection),
              let destinationAccountId = try? AddressFactory.accountId(
                  from: data.recipientAddress,
                  chain: destination
              ),
              destinationAccountId == context.destinationAccountId else {
            throw ReviewedCrossChainSubmissionError.runtimeUnavailable
        }
        try ReviewedCrossChainSubmissionValidator.validate(
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
