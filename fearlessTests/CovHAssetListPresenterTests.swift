import XCTest
import SoraFoundation
import SSFModels
@testable import fearless

final class CovHAssetListArrivalSpy: FWArrivalAnnouncing {
    private(set) var symbols: [String] = []
    func announce(symbol: String, locale _: Locale) { symbols.append(symbol) }
}

final class CovHAssetListPresenterContext {
    let wallet: MetaAccountModel
    let interactor = CovHAssetListInteractorSpy()
    let router = CovHAssetListRouterSpy()
    let view = CovHAssetListViewSpy()
    let arrivals = CovHAssetListArrivalSpy()
    let presenter: ChainAssetListPresenter
    let languages = Locale(identifier: "en").rLanguages

    init(wallet: MetaAccountModel = AccountGenerator.generateMetaAccount()) throws {
        self.wallet = wallet
        presenter = ChainAssetListPresenter(
            interactor: interactor,
            router: router,
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en")),
            wallet: wallet,
            viewModelFactory: ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory()),
            arrivalAnnouncer: arrivals
        )
        presenter.didLoad(view: view)
    }

    static func cell(for chainAsset: ChainAsset, options: [ChainOptionsViewModel]? = nil, balance: String = "1") -> ChainAccountBalanceCellViewModel {
        ChainAccountBalanceCellViewModel(
            assetContainsChainAssets: [chainAsset],
            chainIconViewViewModel: ChainCollectionViewModel(maxImagesCount: 5, chainImages: []),
            chainAsset: chainAsset,
            metadataTrust: AssetMetadataTrustInfo(trust: .verified, provenance: .registry),
            assetName: chainAsset.asset.name,
            assetInfo: nil,
            imageViewModel: nil,
            balanceString: .normal(balance),
            priceAttributedString: .normalAttributed(nil),
            totalAmountString: .normal("$" + balance),
            options: options,
            isColdBoot: false,
            locale: Locale(identifier: "en"),
            hideButtonIsVisible: true,
            swipeActionsEnabled: true,
            transferableString: nil
        )
    }

    static func bitcoinChain() -> ChainModel {
        CovHAssetListFixture.chain(id: UniversalWalletRegistry.bitcoinMainnet.chainId, name: "Bitcoin")
    }
}

final class CovHAssetListPresenterTests: XCTestCase {
    func testMissingAccountSheetOffersCreateImportAndSkip() throws {
        let context = try CovHAssetListPresenterContext()
        let chain = CovHAssetListFixture.chain(name: "Account-less network")

        context.presenter.didTapResolveAccountIssue(for: chain)

        let actions = try XCTUnwrap(context.router.accountOptions.last)
        XCTAssertEqual(actions.map(\.title), [
            R.string.localizable.createNewAccount(preferredLanguages: context.languages),
            R.string.localizable.alreadyHaveAccount(preferredLanguages: context.languages),
            R.string.localizable.missingAccountSkip(preferredLanguages: context.languages)
        ])
        actions.forEach { $0.handler?() }
        XCTAssertEqual(context.router.calls, ["create", "import"])
        XCTAssertEqual(context.router.chainModels.map(\.chain.chainId), [chain.chainId, chain.chainId])
        XCTAssertEqual(context.interactor.unused, [chain.chainId])
    }

    func testSkippedNetworkIsNotOfferedTheSkipAgain() throws {
        let chain = CovHAssetListFixture.chain(name: "Skipped network")
        let wallet = AccountGenerator.generateMetaAccount().replacingUnusedChainIds([chain.chainId])
        let context = try CovHAssetListPresenterContext(wallet: wallet)

        context.presenter.didTapResolveAccountIssue(for: chain)

        XCTAssertEqual(context.router.accountOptions.last?.count, 2)
    }

    func testUniversalNetworkForAWalletWithoutRootLeadsToTheWalletList() throws {
        let context = try CovHAssetListPresenterContext(wallet: CovHAssetListFixture.evmOnlyWallet())

        context.presenter.didTapResolveAccountIssue(for: CovHAssetListPresenterContext.bitcoinChain())

        let sheet = try XCTUnwrap(context.router.sheets.last)
        XCTAssertEqual(sheet.title, R.string.localizable.universalUnsupportedTitle(preferredLanguages: context.languages))
        XCTAssertEqual(sheet.message, R.string.localizable.universalUnsupportedMessage(preferredLanguages: context.languages))
        sheet.actions.first?.handler?()
        XCTAssertTrue(context.router.calls.isEmpty, "The wallet list opens once the sheet is gone")
        sheet.dismissCompletion?()
        XCTAssertEqual(context.router.calls, ["wallets"])
    }

