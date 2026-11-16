import BigInt
@testable import fearless
import Foundation
import RobinHood
import SSFModels
import XCTest

final class CovGWalletSubscriberTests: XCTestCase {
    private let account = Data(repeating: 1, count: 32)

    func testEmptyChangesAndProviderFailuresPreserveAccountAndAsset() throws {
        let asset = try chainAsset(type: .normal)
        let factory = CovGWalletFactory()
        let subscriber = CovGWalletSubscriber(factory: factory)
        XCTAssertTrue(subscriber.subscribeToAccountInfoProvider(for: account, chainAsset: asset, notifyJustWhenUpdated: true) === factory.provider)
        waitUntil { subscriber.results.count == 1 && factory.observable.isObserved }
        XCTAssertNil(try subscriber.results[0].0.get())
        XCTAssertEqual(subscriber.results[0].1, account)
        XCTAssertEqual(subscriber.results[0].2, asset)
        factory.observable.emit([.delete(deletedIdentifier: "balance")])
        waitUntil { subscriber.results.count == 2 }
        XCTAssertNil(try subscriber.results[1].0.get())
        factory.error = NSError(domain: "CovG.factory", code: 83)
        XCTAssertNil(subscriber.subscribeToAccountInfoProvider(for: account, chainAsset: asset, notifyJustWhenUpdated: false))
        let failed = CovGWalletFactory(result: .failure(NSError(domain: "CovG.provider", code: 84)))
        let failedSubscriber = CovGWalletSubscriber(factory: failed)
        XCTAssertNotNil(failedSubscriber.subscribeToAccountInfoProvider(for: account, chainAsset: asset, notifyJustWhenUpdated: false))
        waitUntil { failedSubscriber.results.count == 1 }
        XCTAssertThrowsError(try failedSubscriber.results[0].0.get()) { XCTAssertEqual(($0 as NSError).code, 84) }
    }

    func testEthereumBalancesDecodeAndMalformedJSONIsReported() throws {
        let asset = try chainAsset(type: .normal, options: [.ethereum])
        let expected = AccountInfo(ethBalance: 53)
        let factory = CovGWalletFactory()
        let subscriber = try subscribe(factory, asset: asset)
        try factory.observable.emit([.insert(newItem: AccountInfoStorageWrapper(identifier: "balance", data: JSONEncoder().encode(expected)))])
        waitUntil { subscriber.results.count == 2 }
        XCTAssertEqual(try subscriber.results[1].0.get(), expected)
        factory.observable.emit([.update(newItem: AccountInfoStorageWrapper(identifier: "balance", data: Data("invalid".utf8)))])
        waitUntil { subscriber.results.count == 3 }
        XCTAssertThrowsError(try subscriber.results[2].0.get())
    }

