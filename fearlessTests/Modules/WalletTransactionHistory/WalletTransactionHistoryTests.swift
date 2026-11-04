import Foundation
import RobinHood
import SoraFoundation
import SSFModels
import SSFUtils
import TonSwift
import UIKit
import XCTest
@testable import fearless

@MainActor
final class WalletTransactionHistoryTests: XCTestCase {
    private let asset = AssetModel(id: "ETH", name: "Ether", symbol: "ETH", precision: 18, isUtility: true, isNative: true, ethereumType: .normal)

    func testPageFailurePreservesLoadedHistoryAndStopsAutomaticRetryLoop() throws {
        let (interactor, remote, output) = try fixture()
        remote.complete(0, .success(page("first", context: ["next": "page-2"])))
        XCTAssertTrue(interactor.loadNext())
        remote.complete(1, .failure(HistoryFixtureError.unavailable))
        XCTAssertEqual(interactor.pages.flatMap(\.transactions).map(\.transactionId), ["first"])
        XCTAssertEqual(output.pages.count, 1)
        XCTAssertEqual(output.failures, 1)
        XCTAssertEqual(output.cachedHistoryOnFailure, [true])
        XCTAssertFalse(interactor.loadNext())
        XCTAssertEqual(remote.calls.count, 2)
        interactor.reload()
        remote.complete(2, .success(page("fresh", context: ["next": "retry-next"])))
        XCTAssertEqual(interactor.pages.flatMap(\.transactions).map(\.transactionId), ["fresh"])
        XCTAssertTrue(interactor.loadNext())
        XCTAssertEqual(remote.calls.last?.pagination.context, ["next": "retry-next"])
    }

    func testProviderRefreshFailureDoesNotDiscardPreviouslyLoadedPages() throws {
        let (interactor, remote, output) = try fixture()
        remote.complete(0, .success(page("first", context: ["next": "older"])))
        XCTAssertTrue(interactor.loadNext())
        remote.complete(1, .success(page("older")))
        interactor.handleDataProvider(error: HistoryFixtureError.unavailable)
        XCTAssertEqual(interactor.pages.flatMap(\.transactions).map(\.transactionId), ["first", "older"])
        XCTAssertEqual(output.pages.count, 2)
        XCTAssertEqual(output.failures, 1)
    }

    func testEmptyPageWithContinuationStillLoadsTheNextPage() throws {
        // Iroha Torii scans a fixed window of blocks per request, so a page can be empty while
        // older transfers remain behind its cursor.
        let (interactor, remote, output) = try fixture()
        remote.complete(0, .success(AssetTransactionPageData(transactions: [], context: ["cursor": "older-window"])))
        XCTAssertEqual(output.failures, 0)
        XCTAssertTrue(interactor.loadNext())
        XCTAssertEqual(remote.calls.last?.pagination.context, ["cursor": "older-window"])
        remote.complete(1, .success(page("older")))
        XCTAssertEqual(interactor.pages.flatMap(\.transactions).map(\.transactionId), ["older"])
        XCTAssertEqual(output.pages.count, 2)
    }

    func testNilCompletionFailsVisiblyInsteadOfCreatingEmptyHistory() throws {
        for value: Result<AssetTransactionPageData?, Error>? in [nil, .success(nil)] {
            let (_, remote, output) = try fixture()
            remote.complete(0, value)
            XCTAssertEqual(output.failures, 1)
            XCTAssertEqual(output.cachedHistoryOnFailure, [false])
            XCTAssertTrue(output.pages.isEmpty)
        }
    }

    func testProviderFailureDuringReloadPreservesRowsAndRejectsPendingCompletionUntilRetry() throws {
        let (interactor, remote, output) = try fixture()
        remote.complete(0, .success(page("loaded")))
        interactor.reload()
        interactor.handleDataProvider(error: HistoryFixtureError.unavailable)
        XCTAssertEqual(output.failures, 1)
        XCTAssertEqual(output.cachedHistoryOnFailure, [true])
        XCTAssertFalse(interactor.loadNext())
        XCTAssertEqual(interactor.pages.flatMap(\.transactions).map(\.transactionId), ["loaded"])
        remote.complete(1, .success(page("stale-pending-reload")))
        XCTAssertEqual(output.pages.count, 1)
        XCTAssertFalse(interactor.loadNext())
        interactor.reload()
        remote.complete(2, .success(page("retry-recovered", context: ["next": "older"])))
        XCTAssertEqual(output.pages.last?.0.transactions.first?.transactionId, "retry-recovered")
        XCTAssertTrue(interactor.loadNext())
    }