    func testSetupIsOfferedOnceWhileAdoptionRunsAndRecoveryImportsThePhrase() throws {
        let context = try CovHAssetListPresenterContext()
        let bitcoin = CovHAssetListPresenterContext.bitcoinChain()

        context.presenter.didTapResolveAccountIssue(for: bitcoin)
        let setup = try XCTUnwrap(context.router.sheets.last)
        XCTAssertEqual(setup.title, R.string.localizable.universalSetupTitle(preferredLanguages: context.languages))
        setup.actions.first?.handler?()
        setup.dismissCompletion?()
        XCTAssertEqual(context.interactor.calls, ["setup", "adopt"])

        context.presenter.didTapResolveAccountIssue(for: bitcoin)
        XCTAssertEqual(context.router.sheets.count, 1, "No second setup sheet while the first adoption runs")

        context.presenter.didAdoptStoredWalletSeed(result: .failure(UniversalWalletStoredSeedAdopter.AdoptionError.storedWalletSeedUnavailable))
        let recovery = try XCTUnwrap(context.router.sheets.last)
        XCTAssertEqual(recovery.title, R.string.localizable.universalRecoveryTitle(preferredLanguages: context.languages))
        XCTAssertEqual(recovery.actions.count, 2)
        recovery.actions.first?.handler?()
        recovery.dismissCompletion?()
        XCTAssertEqual(context.router.calls, ["import"])
        XCTAssertEqual(context.router.chainModels.last?.chain.chainId, bitcoin.chainId)
    }

    func testUnsupportedSecretAfterSetupExplainsAndLeadsToTheWalletList() throws {
        let context = try CovHAssetListPresenterContext()
        context.presenter.didTapResolveAccountIssue(for: CovHAssetListPresenterContext.bitcoinChain())
        let setup = try XCTUnwrap(context.router.sheets.last)
        setup.actions.first?.handler?()
        setup.dismissCompletion?()

        context.presenter.didAdoptStoredWalletSeed(result: .failure(UniversalWalletStoredSeedAdopter.AdoptionError.unsupportedSecretSource))

        let sheet = try XCTUnwrap(context.router.sheets.last)
        XCTAssertEqual(sheet.title, R.string.localizable.universalUnsupportedTitle(preferredLanguages: context.languages))
        XCTAssertEqual(sheet.message, R.string.localizable.universalUnsupportedSourceMessage(preferredLanguages: context.languages))
        XCTAssertTrue(context.router.errors.isEmpty)
    }

    func testAdoptionSuccessReplacesTheWalletAndRefreshesTheList() throws {
        let context = try CovHAssetListPresenterContext()
        context.presenter.didReceiveChainAssets(result: .success([CovHAssetListFixture.chainAsset()]))
        CovHAssetListFixture.drainMain()
        let models = context.view.models.count

        let renamed = context.wallet.replacingName("Adopted")
        context.presenter.didAdoptStoredWalletSeed(result: .success(renamed))
        CovHAssetListFixture.drainMain()

        XCTAssertEqual(context.view.models.count, models + 1)
        XCTAssertEqual(context.view.models.last?.walletId, context.wallet.metaId)
        XCTAssertTrue(context.router.errors.isEmpty)
    }

    func testSelectingARowOpensTheNetworkOrAsksForAnUpdate() throws {
        let context = try CovHAssetListPresenterContext()
        let supported = CovHAssetListFixture.chainAsset()
        let unsupported = CovHAssetListFixture.chainAsset(chain: CovHAssetListFixture.chain(minVersion: "999.0.0"))
        XCTAssertTrue(supported.chain.isSupported)
        XCTAssertFalse(unsupported.chain.isSupported)

        context.presenter.didSelectViewModel(CovHAssetListPresenterContext.cell(for: supported))
        XCTAssertEqual(context.router.calls, ["chainAccount"])
        XCTAssertEqual(context.router.assets, [supported.assetKey])

        context.presenter.didSelectViewModel(CovHAssetListPresenterContext.cell(for: unsupported))
        XCTAssertEqual(context.router.calls, ["chainAccount", "warning"])
        context.router.warningHandlers.first?()
        XCTAssertEqual(context.router.calls.last, "appstore")
    }

    func testSelectingAnAccountlessUniversalRowOffersSetup() throws {
        let context = try CovHAssetListPresenterContext()
        let bitcoin = CovHAssetListFixture.chainAsset(chain: CovHAssetListPresenterContext.bitcoinChain(), id: "btc", symbol: "BTC")

        context.presenter.didSelectViewModel(CovHAssetListPresenterContext.cell(for: bitcoin))
        XCTAssertEqual(context.router.sheets.count, 1)
        XCTAssertTrue(context.router.calls.isEmpty)

        context.presenter.didTapAction(actionType: .send, viewModel: CovHAssetListPresenterContext.cell(for: bitcoin))
        XCTAssertTrue(context.router.calls.isEmpty, "Sending needs the account first")
    }

    func testSwipeActionsRouteOrChangeVisibility() throws {
        let context = try CovHAssetListPresenterContext()
        let asset = CovHAssetListFixture.chainAsset()
        let cell = CovHAssetListPresenterContext.cell(for: asset)

        context.presenter.didTapAction(actionType: .send, viewModel: cell)
        context.presenter.didTapAction(actionType: .receive, viewModel: cell)
        context.presenter.didTapAction(actionType: .hide, viewModel: cell)
        context.presenter.didTapAction(actionType: .show, viewModel: cell)
        context.presenter.didTapAction(actionType: .teleport, viewModel: cell)

        XCTAssertEqual(context.router.calls, ["send", "receive"])
        XCTAssertEqual(context.interactor.hidden, [asset.assetKey])
        XCTAssertEqual(context.interactor.shown, [asset.assetKey])
    }