    func testSubstrateAndAssetVariantsMapDecodedBalances() throws {
        let variants: [SubstrateAssetType] = [.normal, .ormlChain, .ormlAsset, .foreignAsset, .stableAssetPoolToken,
                                              .liquidCrowdloan, .vToken, .vsToken, .stable, .assetId, .token2, .xcm, .assets, .soraAsset]
        for type in variants {
            let asset = try chainAsset(type: type)
            let factory = CovGWalletFactory()
            factory.manager.configure = { operation in
                if let operation = operation as? StorageDecodingOperation<AccountInfo?> {
                    operation.result = .success(AccountInfo(ethBalance: 53))
                } else if let operation = operation as? StorageDecodingOperation<OrmlAccountInfo?> {
                    operation.result = .success(try? JSONDecoder().decode(OrmlAccountInfo.self, from: Data(#"{"free":"53","reserved":"7","frozen":"3"}"#.utf8)))
                } else if let operation = operation as? StorageDecodingOperation<AssetAccount?> {
                    operation.result = .success(try? JSONDecoder().decode(AssetAccount.self, from: Data(#"{"balance":"53"}"#.utf8)))
                }
            }
            let subscriber = try subscribe(factory, asset: asset)
            factory.observable.emit([.insert(newItem: AccountInfoStorageWrapper(identifier: "balance", data: Data()))])
            waitUntil { subscriber.results.count == 2 }
            let result = try XCTUnwrap(subscriber.results[1].0.get())
            XCTAssertEqual(result.data.free, 53, "\(type)")
            XCTAssertEqual(subscriber.results[1].1, account)
            XCTAssertEqual(subscriber.results[1].2, asset)
        }
    }

    func testEquilibriumBalancesMapOnlyAssetsWithCurrencyIdentifiers() throws {
        let asset = try chainAsset(type: .equilibrium)
        let factory = CovGWalletFactory()
        factory.manager.configure = { operation in
            guard let decoding = operation as? StorageDecodingOperation<EquilibriumAccountInfo?> else { return }
            let json = #"{"nonce":"0","consumers":"0","providers":"1","sufficients":"0","data":["V0",{"balance":[["7",["Positive","53"]]]}]}"#
            decoding.result = .success(try? JSONDecoder().decode(EquilibriumAccountInfo.self, from: Data(json.utf8)))
        }
        let subscriber = try subscribe(factory, asset: asset)
        factory.observable.emit([.insert(newItem: AccountInfoStorageWrapper(identifier: "balance", data: Data()))])
        waitUntil { subscriber.results.count == 2 }
        XCTAssertEqual(try subscriber.results[1].0.get()?.data.free, 53)
        XCTAssertEqual(subscriber.results[1].2.asset.currencyId, "7")
    }

    func testDecoderFailuresAndMissingValuesAreForwardedForEachStorageShape() throws {
        for type in [SubstrateAssetType.normal, .ormlAsset, .assets, .equilibrium] {
            for failure in [false, true] {
                let factory = CovGWalletFactory()
                factory.manager.configure = { operation in
                    let error = NSError(domain: "CovG.decode", code: 85)
                    if let decoder = operation as? StorageDecodingOperation<AccountInfo?> {
                        decoder.result = failure ? .failure(error) : .success(nil)
                    }
                    if let decoder = operation as? StorageDecodingOperation<OrmlAccountInfo?> {
                        decoder.result = failure ? .failure(error) : .success(nil)
                    }
                    if let decoder = operation as? StorageDecodingOperation<AssetAccount?> {
                        decoder.result = failure ? .failure(error) : .success(nil)
                    }
                    if let decoder = operation as? StorageDecodingOperation<EquilibriumAccountInfo?> {
                        decoder.result = failure ? .failure(error) : .success(nil)
                    }
                }
                let subscriber = try subscribe(factory, asset: chainAsset(type: type))
                factory.observable.emit([.insert(newItem: AccountInfoStorageWrapper(identifier: "balance", data: Data()))])
                waitUntil { subscriber.results.count == 2 }
                if failure {
                    XCTAssertThrowsError(try subscriber.results[1].0.get()) { XCTAssertEqual(($0 as NSError).code, 85) }
                } else {
                    XCTAssertNil(try subscriber.results[1].0.get())
                }
            }
        }
    }

    private func subscribe(_ factory: CovGWalletFactory, asset: ChainAsset) throws -> CovGWalletSubscriber {
        let subscriber = CovGWalletSubscriber(factory: factory)
        XCTAssertNotNil(subscriber.subscribeToAccountInfoProvider(for: account, chainAsset: asset, notifyJustWhenUpdated: false))
        waitUntil { subscriber.results.count == 1 && factory.observable.isObserved }
        XCTAssertNil(try subscriber.results[0].0.get())
        XCTAssertEqual(factory.lastAccount, account)
        XCTAssertEqual(factory.lastAsset, asset)
        return subscriber
    }

    private func chainAsset(type: SubstrateAssetType, options: [ChainOptions] = []) throws -> ChainAsset {
        let asset = AssetModel(id: "7", name: "Token", symbol: "UNIT", precision: 12, currencyId: "7", isUtility: false, isNative: false, type: type)
        let chain = ChainModel(
            rank: nil, disabled: false, chainId: "1", paraId: nil, name: "Coverage chain", assets: [asset], xcm: nil,
            nodes: [], addressPrefix: 42, icon: nil, options: options, externalApi: nil, iosMinAppVersion: nil, identityChain: nil
        )
        return ChainAsset(chain: chain, asset: asset)
    }

    private func waitUntil(_ predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(10)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(predicate())
    }
}

private final class CovGWalletSubscriber: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    private let lock = NSLock()
    private var received: [(Result<AccountInfo?, Error>, AccountId, ChainAsset)] = []
    var results: [(Result<AccountInfo?, Error>, AccountId, ChainAsset)] {
        lock.lock(); defer { lock.unlock() }; return received
    }

    init(factory: WalletLocalSubscriptionFactoryProtocol) {
        walletLocalSubscriptionFactory = factory
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        lock.lock(); received.append((result, accountId, chainAsset)); lock.unlock()
    }
}

private final class CovGWalletFactory: WalletLocalSubscriptionFactoryProtocol {
    let observable = CovGStreamObservable<AccountInfoStorageWrapper>()
    let provider: StreamableProvider<AccountInfoStorageWrapper>
    let manager = CovGDecodingManager()
    var operationManager: OperationManagerProtocol {
        manager
    }

    var processingQueue: DispatchQueue? {
        .main
    }

    var runtime: RuntimeProviderProtocol? = CovGHistoryRuntime()
    var error: Error?
    var lastAccount: AccountId?
    var lastAsset: ChainAsset?
    init(result: Result<[AccountInfoStorageWrapper], Error> = .success([])) {
        provider = observable.provider(result: result)
    }

    func getAccountProvider(for accountId: AccountId, chainAsset: ChainAsset) throws -> StreamableProvider<AccountInfoStorageWrapper> {
        if let error {
            throw error
        }
        lastAccount = accountId; lastAsset = chainAsset
        return provider
    }

    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? {
        runtime
    }
}

private final class CovGDecodingManager: OperationManagerProtocol {
    var configure: ((Operation) -> Void)?
    private let queue = OperationQueue()
    func enqueue(operations: [Operation], in _: OperationMode) {
        operations.forEach { configure?($0) }
        queue.addOperations(operations, waitUntilFinished: false)
    }
}