    func testRetryRecreatesDependenciesAfterTransientSetupFailure() throws {
        let remote = HistoryRecoveryRemote()
        let dependencies = HistoryDependencies(remote: remote)
        dependencies.shouldFail = true
        let (interactor, _, output) = try fixture(dependencies: dependencies)
        XCTAssertEqual(output.failures, 1)
        XCTAssertNil(dependencies.dependencies)
        XCTAssertFalse(interactor.loadNext())
        dependencies.shouldFail = false
        interactor.reload()
        XCTAssertEqual(dependencies.creationCount, 2)
        remote.complete(0, .success(page("recovered-after-setup")))
        XCTAssertEqual(output.pages.last?.0.transactions.first?.transactionId, "recovered-after-setup")
    }

    func testStaleWalletResponseCannotReplaceCurrentWalletHistory() throws {
        let (interactor, remote, output) = try fixture()
        let replacement = wallet(byte: 0x22)
        interactor.processSelectedAccountChanged(event: SelectedAccountChanged(account: replacement))
        XCTAssertEqual(output.resets, 1)
        XCTAssertEqual(remote.calls.count, 2)
        XCTAssertEqual(remote.calls[1].address.lowercased(), "0x" + String(repeating: "22", count: 20))
        remote.complete(0, .success(page("wrong-wallet")))
        XCTAssertTrue(output.pages.isEmpty)
        remote.complete(1, .success(page("right-wallet")))
        XCTAssertEqual(output.pages.last?.0.transactions.first?.transactionId, "right-wallet")
        XCTAssertEqual(interactor.historyExplorerURL()?.absoluteString.lowercased(), "https://etherscan.io/address/0x" + String(repeating: "22", count: 20))
    }

    /// decisions.md: BTC/SOL history may degrade to an explorer link, never to an error dead end.
    /// Solana has no history indexer and Bitcoin's can fail; neither network has registry
    /// explorers, so the app-owned explorer of the wallet's own address is offered.
    func testSolanaAndBitcoinHistoryOfferTheExplorerOfTheWalletsAddress() throws {
        let phrase = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let wallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: try UniversalWalletAccountProvisioning.addingSolanaMainnetAccount(
                to: wallet(byte: 0x11), mnemonic: phrase
            ),
            mnemonic: phrase
        )
        let solana = try SolanaKeyDerivation.deriveAccount(mnemonic: phrase)
        let bitcoinAccount = try XCTUnwrap(wallet.chainAccounts.first {
            $0.chainId == UniversalWalletRegistry.bitcoinMainnet.chainId
        })
        let bitcoinAddress = try XCTUnwrap(
            UniversalWalletChainAccountSupport.address(for: bitcoinAccount.chainId, publicKey: bitcoinAccount.publicKey)
        )

        let solanaHistory = makeInteractor(
            chain: UniversalWalletRegistry.solanaMainnetChainModel, wallet: wallet,
            dependencies: HistoryDependencies(remote: HistoryRecoveryRemote())
        )
        let bitcoinHistory = makeInteractor(
            chain: UniversalWalletRegistry.bitcoinMainnetChainModel, wallet: wallet,
            dependencies: HistoryDependencies(remote: HistoryRecoveryRemote())
        )

