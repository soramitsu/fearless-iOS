import XCTest
import BigInt
import SSFModels
@testable import fearless

enum CovHSendError: Error {
    case failed
}

enum CovHSendWait {
    static func until(timeout: TimeInterval = 3, _ predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}

enum CovHSendFixtures {
    static func asset(id: String, symbol: String, utility: Bool, precision: UInt16 = 9) -> AssetModel {
        AssetModel(
            id: id, name: symbol, symbol: symbol, precision: precision, icon: nil, currencyId: nil, existentialDeposit: nil,
            color: nil, isUtility: utility, isNative: utility, staking: nil, purchaseProviders: nil, type: nil,
            ethereumType: nil, priceProvider: nil, coingeckoPriceId: nil
        )
    }

    static func chain(id: String = UUID().uuidString, name: String, assets: [AssetModel], options: [ChainOptions]? = nil) -> ChainModel {
        ChainModel(
            rank: nil, disabled: false, chainId: id, paraId: nil, name: name, assets: Set(assets), xcm: nil,
            nodes: [ChainNodeModel(url: URL(string: "wss://\(id).invalid")!, name: "node", apikey: nil)],
            addressPrefix: 42, icon: nil, options: options, iosMinAppVersion: nil, identityChain: nil
        )
    }

    static func chainAsset(chainName: String, assetUtility: Bool) -> ChainAsset {
        let asset = asset(id: "asset-\(UUID().uuidString)", symbol: "AST", utility: assetUtility)
        return ChainAsset(chain: chain(name: chainName, assets: [asset]), asset: asset)
    }

    static func bitcoin() throws -> ChainAsset {
        try XCTUnwrap(UniversalWalletRegistry.bitcoinMainnetChainModel.utilityChainAssets().first)
    }

    static func solana() throws -> ChainAsset {
        try XCTUnwrap(UniversalWalletRegistry.solanaMainnetChainModel.utilityChainAssets().first)
    }

    static func solanaToken() throws -> ChainAsset {
        let chain = UniversalWalletRegistry.solanaMainnetChainModel
        _ = try XCTUnwrap(chain.utilityAssets().first)
        return ChainAsset(chain: chain, asset: asset(id: "covh-spl-token", symbol: "CTK", utility: false, precision: 6))
    }

    static func tonJetton() -> ChainAsset {
        let native = asset(id: "ton", symbol: "TON", utility: true)
        let jetton = asset(id: "covh-jetton", symbol: "JET", utility: false)
        let chain = chain(id: "covh-ton-chain", name: "TON", assets: [native, jetton])
        return ChainAsset(chain: chain, asset: jetton)
    }

    static func xorless() -> XorlessTransfer {
        XorlessTransfer(
            dexId: "0", assetId: SoraAssetId(wrappedValue: "0x00"), receiver: Data(repeating: 2, count: 32), amount: 10,
            desiredXorAmount: 1, maxAmountIn: 2, selectedSourceTypes: [],
            filterMode: PolkaswapCallFilterModeType(wrappedName: "Disabled", wrappedValue: nil), additionalData: Data()
        )
    }
}

final class CovHSendTransferService: TransferServiceProtocol {
    private let lock = NSLock()
    private var storedTransfers: [Transfer] = []
    private var storedRetried: [String] = []
    private var storedAcknowledged: [String] = []
    private var storedPresentations: [(id: String, fee: BigUInt)] = []
    private weak var storedListener: TransferFeeEstimationListener?
    var submitResult: Result<String, Error> = .success("0xhash")
    var retryResult: Result<String, Error> = .success("0xretry")
    var feeResult: Result<BigUInt, Error> = .success(42)
    var xorlessFeeResult: Result<BigUInt, Error> = .success(43)
    var xorlessHash = "0xxor"
    var confirmAccepted = true
    var acknowledgeResult = true
    var allowReplace = false
    var unsubscribeCount = 0

    var subscribedTransfers: [Transfer] { locked { storedTransfers } }
    var retried: [String] { locked { storedRetried } }
    var acknowledged: [String] { locked { storedAcknowledged } }
    var confirmedPresentations: [(id: String, fee: BigUInt)] { locked { storedPresentations } }
    var listener: TransferFeeEstimationListener? { locked { storedListener } }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    func estimateFee(for _: Transfer) async throws -> BigUInt { try feeResult.get() }
    func submit(transfer _: Transfer) async throws -> String { try submitResult.get() }
    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener) {
        locked {
            storedTransfers.append(transfer)
            storedListener = listener
        }
    }

    func unsubscribe() { unsubscribeCount += 1 }
    func confirmFeePresentation(id: String, fee: BigUInt) async -> Bool {
        locked { storedPresentations.append((id, fee)) }
        return confirmAccepted
    }

    func acknowledgeSubmittedTransfer(hash: String, transfer _: Transfer) async -> Bool {
        locked { storedAcknowledged.append(hash) }
        return acknowledgeResult
    }

    func acknowledgeRecoveredTransfer(hash _: String, identity _: TonTransferIntentIdentity) async -> Bool { acknowledgeResult }
    func retryUnresolvedTransfer(hash: String) async throws -> String {
        locked { storedRetried.append(hash) }
        return try retryResult.get()
    }

    func allowReplacingUnresolvedTransfer(hash _: String) async -> Bool { allowReplace }
    func estimateFee(for _: XorlessTransfer) async throws -> BigUInt { try xorlessFeeResult.get() }
    func submit(transfer _: XorlessTransfer) async throws -> String { xorlessHash }
}

final class CovHSendAccountInfoAdapter: AccountInfoSubscriptionAdapterProtocol {
    var subscribed: [[ChainAsset]] = []
    var single: [ChainAsset] = []
    var resets = 0
    var wallets: [MetaAccountModel] = []
    weak var handler: AccountInfoSubscriptionAdapterHandler?

    func subscribe(
        chainAsset: ChainAsset, accountId _: AccountId, handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?, notifyJustWhenUpdated _: Bool
    ) {
        single.append(chainAsset)
        self.handler = handler
    }

    func subscribe(
        chainsAssets: [ChainAsset], handler: AccountInfoSubscriptionAdapterHandler?, deliveryOn _: DispatchQueue?, notifyJustWhenUpdated _: Bool
    ) {
        subscribed.append(chainsAssets)
        self.handler = handler
    }

    func reset() { resets += 1 }
    func unsubscribe(chainAsset _: ChainAsset) {}
    func update(wallet: MetaAccountModel) { wallets.append(wallet) }
}

final class CovHSendRemoteService: AccountInfoRemoteService {
    private let lock = NSLock()
    private var storedRequests: [ChainAsset] = []
    var error: Error?
    var accountInfo: AccountInfo?

    var requests: [ChainAsset] {
        lock.lock()
        defer { lock.unlock() }
        return storedRequests
    }

    func fetchAccountInfos(for _: ChainModel, wallet _: MetaAccountModel) async throws -> [ChainAssetId: AccountInfo?] { [:] }

    func fetchAccountInfo(for chainAsset: ChainAsset, wallet _: MetaAccountModel) async throws -> AccountInfo? {
        lock.lock()
        storedRequests.append(chainAsset)
        lock.unlock()
        if let error { throw error }
        return accountInfo
    }
}