    func testListButtonsReachTheInteractorAndManageAssets() throws {
        let context = try CovHAssetListPresenterContext()
        let chain = CovHAssetListFixture.chain()

        context.presenter.didPullToRefresh()
        context.presenter.didTapManageAsset()
        context.presenter.didFinishManageAssetAnimate()
        context.presenter.didTapResolveNetworkIssue(for: chain)
        context.presenter.didTapCloseBanners()
        context.presenter.reloadBannersView()
        CovHAssetListFixture.drainMain()

        XCTAssertEqual(context.interactor.calls, ["setup", "reload"])
        XCTAssertEqual(context.router.calls, ["manage"])
        XCTAssertEqual(context.router.manageFilters, [.all])
        XCTAssertFalse(context.interactor.shouldRunManageAssetAnimate)
        XCTAssertEqual(context.interactor.retried, [chain.chainId])
        XCTAssertEqual(context.view.bannerReloads, 1)
    }

    func testSingleNetworkTokenRowActsOnItsOnlyAsset() throws {
        let context = try CovHAssetListPresenterContext()
        let asset = CovHAssetListFixture.chainAsset(id: "single-\(UUID().uuidString)", symbol: "SGL")
        context.presenter.didReceiveChainAssets(result: .success([asset]))
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 5000)), for: asset)
        CovHAssetListFixture.drainMain()

        let row = try XCTUnwrap(context.view.models.last?.tokenRows.first { $0.model.isSingleNetwork })
        context.presenter.didTapTokenAction(actionType: .receive, groupId: row.model.id, walletId: context.wallet.metaId)
        context.presenter.didTapTokenAction(actionType: .send, groupId: row.model.id, walletId: context.wallet.metaId)

        XCTAssertEqual(context.router.calls, ["receive", "send"])
        XCTAssertEqual(context.router.assets, [asset.assetKey, asset.assetKey])
        XCTAssertEqual(context.arrivals.symbols, [], "A first balance is no arrival")
    }

    func testWalletIssuesSettingsAndBalancesRefreshTheList() throws {
        let context = try CovHAssetListPresenterContext()
        let asset = CovHAssetListFixture.chainAsset()
        context.presenter.didReceiveChainAssets(result: .success([asset]))
        CovHAssetListFixture.drainMain()
        var models = context.view.models.count
        let refreshes: [() -> Void] = [
            { context.presenter.updateViewModel(isInitSearchState: true) },
            { context.presenter.didReceiveWallet(wallet: context.wallet.replacingName("Same wallet")) },
            { context.presenter.didReceiveChainsWithIssues([]) },
            { context.presenter.didReceiveChainsWithIssues([.network(chains: [asset.chain])]) },
            { context.presenter.didReceive(chainSettings: []) },
            { context.presenter.didReceive(accountInfosByChainAssets: [asset: AccountInfo(ethBalance: 9)]) }
        ]
        for refresh in refreshes {
            refresh()
            CovHAssetListFixture.drainMain()
            XCTAssertEqual(context.view.models.count, models + 1)
            models = context.view.models.count
        }

        context.presenter.didReceiveWallet(wallet: AccountGenerator.generateMetaAccount())
        CovHAssetListFixture.drainMain()
        XCTAssertEqual(context.view.models.count, models, "Another wallet's model is ignored")
    }

    func testNetworkAndSearchFiltersOnlyChangeThePresentation() throws {
        let context = try CovHAssetListPresenterContext()
        let asset = CovHAssetListFixture.chainAsset()
        context.presenter.didReceiveChainAssets(result: .success([asset]))
        CovHAssetListFixture.drainMain()

        context.presenter.updateChainAssets(using: [.search("COV")], sorts: [], networkFilter: .all)
        context.presenter.updateViewModel(isInitSearchState: false)
        CovHAssetListFixture.drainMain()
        XCTAssertEqual(context.view.models.last?.displayState.isSearch, true)

        context.presenter.updateChainAssets(using: [], sorts: [], networkFilter: .chain(asset.chain.chainId))
        context.presenter.updateViewModel(isInitSearchState: false)
        CovHAssetListFixture.drainMain()
        // One list (4f4220937): on the wallet home the search field is the list's own, so a network change keeps
        // its query; clearing the field shows the chosen network.
        XCTAssertEqual(context.view.models.last?.displayState.isSearch, true)
        context.presenter.didSearch("", walletId: context.wallet.metaId)
        CovHAssetListFixture.drainMain()
        XCTAssertEqual(context.view.models.last?.displayState.isSearch, false)

        context.presenter.updateChainAssets(using: [], sorts: [], networkFilter: nil)
        XCTAssertEqual(context.interactor.catalogFilters.count, 3)
        XCTAssertTrue(context.interactor.catalogFilters.allSatisfy(\.isEmpty), "Every enabled network stays subscribed")
    }
}