        XCTAssertEqual(
            solanaHistory.historyExplorerURL()?.absoluteString,
            "https://solscan.io/account/\(solana.address)",
            "Solscan, as the browser extension links to"
        )
        XCTAssertEqual(bitcoinHistory.historyExplorerURL()?.absoluteString, "https://mempool.space/address/\(bitcoinAddress)")
        XCTAssertNil(
            makeInteractor(
                chain: UniversalWalletRegistry.solanaMainnetChainModel, wallet: self.wallet(byte: 0x12),
                dependencies: HistoryDependencies(remote: HistoryRecoveryRemote())
            ).historyExplorerURL(),
            "no Solana account, no address page"
        )
    }

    func testStaleChainAndFilterResponsesAreDiscarded() throws {
        let (interactor, remote, output) = try fixture()
        interactor.chainAssetChanged(ChainAsset(chain: try chain(id: "196", explorer: "https://www.oklink.com/x-layer/{type}/{value}"), asset: asset))
        remote.complete(0, .failure(HistoryFixtureError.unavailable))
        XCTAssertEqual(output.failures, 0)
        interactor.applyFilters([])
        remote.complete(1, .success(page("old-filter")))
        XCTAssertTrue(output.pages.isEmpty)
        remote.complete(2, .success(page("current")))
        XCTAssertEqual(output.pages.last?.0.transactions.first?.transactionId, "current")
        XCTAssertTrue(interactor.historyExplorerURL()?.absoluteString.contains("/xlayer/address/") == true)
    }

    func testExplorerURLUsesExactCurrentKaiaXLayerAndBNBAddress() throws {
        for (id, explorer) in [("8217", "https://kaiascan.io/{type}/{value}"), ("196", "https://www.oklink.com/xlayer/{type}/{value}"), ("56", "https://bscscan.com/{type}/{value}")] {
            let (interactor, _, _) = try fixture(chain: chain(id: id, explorer: explorer))
            let expected = explorer.replacingOccurrences(of: "{type}", with: "address").replacingOccurrences(of: "{value}", with: "0x" + String(repeating: "11", count: 20))
            XCTAssertEqual(interactor.historyExplorerURL()?.absoluteString.lowercased(), expected.lowercased())
        }
    }

    func testReleasedXLayerMainnetTestExplorerIsCorrectedWithoutReplacingCustomExplorer() throws {
        let (interactor, _, _) = try fixture(chain: chain(id: "196", explorer: "https://www.okx.com/explorer/xlayer-test/{type}/{value}"))
        XCTAssertEqual(interactor.historyExplorerURL()?.absoluteString.lowercased(), "https://www.oklink.com/xlayer/address/0x" + String(repeating: "11", count: 20))
        let (custom, _, _) = try fixture(chain: chain(id: "196", explorer: "https://custom.example/{type}/{value}"))
        XCTAssertEqual(custom.historyExplorerURL()?.host, "custom.example")
        let (providerCustom, _, _) = try fixture(chain: chain(id: "196", explorer: "https://www.oklink.com/custom-route/{type}/{value}"))
        XCTAssertTrue(providerCustom.historyExplorerURL()?.path.hasPrefix("/custom-route/address/") == true)
    }

    func testNoExplorerButtonForMissingAccountOrUnsafeExplorerURL() throws {
        for explorer in ["http://unsafe.example/{type}/{value}", "javascript:alert('{value}')", "https://user:password@example.org/{value}"] {
            let (interactor, _, _) = try fixture(chain: chain(explorer: explorer))
            XCTAssertNil(interactor.historyExplorerURL())
        }
        let missingWallet = wallet(byte: 0x11, hasEthereum: false)
        let (interactor, remote, output) = try fixture(wallet: missingWallet)
        XCTAssertNil(interactor.historyExplorerURL())
        XCTAssertTrue(remote.calls.isEmpty)
        XCTAssertEqual(output.failures, 1)
    }

    func testTonOnlyLegacyHistoryUsesOriginalNativeAddressWithoutSubstrateRoot() throws {
        let publicKey = Data(repeating: 0x11, count: 32)
        let account = try LegacyTonAccount(serializedAddress: JSONEncoder().encode(WalletV4R2(publicKey: publicKey).address()), publicKey: publicKey, contractVersion: "v4R2")
        var nativeWallet = wallet(byte: 0x11, hasEthereum: false)
        nativeWallet.legacyTonAccount = account
        let (interactor, remote, _) = try fixture(chain: chain(id: "-239", explorer: "https://tonviewer.com/{value}", ethereum: false), wallet: nativeWallet)
        XCTAssertEqual(remote.calls.first?.address, account.address)
        XCTAssertEqual(interactor.historyExplorerURL()?.lastPathComponent, account.address)
    }

    func testPresenterStopsSpinnerPreservesRowsAndOnlyOpensExplorerOnTap() throws {
        let input = HistoryInputSpy()
        let wireframe = HistoryWireframeSpy()
        let view = HistoryViewSpy()
        let presenter = makePresenter(input: input, wireframe: wireframe)
        presenter.setup(with: view)
        presenter.didReceive(pageData: page("cached"), reload: true)
        presenter.didReceiveHistoryFailure(hasCachedHistory: true)
        XCTAssertEqual(view.stops, 2)
        XCTAssertEqual(view.failures, [true])
        guard case .reloaded = view.states.last else { return XCTFail("Loaded rows must stay visible") }
        XCTAssertEqual(presenter.viewModels.first?.items.first?.transaction.transactionId, "cached")
        XCTAssertTrue(wireframe.opened.isEmpty)
        XCTAssertFalse(presenter.loadNext())
        presenter.retryHistory()
        XCTAssertEqual(input.reloads, 1)
        XCTAssertEqual(view.starts, 1)
        input.url = URL(string: "https://kaiascan.io/address/current-wallet")
        presenter.viewHistoryOnExplorer()
        XCTAssertEqual(wireframe.opened, [input.url!])
        presenter.didReceiveHistoryFailure(hasCachedHistory: true)
        XCTAssertEqual(presenter.viewModels.first?.items.first?.transaction.transactionId, "cached")
    }

    func testUnsupportedHistoryUsesRecoveryAndWalletResetClearsOldRows() throws {
        let input = HistoryInputSpy()
        input.url = nil
        let view = HistoryViewSpy()
        let presenter = makePresenter(input: input, wireframe: HistoryWireframeSpy())
        presenter.setup(with: view)
        presenter.didReceive(pageData: page("old"), reload: true)
        presenter.didReceiveUnsupported()
        XCTAssertEqual(view.failures, [false])
        XCTAssertEqual(view.stops, 2)
        guard case .unsupported = view.states.last else { return XCTFail("Unsupported networks must say so") }
        XCTAssertFalse(presenter.loadNext())
        presenter.didResetHistory()
        XCTAssertTrue(presenter.viewModels.isEmpty)
        guard case .loading = view.states.last else { return XCTFail("Old wallet rows must be reset") }
    }

    func testRecoveryNoticeFits320PointsKeepsRowsAndOffersAccessibleActions() throws {
        let input = HistoryInputSpy()
        let wireframe = HistoryWireframeSpy()
        let presenter = makePresenter(input: input, wireframe: wireframe)
        let controller = WalletTransactionHistoryViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        controller.rootView.setHeaderHeight(60)
        presenter.didReceive(pageData: page("cached"), reload: true)
        controller.didStartLoading()
        presenter.didReceiveHistoryFailure(hasCachedHistory: true)
        controller.view.layoutIfNeeded()
        XCTAssertFalse(controller.rootView.recoveryView.isHidden)
        XCTAssertEqual(controller.numberOfSections(in: controller.rootView.tableView), 1)
        XCTAssertEqual(controller.tableView(controller.rootView.tableView, numberOfRowsInSection: 0), 1)
        XCTAssertTrue(controller.view.isUserInteractionEnabled)
        XCTAssertFalse(controller.view.subviews.contains { $0.accessibilityIdentifier == LoadableViewProtocolConstants.activityIndicatorIdentifier })
        for button in [controller.rootView.retryButton, controller.rootView.explorerButton] {
            XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
            XCTAssertGreaterThan(button.bounds.width, 0)
            XCTAssertFalse(button.hasAmbiguousLayout)
        }
        XCTAssertLessThanOrEqual(controller.rootView.recoveryView.frame.maxX, 320)
        controller.rootView.explorerButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(wireframe.opened.count, 1)
        controller.rootView.retryButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(input.reloads, 1)
        presenter.didReceive(pageData: page("recovered"), reload: true)
        XCTAssertTrue(controller.rootView.recoveryView.isHidden)
    }

    func testUnsupportedHistoryOpensExplorerAndAnotherNetworksFailureStillOffersRetry() throws {
        let input = HistoryInputSpy()
        input.url = URL(string: "https://explorer.example/address/test-wallet")
        let wireframe = HistoryWireframeSpy()
        let presenter = makePresenter(input: input, wireframe: wireframe)
        let controller = WalletTransactionHistoryViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        presenter.didReceiveUnsupported()
        controller.view.layoutIfNeeded()
        XCTAssertFalse(controller.rootView.recoveryView.isHidden)
        XCTAssertTrue(controller.rootView.retryButton.isHidden, "Solana has no history provider to retry")
        XCTAssertFalse(controller.rootView.explorerButton.isHidden)
        XCTAssertGreaterThanOrEqual(controller.rootView.explorerButton.bounds.height, 44)
        controller.rootView.explorerButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(wireframe.opened, [try XCTUnwrap(input.url)])
        XCTAssertEqual(input.reloads, 0)

        // The same sheet is reused after switching networks. A provider failure must
        // restore Retry even when the previous network could only open its explorer.
        presenter.didResetHistory()
        input.url = nil
        presenter.didReceiveHistoryFailure(hasCachedHistory: false)
        controller.view.layoutIfNeeded()
        XCTAssertFalse(controller.rootView.retryButton.isHidden)
        XCTAssertTrue(controller.rootView.explorerButton.isHidden)
        XCTAssertGreaterThanOrEqual(controller.rootView.retryButton.bounds.height, 44)
        controller.rootView.retryButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(input.reloads, 1)
    }

    /// Solana's indexer may be missing (404), serve another cluster or have nothing for the
    /// wallet. The screen never ends in an empty list or "not supported": it offers Solscan.
    func testSolanaHistoryWithoutRows_offersSolscanInsteadOfAnEmptyListOrNotSupported() throws {
        let input = HistoryInputSpy()
        input.url = URL(string: "https://solscan.io/account/HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk")
        let wireframe = HistoryWireframeSpy()
        let presenter = makeSolanaPresenter(input: input, wireframe: wireframe)
        let controller = WalletTransactionHistoryViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let locale = LocalizationManager.shared.selectedLocale
        let explorerMessage = WalletTransactionHistoryViewLayout.explorerOnlyMessage(locale: locale)
        let unsupported = R.string.localizable.walletTransactionHistoryUnsupportedMessage(preferredLanguages: locale.rLanguages)

        for deliver in [
            { presenter.didReceive(pageData: AssetTransactionPageData(transactions: []), reload: true) },
            { presenter.didReceiveUnsupported() },
            { presenter.didReceiveHistoryFailure(hasCachedHistory: false) }
        ] {
            controller.didReceive(state: .loading)
            deliver()
            controller.view.layoutIfNeeded()
            XCTAssertFalse(controller.rootView.recoveryView.isHidden)
            XCTAssertEqual(controller.rootView.recoveryLabel.text, explorerMessage)
            XCTAssertNotEqual(controller.rootView.recoveryLabel.text, unsupported)
            XCTAssertTrue(controller.rootView.recoveryLabel.text?.contains("Solscan") == true)
            XCTAssertFalse(controller.rootView.explorerButton.isHidden)
            XCTAssertTrue(controller.rootView.retryButton.isHidden, "Retrying the indexer gives the same answer")
            XCTAssertGreaterThanOrEqual(controller.rootView.explorerButton.bounds.height, 44)
        }

        controller.rootView.explorerButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(wireframe.opened, [try XCTUnwrap(input.url)])
        XCTAssertEqual(input.reloads, 0)

        // Without an address page the notice still says where the history is, and Retry stays.
        input.url = nil
        presenter.didReceive(pageData: AssetTransactionPageData(transactions: []), reload: true)
        XCTAssertTrue(controller.rootView.explorerButton.isHidden)
        XCTAssertFalse(controller.rootView.retryButton.isHidden)
    }

    func testSolanaHistoryWithVerifiedRows_showsThemWithoutTheExplorerNotice() throws {
        let view = HistoryViewSpy()
        let presenter = makeSolanaPresenter(input: HistoryInputSpy(), wireframe: HistoryWireframeSpy())
        presenter.setup(with: view)

        presenter.didReceive(pageData: page("solana-transfer"), reload: true)

        guard case .reloaded = view.states.last else { return XCTFail("Indexer rows for this cluster are shown") }
        XCTAssertTrue(view.failures.isEmpty)
        XCTAssertEqual(presenter.viewModels.first?.items.first?.transaction.transactionId, "solana-transfer")

        // A later empty page that only appends keeps the rows.
        presenter.didReceive(pageData: AssetTransactionPageData(transactions: []), reload: false)
        guard case .loaded = view.states.last else { return XCTFail("Loaded rows stay") }
        XCTAssertTrue(view.failures.isEmpty)
    }

    func testSolanaHistory_whenTheIndexerHasNothing_thenTheInteractorAndPresenterOfferSolscan() throws {
        let phrase = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let wallet = try UniversalWalletAccountProvisioning.addingSolanaMainnetAccount(to: wallet(byte: 0x11), mnemonic: phrase)
        let solana = try SolanaKeyDerivation.deriveAccount(mnemonic: phrase)
        let remote = HistoryRecoveryRemote()
        let view = HistoryViewSpy()
        let wireframe = HistoryWireframeSpy()
        let chain = UniversalWalletRegistry.solanaMainnetChainModel
        let interactor = makeInteractor(chain: chain, wallet: wallet, dependencies: HistoryDependencies(remote: remote))
        let presenter = WalletTransactionHistoryPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: HistoryViewModelFactory(),
            chainAsset: ChainAsset(chain: chain, asset: try XCTUnwrap(chain.assets.first)),
            logger: Logger.shared,
            localizationManager: LocalizationManager.shared
        )
        presenter.setup(with: view)
        XCTAssertEqual(remote.calls.first?.address, solana.address)

        // SolanaHistoryOperationFactory answers an empty page for a 404, another cluster or an outage.
        remote.complete(0, .success(AssetTransactionPageData(transactions: [])))

        guard case .explorerOnly = view.states.last else { return XCTFail("No rows: the explorer is offered") }
        XCTAssertEqual(view.failures, [true])
        presenter.viewHistoryOnExplorer()
        XCTAssertEqual(wireframe.opened.map(\.absoluteString), ["https://solscan.io/account/\(solana.address)"])
    }

    func testFailureWithoutCachedHistoryShowsUnavailableBeforeRecoveryActions() throws {
        let input = HistoryInputSpy()
        let view = HistoryViewSpy()
        let presenter = makePresenter(input: input, wireframe: HistoryWireframeSpy())
        presenter.setup(with: view)
        presenter.didReceiveHistoryFailure(hasCachedHistory: false)
        XCTAssertEqual(view.stops, 1)
        XCTAssertEqual(view.failures, [true])
        // Unavailable must arrive first: a later state change hides the recovery notice.
        XCTAssertEqual(view.events, ["state:unavailable", "failure"])
        XCTAssertFalse(presenter.loadNext())
        presenter.retryHistory()
        XCTAssertEqual(input.reloads, 1)
    }

    func testHistoryRouting_everyFormerOklinkCatalogChain() throws {
        let storage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> = SubstrateDataStorageFacade.shared.createRepository()
        let alchemy = String(describing: AlchemyHistoryOperationFactory.self)
        let routescan = String(describing: EtherscanHistoryOperationFactory.self)
        let oklink = String(describing: OklinkHistoryOperationFactory.self)
        let expected = [
            "1": alchemy, "56": alchemy, "137": alchemy, "42161": alchemy, "10": alchemy,
            "43114": routescan,
            // Polygon zkEVM was retired; X Layer and Kaia have no replacement indexer credentials yet.
            "1101": oklink, "196": oklink, "8217": oklink
        ]
        let oklinkRoutes = try Self.registryChains().filter {
            ["www.oklink.com", "oklink.com"].contains($0.externalApi?.history?.url.host?.lowercased() ?? "")
        }
        XCTAssertEqual(Set(oklinkRoutes.map(\.chainId)), Set(expected.keys))
        for chain in oklinkRoutes {
            let factory = try XCTUnwrap(HistoryOperationFactoriesAssembly.createOperationFactory(
                chain: chain,
                txStorage: AnyDataProviderRepository(storage)
            ), chain.chainId)
            XCTAssertEqual(String(describing: type(of: factory)), expected[chain.chainId], chain.chainId)
        }
    }

    func testFormerOklinkRoutesWithoutIndexerShowFailureAndExplorerInsteadOfEmptyHistory() throws {
        let address = "0x" + String(repeating: "11", count: 20)
        let explorers = [
            "56": "https://www.okx.com/web3/explorer/bsc/address/\(address)?channelID=flessw",
            "8217": "https://www.okx.com/web3/explorer/kaia/address/\(address)?channelID=flessw",
            // The released registry points mainnet 196 at xlayer-test; only that route is corrected.
            "196": "https://www.oklink.com/xlayer/address/\(address)"
        ]
        for (chainId, explorer) in explorers {
            let chain = try XCTUnwrap(Self.registryChains().first { $0.chainId == chainId })
            let remote = HistoryRecoveryRemote()
            let view = HistoryViewSpy()
            let interactor = makeInteractor(chain: chain, wallet: wallet(byte: 0x11), dependencies: HistoryDependencies(remote: remote))
            let presenter = WalletTransactionHistoryPresenter(
                interactor: interactor,
                wireframe: HistoryWireframeSpy(),
                viewModelFactory: HistoryViewModelFactory(),
                chainAsset: ChainAsset(chain: chain, asset: asset),
                logger: Logger.shared,
                localizationManager: LocalizationManager.shared
            )
            presenter.setup(with: view)
            XCTAssertEqual(remote.calls.first?.address.lowercased(), address, chainId)
            remote.complete(0, .failure(HistoryFixtureError.unavailable))

            XCTAssertEqual(view.failures, [true], chainId)
            XCTAssertEqual(view.events.suffix(2), ["state:unavailable", "failure"], chainId)
            XCTAssertFalse(view.states.contains { if case .loaded = $0 { return true } else { return false } }, chainId)
            XCTAssertEqual(interactor.historyExplorerURL()?.absoluteString.lowercased(), explorer.lowercased(), chainId)
        }
    }

    private func fixture(chain: ChainModel? = nil, wallet: MetaAccountModel? = nil, dependencies: HistoryDependencies? = nil) throws -> (WalletTransactionHistoryInteractor, HistoryRecoveryRemote, HistoryOutputSpy) {
        let remote = dependencies?.remote ?? HistoryRecoveryRemote()
        let output = HistoryOutputSpy()
        let interactor = makeInteractor(
            chain: try chain ?? self.chain(),
            wallet: wallet ?? self.wallet(byte: 0x11),
            dependencies: dependencies ?? HistoryDependencies(remote: remote)
        )
        interactor.setup(with: output)
        return (interactor, remote, output)
    }

    private func makeInteractor(chain: ChainModel, wallet: MetaAccountModel, dependencies: HistoryDependencies) -> WalletTransactionHistoryInteractor {
        let interactor = WalletTransactionHistoryInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: wallet,
            dependencyContainer: dependencies,
            logger: nil,
            defaultFilter: WalletHistoryRequest(assets: [asset.id]),
            selectedFilter: WalletHistoryRequest(assets: [asset.id]),
            transactionsPerPage: 10,
            filters: [],
            eventCenter: EventCenter(),
            applicationHandler: ApplicationHandler()
        )
        addTeardownBlock { interactor.didReceiveDidEnterBackground(notification: Notification(name: UIApplication.didEnterBackgroundNotification)) }
        return interactor
    }

    private static var cachedRegistryChains: [ChainModel]?

    /// The byte copy of the release registry (`Registry/chains_v13_20261009.json`, see its README).
    private static func registryChains() throws -> [ChainModel] {
        if let cachedRegistryChains { return cachedRegistryChains }
        let url = try XCTUnwrap(Bundle(for: WalletTransactionHistoryTests.self).url(
            forResource: "chains_v13_20261009", withExtension: "json", subdirectory: "Registry"
        ))
        let data = try Data(contentsOf: url)
        let chains: [ChainModel]
        if let decoded = try? JSONDecoder().decode([ChainModel].self, from: data) {
            chains = decoded
        } else {
            chains = try JSONDecoder().decode([ChainModel].self, from: ChainSyncService.coerceChainsPayloadForCompatibility(data))
        }
        cachedRegistryChains = chains
        return chains
    }

    private func chain(id: String = "1", explorer: String = "https://etherscan.io/{type}/{value}", ethereum: Bool = true) throws -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: id,
            paraId: nil,
            name: "Synthetic network",
            assets: [asset],
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            icon: nil,
            options: ethereum ? [.ethereum] : nil,
            externalApi: .init(
                history: ChainModel.BlockExplorer(type: "etherscan", url: URL(string: "https://history.example")!),
                explorers: [.init(type: .etherscan, types: [.address], url: explorer)]
            ),
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func wallet(byte: UInt8, hasEthereum: Bool = true) -> MetaAccountModel {
        MetaAccountModel(
            metaId: "wallet-\(byte)",
            name: "Synthetic wallet",
            substrateAccountId: nil,
            substrateCryptoType: 0,
            substratePublicKey: nil,
            ethereumAddress: hasEthereum ? Data(repeating: byte, count: 20) : nil,
            ethereumPublicKey: hasEthereum ? Data(repeating: byte, count: 33) : nil,
            chainAccounts: [],
            assetKeysOrder: nil,
            canExportEthereumMnemonic: false,
            unusedChainIds: nil,
            selectedCurrency: .defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: true,
            favouriteChainIds: []
        )
    }

    private func page(_ id: String, context: PaginationContext? = nil) -> AssetTransactionPageData {
        AssetTransactionPageData(transactions: [AssetTransactionData(
            transactionId: id,
            status: .commited,
            assetId: asset.id,
            peerId: "peer",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: nil,
            details: "",
            amount: AmountDecimal(value: 1),
            fees: [],
            timestamp: 100,
            type: TransactionType.outgoing.rawValue,
            reason: "",
            context: nil
        )], context: context)
    }

    private func makeSolanaPresenter(input: HistoryInputSpy, wireframe: HistoryWireframeSpy) -> WalletTransactionHistoryPresenter {
        let chain = UniversalWalletRegistry.solanaMainnetChainModel
        return WalletTransactionHistoryPresenter(
            interactor: input,
            wireframe: wireframe,
            viewModelFactory: HistoryViewModelFactory(),
            chainAsset: ChainAsset(chain: chain, asset: chain.assets.first!),
            logger: Logger.shared,
            localizationManager: LocalizationManager.shared
        )
    }

    private func makePresenter(input: HistoryInputSpy, wireframe: HistoryWireframeSpy) -> WalletTransactionHistoryPresenter {
        WalletTransactionHistoryPresenter(
            interactor: input,
            wireframe: wireframe,
            viewModelFactory: HistoryViewModelFactory(),
            chainAsset: ChainAsset(chain: try! chain(), asset: asset),
            logger: Logger.shared,
            localizationManager: LocalizationManager.shared
        )
    }
}

