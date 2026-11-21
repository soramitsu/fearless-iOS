import XCTest
import BigInt
import RobinHood
import SSFModels
import SSFUtils
@testable import fearless

final class CovHChainAccountInteractorContext {
    let eventCenter = CovHChainAccountEventCenterSpy()
    let fetching = CovHChainAccountAssetFetchingStub()
    let exportOptions = CovHChainAccountExportOptionsStub()
    let adapter = CovHChainAccountBalanceAdapterSpy()
    let remote = CovHChainAccountRemoteServiceStub()
    let registry = CovHChainAccountRegistryStub()
    let output = CovHChainAccountOutputSpy()
    let wallet: MetaAccountModel
    let interactor: ChainAccountInteractor

    init(chainAsset: ChainAsset, wallet: MetaAccountModel) {
        self.wallet = wallet
        let operationManager = OperationManager()
        let cacheWrapper = BalanceRepositoryCacheWrapper(
            logger: Logger.shared,
            repository: SubstrateRepositoryFactory(storageFacade: UserDataStorageTestFacade()).createAccountInfoStorageItemRepository(),
            operationManager: operationManager
        )
        interactor = ChainAccountInteractor(
            wallet: wallet,
            chainAsset: chainAsset,
            operationManager: operationManager,
            eventCenter: eventCenter,
            repository: AccountRepositoryFactory.createRepository(for: UserDataStorageTestFacade()),
            availableExportOptionsProvider: exportOptions,
            chainAssetFetching: fetching,
            storageRequestFactory: StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: operationManager),
            walletBalanceSubscriptionAdapter: adapter,
            ethRemoteBalanceFetching: EthereumRemoteBalanceFetching(chainRegistry: registry, repositoryWrapper: cacheWrapper),
            chainRegistry: registry,
            accountInfoRemoteService: remote
        )
        interactor.presenter = output
    }

    static func bitcoin(remoteInfo: AccountInfo? = nil, error: Error? = nil) throws -> CovHChainAccountInteractorContext {
        let chainAsset = try CovHChainAccountFixture.bitcoinChainAsset()
        let wallet = CovHChainAccountFixture.wallet(extraAccounts: [CovHChainAccountFixture.bitcoinAccount()])
        let context = CovHChainAccountInteractorContext(chainAsset: chainAsset, wallet: wallet)
        context.remote.accountInfo = remoteInfo
        context.remote.error = error
        context.fetching.result = .success([chainAsset, CovHChainAccountFixture.chainAsset()])
        return context
    }
}

final class CovHChainAccountInteractorTests: XCTestCase {
    func testUniversalSetupReportsZeroLocksAndTheRemoteAccountInfo() throws {
        let info = AccountInfo(nonce: 0, consumers: 0, providers: 1, data: AccountData(free: 21, reserved: .zero, frozen: .zero))
        let context = try CovHChainAccountInteractorContext.bitcoin(remoteInfo: info)
        context.interactor.setup()

        XCTAssertEqual(context.eventCenter.observers.count, 1)
        XCTAssertEqual(context.fetching.filters.first?.count, 2)
        XCTAssertTrue(context.fetching.filters.first?.contains(.enabledChains) == true)
        XCTAssertEqual(Array(context.output.events.prefix(4)), ["available", "locks", "frozen", "minimum"])
        XCTAssertEqual(context.output.availableChainAssets.first?.map(\.chain.chainId), [context.interactor.chainAsset.chain.chainId])
        XCTAssertEqual(context.interactor.availableChainAssets.count, 1)
        if case let .success(value) = context.output.minimumBalances.first {
            XCTAssertEqual(value, .zero)
        } else {
            XCTFail("A universal chain has no existential deposit")
        }

        CovHChainAccountFixture.spin { context.output.events.contains("accountInfo") }
        XCTAssertEqual(context.output.accountInfos, [info])
        XCTAssertEqual(context.remote.requests.map(\.chain.chainId), [UniversalWalletRegistry.bitcoinMainnet.chainId])
        XCTAssertFalse(context.interactor.checkIsClaimAvailable())
        XCTAssertTrue(context.registry.runtimeRequests.isEmpty, "claims are only checked with a legacy crowdloan lock")
    }

    func testUniversalRemoteFailureReportsNoAccountInfo() throws {
        let context = try CovHChainAccountInteractorContext.bitcoin(error: NSError(domain: "remote", code: 1))
        context.interactor.setup()
        CovHChainAccountFixture.spin { context.output.events.contains("accountInfo") }
        XCTAssertEqual(context.output.accountInfos.count, 1)
        XCTAssertNil(context.output.accountInfos.first ?? AccountInfo(ethBalance: 1))
    }

    func testFailedChainAssetFetchLeavesNoAvailableChainAssets() throws {
        let context = try CovHChainAccountInteractorContext.bitcoin()
        context.fetching.result = .failure(NSError(domain: "fetch", code: 2))
        context.interactor.setup()
        XCTAssertEqual(context.output.availableChainAssets.first?.count, 0)
        XCTAssertTrue(context.interactor.availableChainAssets.isEmpty)
    }

    func testSubstrateChainWithoutRuntimeReportsLockErrorsAndMissingDeposit() {
        let chainAsset = CovHChainAccountFixture.chainAsset()
        let context = CovHChainAccountInteractorContext(chainAsset: chainAsset, wallet: CovHChainAccountFixture.wallet())
        context.fetching.result = .success([chainAsset])
        context.interactor.setup()
        XCTAssertEqual(Array(context.output.events.prefix(4)), ["available", "locksError", "frozenError", "minimum"])
        if case .success = context.output.minimumBalances.first {
            XCTFail("An unknown chain has no runtime to read the deposit from")
        }
    }