private enum HistoryFixtureError: Error { case unavailable }

private final class HistoryRecoveryRemote: HistoryServiceProtocol {
    struct Call { let address: String; let chainId: String; let pagination: Pagination; let completion: TransactionHistoryBlock }
    var calls: [Call] = []
    func fetchTransactionHistory(for address: String, asset _: AssetModel, chain: ChainModel, filters _: [WalletTransactionHistoryFilter], pagination: Pagination, runCompletionIn _: DispatchQueue, completionBlock: @escaping TransactionHistoryBlock) -> CancellableCall {
        calls.append(Call(address: address, chainId: chain.chainId, pagination: pagination, completion: completionBlock))
        return HistoryCancellable()
    }

    func complete(_ index: Int, _ result: Result<AssetTransactionPageData?, Error>?) { calls[index].completion(result) }
}

private final class HistoryCancellable: CancellableCall { func cancel() {} }
private final class HistoryDependencies: WalletTransactionHistoryDependencyContaining {
    let remote: HistoryRecoveryRemote
    var shouldFail = false
    var creationCount = 0
    var dependencies: WalletTransactionHistoryDependencyContainer.WalletTransactionHistoryDependencies?
    init(remote: HistoryRecoveryRemote) { self.remote = remote }
    func createDependencies(for _: ChainAsset, selectedAccount _: MetaAccountModel) throws {
        creationCount += 1
        if shouldFail { throw HistoryFixtureError.unavailable }
        dependencies = .init(dataProvider: nil, historyService: remote)
    }
}

private final class HistoryOutputSpy: WalletTransactionHistoryInteractorOutputProtocol {
    var pages: [(AssetTransactionPageData, Bool)] = []
    var failures = 0
    var cachedHistoryOnFailure: [Bool] = []
    var resets = 0
    func didReceive(pageData: AssetTransactionPageData, reload: Bool) { pages.append((pageData, reload)) }
    func didReceive(filters _: [FilterSet]) {}
    func didReceiveUnsupported() { failures += 1 }
    func didReceiveHistoryFailure(hasCachedHistory: Bool) {
        failures += 1
        cachedHistoryOnFailure.append(hasCachedHistory)
    }

    func didResetHistory() { resets += 1 }
}

private final class HistoryInputSpy: WalletTransactionHistoryInteractorInputProtocol {
    var reloads = 0
    var url = URL(string: "https://etherscan.io/address/current-wallet")
    func setup(with _: WalletTransactionHistoryInteractorOutputProtocol?) {}
    func loadNext() -> Bool { true }
    func applyFilters(_: [FilterSet]) {}
    func reload() { reloads += 1 }
    func chainAssetChanged(_: ChainAsset) {}
    func historyExplorerURL() -> URL? { url }
}

private final class HistoryWireframeSpy: WalletTransactionHistoryWireframeProtocol {
    var opened: [URL] = []
    func showHistoryExplorer(url: URL, from _: ControllerBackedProtocol) { opened.append(url) }
    func showTransactionDetails(from _: ControllerBackedProtocol?, transaction _: AssetTransactionData, chain _: ChainModel, asset _: AssetModel, selectedAccount _: MetaAccountModel) {}
}