    func testEthereumSetupReportsLockErrors() {
        let chainAsset = CovHChainAccountFixture.chainAsset(options: [.ethereum])
        let context = CovHChainAccountInteractorContext(chainAsset: chainAsset, wallet: CovHChainAccountFixture.wallet())
        context.interactor.setup()
        context.interactor.updateData()
        XCTAssertTrue(context.output.events.contains("locksError"))
        XCTAssertTrue(context.output.events.contains("minimum"))
    }

    func testExportOptionsOnUniversalChainAreEmpty() throws {
        let context = try CovHChainAccountInteractorContext.bitcoin()
        context.interactor.getAvailableExportOptions(for: "any")
        XCTAssertEqual(context.output.exportOptions, [[]])
        XCTAssertTrue(context.exportOptions.requests.isEmpty)
    }

    func testExportOptionsForTheWalletAccountComeFromTheProvider() throws {
        let chainAsset = CovHChainAccountFixture.chainAsset()
        let wallet = CovHChainAccountFixture.wallet()
        let context = CovHChainAccountInteractorContext(chainAsset: chainAsset, wallet: wallet)
        let address = try XCTUnwrap(wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress())
        context.exportOptions.options = [.seed]
        context.interactor.getAvailableExportOptions(for: address)
        XCTAssertEqual(context.output.exportOptions, [[.seed]])
        XCTAssertEqual(context.exportOptions.requests.count, 1)
        XCTAssertNil(context.exportOptions.requests.first?.0, "the wallet's own account exports the whole wallet")
        XCTAssertEqual(context.exportOptions.requests.first?.1, false)
    }

    func testExportOptionsForAChainAccountPassTheAccountId() throws {
        let chainAsset = CovHChainAccountFixture.chainAsset()
        let chainAccount = ChainAccountModel(
            chainId: "other-chain", accountId: Data(repeating: 9, count: 32), publicKey: Data(repeating: 9, count: 32),
            cryptoType: 0, ethereumBased: false
        )
        let wallet = CovHChainAccountFixture.wallet(extraAccounts: [chainAccount])
        let context = CovHChainAccountInteractorContext(chainAsset: chainAsset, wallet: wallet)
        let address = try chainAccount.accountId.toAddress(using: .substrate(chainAsset.chain.addressPrefix))
        context.interactor.getAvailableExportOptions(for: address)
        XCTAssertEqual(context.output.exportOptions, [context.exportOptions.options])
        XCTAssertEqual(context.exportOptions.requests.first?.0, chainAccount.accountId)
    }

    func testExportOptionsForAnUnknownAddressFallBackToKeystore() {
        let context = CovHChainAccountInteractorContext(chainAsset: CovHChainAccountFixture.chainAsset(), wallet: CovHChainAccountFixture.wallet())
        context.interactor.getAvailableExportOptions(for: "unknown-address")
        XCTAssertEqual(context.output.exportOptions, [[.keystore]])
        XCTAssertTrue(context.exportOptions.requests.isEmpty)
    }

    func testUpdateSelectsAnAvailableChainAndRefetches() throws {
        let context = try CovHChainAccountInteractorContext.bitcoin()
        context.interactor.setup()
        let chain = context.interactor.chainAsset.chain
        context.interactor.update(chain: chain)
        XCTAssertEqual(context.output.updatedChainAssets.map(\.chain.chainId), [chain.chainId])
        XCTAssertEqual(context.output.events.filter { $0 == "locks" }.count, 2)
    }

    func testChainsUpdatedEventReplacesTheMatchingChainOnly() throws {
        let context = try CovHChainAccountInteractorContext.bitcoin()
        let original = context.interactor.chainAsset
        context.interactor.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [CovHChainAccountFixture.chain(name: "Unrelated")]))
        XCTAssertEqual(context.interactor.chainAsset.chain.name, original.chain.name)
        XCTAssertTrue(context.output.events.isEmpty)

        let renamed = CovHChainAccountFixture.chain(id: original.chain.chainId, name: "Renamed", assets: original.chain.assets)
        context.interactor.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [renamed]))
        XCTAssertEqual(context.interactor.chainAsset.chain.name, "Renamed")
        XCTAssertEqual(context.interactor.chainAsset.asset.id, original.asset.id)
        XCTAssertEqual(Array(context.output.events.prefix(3)), ["locks", "frozen", "minimum"])
    }

    func testSelectedAccountChangeForwardsTheNewWallet() throws {
        let context = try CovHChainAccountInteractorContext.bitcoin()
        let replacement = CovHChainAccountFixture.wallet()
        context.interactor.processSelectedAccountChanged(event: SelectedAccountChanged(account: replacement))
        XCTAssertEqual(context.output.events, ["wallet"], "a wallet without a Bitcoin account fetches nothing")
        XCTAssertEqual(context.output.wallets.map(\.metaId), [replacement.metaId])
    }

    func testBalanceListenerDescribesItselfAndForwardsResults() throws {
        let context = try CovHChainAccountInteractorContext.bitcoin()
        guard case let .chainAsset(wallet, chainAsset) = context.interactor.type else {
            return XCTFail("The chain account screen listens to one chain asset")
        }
        XCTAssertEqual(wallet.metaId, context.wallet.metaId)
        XCTAssertEqual(chainAsset.chain.chainId, UniversalWalletRegistry.bitcoinMainnet.chainId)
        context.interactor.handle(result: .success([:]))
        XCTAssertEqual(context.output.events, ["balances"])
    }
}