private struct HistoryViewModelFactory: WalletTransactionHistoryViewModelFactoryProtocol {
    func merge(newItems: [AssetTransactionData], into existingViewModels: inout [WalletTransactionHistorySection], locale _: Locale) throws -> [SectionedListDifference<WalletTransactionHistorySection, WalletTransactionHistoryCellViewModel>] {
        let items = newItems.map { WalletTransactionHistoryCellViewModel(transaction: $0, address: "peer", icon: nil, transactionType: "Transfer", amountString: "1 ETH", timeString: "12:00", statusIcon: nil, status: .commited, incoming: false, imageViewModel: nil) }
        existingViewModels.append(WalletTransactionHistorySection(title: "Today", items: items))
        return []
    }
}

private final class HistoryViewSpy: UIViewController, WalletTransactionHistoryViewProtocol {
    var starts = 0
    var stops = 0
    var states: [WalletTransactionHistoryViewState] = []
    var failures: [Bool] = []
    var events: [String] = []
    var delegate: DraggableDelegate?
    var draggableView: UIView { view }
    var scrollPanRecognizer: UIPanGestureRecognizer? { nil }
    func didStartLoading() { starts += 1 }
    func didStopLoading() { stops += 1 }
    func didReceive(state: WalletTransactionHistoryViewState) {
        states.append(state)
        if case .unavailable = state { events.append("state:unavailable") } else { events.append("state") }
    }

    func reloadContent() {}
    func didReceiveHistoryFailure(canViewExplorer: Bool) {
        failures.append(canViewExplorer)
        events.append("failure")
    }

    func set(dragableState _: DraggableState, animated _: Bool) {}
    func set(contentInsets _: UIEdgeInsets, for _: DraggableState) {}
    func canDrag(from _: DraggableState) -> Bool { false }
    func animate(progress _: Double, from _: DraggableState, to _: DraggableState, finalFrame _: CGRect) {}
}
