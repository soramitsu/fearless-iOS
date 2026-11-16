import XCTest
import UIKit
import SoraFoundation
import SSFModels
@testable import fearless

final class CovJSelAssetNetworksFactorySpy: AssetNetworksViewModelFactoryProtocol {
    struct Call {
        let chainAssets: [ChainAsset]
        let accountInfos: [ChainAssetKey: AccountInfo?]
        let filter: AssetNetworksFilter
        let sort: AssetNetworksSortType
        let issues: [ChainIssue]
        let settings: [ChainSettings]
    }

    private(set) var calls: [Call] = []
    var result: [AssetNetworksTableCellModel] = []

    func buildViewModels(
        chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        wallet _: MetaAccountModel,
        locale _: Locale,
        filter: AssetNetworksFilter,
        sort: AssetNetworksSortType,
        chainsWithIssue: [ChainIssue],
        chainSettings: [ChainSettings]
    ) -> [AssetNetworksTableCellModel] {
        calls.append(Call(chainAssets: chainAssets, accountInfos: accountInfos, filter: filter, sort: sort, issues: chainsWithIssue,
                          settings: chainSettings))
        return result
    }
}

final class CovJSelAssetNetworksViewSpy: AssetNetworksViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }
    var draggableView: UIView { controller.view }
    weak var delegate: DraggableDelegate?
    var scrollPanRecognizer: UIPanGestureRecognizer? { nil }
    private(set) var received: [[AssetNetworksTableCellModel]] = []

    func set(dragableState _: DraggableState, animated _: Bool) {}
    func set(contentInsets _: UIEdgeInsets, for _: DraggableState) {}
    func canDrag(from _: DraggableState) -> Bool { false }
    func animate(progress _: Double, from _: DraggableState, to _: DraggableState, finalFrame _: CGRect) {}

    func didReceive(viewModels: [AssetNetworksTableCellModel]) {
        received.append(viewModels)
    }
}

final class CovJSelAssetNetworksInteractorSpy: AssetNetworksInteractorInput {
    private(set) var outputs: [AssetNetworksInteractorOutput] = []

    func setup(with output: AssetNetworksInteractorOutput) {
        outputs.append(output)
    }
}

final class CovJSelAssetNetworksRouterSpy: AssetNetworksRouterInput {
    private(set) var details: [ChainAsset] = []
    private(set) var filters: [(title: String?, filters: [FilterSet], output: FiltersModuleOutput?)] = []
    private(set) var issues: [[ChainIssue]] = []

    func showDetails(from _: ControllerBackedProtocol?, chainAsset: ChainAsset) {
        details.append(chainAsset)
    }

    func showFilters(title: String?, filters: [FilterSet], moduleOutput: FiltersModuleOutput?, from _: ControllerBackedProtocol?) {
        self.filters.append((title, filters, moduleOutput))
    }

    func showIssueNotification(from _: ControllerBackedProtocol?, issues: [ChainIssue], wallet _: MetaAccountModel) {
        self.issues.append(issues)
    }
}

final class CovJSelAssetNetworksTests: XCTestCase {
    private let listUsage = NumberFormatterUsageCase.listCryptoWith(minimumFractionDigits: 0, maximumFractionDigits: 3)

    private func crypto(_ value: Decimal, _ chainAsset: ChainAsset, locale: Locale) -> String? {
        AssetBalanceFormatterFactory().createTokenFormatter(for: chainAsset.assetDisplayInfo, usageCase: listUsage).value(for: locale)
            .stringFromDecimal(value)
    }

    private func chainNames(_ models: [AssetNetworksTableCellModel]) -> [String?] {
        models.map(\.chainNameLabelText)
    }

    func testFactorySortsByFiatValueAndFormatsBalances() throws {
        let locale = CovJFixture.locale
        let wallet = CovJSelFixture.substrateWallet()
        let currency = wallet.selectedCurrency
        let alphaPrice = "covjsel-alpha-" + UUID().uuidString
        let betaPrice = "covjsel-beta-" + UUID().uuidString
        CovJSelFixture.registerPrice("2", priceId: alphaPrice, currency: currency)
        CovJSelFixture.registerPrice("10", priceId: betaPrice, currency: currency)
        let alpha = ChainAsset(chain: CovJSelFixture.chain(name: "Alpha", assets: []), asset: CovJSelFixture.asset("alpha", priceId: alphaPrice))
        let beta = ChainAsset(chain: CovJSelFixture.chain(name: "Beta", assets: []), asset: CovJSelFixture.asset("beta", priceId: betaPrice))
        let gamma = ChainAsset(chain: CovJSelFixture.chain(name: "Gamma", assets: []), asset: CovJSelFixture.asset("gamma"))
        let infos: [ChainAssetKey: AccountInfo?] = [
            try CovJSelFixture.key(alpha, wallet: wallet): CovJSelFixture.info(free: CovJSelFixture.units(5)),
            try CovJSelFixture.key(beta, wallet: wallet): CovJSelFixture.info(free: CovJSelFixture.units(3)),
            try CovJSelFixture.key(gamma, wallet: wallet): CovJSelFixture.info(free: CovJSelFixture.units(100))
        ]
        let factory = AssetNetworksViewModelFactory(balanceViewModelFactory: AssetBalanceFormatterFactory())

        let models = factory.buildViewModels(
            chainAssets: [gamma, alpha, beta],
            accountInfos: infos,
            wallet: wallet,
            locale: locale,
            filter: .allNetworks,
            sort: .fiat,
            chainsWithIssue: [],
            chainSettings: []
        )

        XCTAssertEqual(chainNames(models), ["Beta", "Alpha", "Gamma"])
        XCTAssertEqual(models[0].cryptoBalanceLabelText, crypto(3, beta, locale: locale))
        XCTAssertEqual(models[0].fiatBalanceLabelText, CovJSelFixture.fiat(30, currency: currency, locale: locale))
        XCTAssertEqual(models[1].fiatBalanceLabelText, CovJSelFixture.fiat(10, currency: currency, locale: locale))
        XCTAssertEqual(models[2].cryptoBalanceLabelText, crypto(100, gamma, locale: locale))
        XCTAssertEqual(models[2].fiatBalanceLabelText, CovJSelFixture.fiat(0, currency: currency, locale: locale))
        XCTAssertTrue(models.allSatisfy { !$0.hasIssues && $0.iconViewModel == nil })
        XCTAssertEqual(models[0].chainAsset, beta)
    }

    func testFactoryFiltersOwnedNetworksSortsByNameAndPopularityAndFlagsIssues() throws {
        let locale = CovJFixture.locale
        let wallet = CovJSelFixture.substrateWallet()
        let alphaChain = CovJSelFixture.chain(name: "Alpha", rank: 1, icon: UniversalWalletRegistry.bitcoinIconURL, assets: [])
        let betaChain = CovJSelFixture.chain(name: "Beta", rank: 9, assets: [])
        let gammaChain = CovJSelFixture.chain(name: "Gamma", rank: 5, assets: [])
        let emptyChain = CovJSelFixture.chain(name: "Empty", assets: [])
        let lockedChain = CovJSelFixture.chain(name: "Locked", assets: [])
        let ethereumChain = CovJSelFixture.chain(name: "Ethereum", options: [.ethereumBased], assets: [])
        let alpha = ChainAsset(chain: alphaChain, asset: CovJSelFixture.asset("alpha"))
        let beta = ChainAsset(chain: betaChain, asset: CovJSelFixture.asset("beta"))
        let gamma = ChainAsset(chain: gammaChain, asset: CovJSelFixture.asset("gamma"))
        let empty = ChainAsset(chain: emptyChain, asset: CovJSelFixture.asset("empty"))
        let locked = ChainAsset(chain: lockedChain, asset: CovJSelFixture.asset("locked"))
        let ethereum = ChainAsset(chain: ethereumChain, asset: CovJSelFixture.asset("eth"))
        let infos: [ChainAssetKey: AccountInfo?] = [
            try CovJSelFixture.key(alpha, wallet: wallet): CovJSelFixture.info(free: CovJSelFixture.units(1)),
            try CovJSelFixture.key(beta, wallet: wallet): CovJSelFixture.info(free: CovJSelFixture.units(2)),
            try CovJSelFixture.key(gamma, wallet: wallet): CovJSelFixture.info(free: CovJSelFixture.units(3)),
            try CovJSelFixture.key(locked, wallet: wallet): CovJSelFixture.info(free: CovJSelFixture.units(4), frozen: CovJSelFixture.units(4))
        ]
        let issues: [ChainIssue] = [.network(chains: [alphaChain, gammaChain]), .missingAccount(chains: [betaChain])]
        let muted = [ChainSettings(chainId: alphaChain.chainId, autobalanced: true, issueMuted: true)]
        let factory = AssetNetworksViewModelFactory(balanceViewModelFactory: AssetBalanceFormatterFactory())
        let all = [gamma, empty, ethereum, beta, locked, alpha]

        let byName = factory.buildViewModels(chainAssets: all, accountInfos: infos, wallet: wallet, locale: locale, filter: .myNetworks,
                                             sort: .name, chainsWithIssue: issues, chainSettings: muted)
        XCTAssertEqual(chainNames(byName), ["Alpha", "Beta", "Gamma"], "no balance, a fully frozen balance and no account are left out")
        XCTAssertEqual(byName.map(\.hasIssues), [false, true, true], "Alpha's network issue is muted")
        XCTAssertNotNil(byName[0].iconViewModel)
        XCTAssertEqual(byName[2].cryptoBalanceLabelText, crypto(3, gamma, locale: locale))

        let byPopularity = factory.buildViewModels(chainAssets: [alpha, beta, gamma], accountInfos: infos, wallet: wallet, locale: locale,
                                                   filter: .allNetworks, sort: .popularity, chainsWithIssue: [], chainSettings: [])
        XCTAssertEqual(chainNames(byPopularity), ["Beta", "Gamma", "Alpha"])

        let everything = factory.buildViewModels(chainAssets: all, accountInfos: infos, wallet: wallet, locale: locale, filter: .allNetworks,
                                                 sort: .name, chainsWithIssue: [], chainSettings: [])
        XCTAssertEqual(chainNames(everything), ["Alpha", "Beta", "Empty", "Gamma", "Locked"])
        XCTAssertEqual(everything[2].cryptoBalanceLabelText, crypto(0, empty, locale: locale))

        let unused = wallet.replacingUnusedChainIds([betaChain.chainId])
        let withUnused = factory.buildViewModels(chainAssets: [beta], accountInfos: infos, wallet: unused, locale: locale,
                                                 filter: .allNetworks, sort: .name, chainsWithIssue: issues, chainSettings: [])
        XCTAssertEqual(withUnused.map(\.hasIssues), [false], "a missing account on an unused network is not an issue")
    }

    func testFactoryFallsBackToPopularUtilityAssetsWhenNothingIsSelectable() throws {
        let wallet = CovJSelFixture.substrateWallet()
        let ranked = ChainAsset(chain: CovJSelFixture.chain(name: "Ranked", rank: 3, assets: []), asset: CovJSelFixture.asset("ranked"))
        let token = ChainAsset(chain: CovJSelFixture.chain(name: "Token", rank: 4, assets: []), asset: CovJSelFixture.asset("tkn", utility: false))
        let unranked = ChainAsset(chain: CovJSelFixture.chain(name: "Unranked", assets: []), asset: CovJSelFixture.asset("unranked"))
        let assets = [ranked, token, unranked]
        assets.forEach { AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: $0.assetKey) }
        defer { assets.forEach { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: $0.assetKey) } }
        let factory = AssetNetworksViewModelFactory(balanceViewModelFactory: AssetBalanceFormatterFactory())

        let models = factory.buildViewModels(chainAssets: assets, accountInfos: [:], wallet: wallet, locale: CovJFixture.locale,
                                             filter: .allNetworks, sort: .name, chainsWithIssue: [], chainSettings: [])

        XCTAssertEqual(chainNames(models), ["Ranked"])
    }

    func testSortItemsDescribeEverySortAndToggleSelection() {
        let sorts = AssetNetworksSort.defaultFilters(selected: .popularity)
        XCTAssertEqual(sorts.map(\.type), [.fiat, .popularity, .name])
        XCTAssertEqual(sorts.map(\.id), ["fiat", "popularity", "name"])
        XCTAssertEqual(sorts.map(\.selected), [false, true, false])
        let nameTitle = R.string.localizable.commonName(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
        XCTAssertEqual(sorts.map(\.title), ["Fiat Balance", "Popularity", nameTitle])
        XCTAssertEqual(AssetNetworksSortType(rawValue: "name"), .name)
        var item = AssetNetworksSort(type: .fiat)
        XCTAssertFalse(item.selected)
        item.changeSelectionState(isSelected: true)
        XCTAssertTrue(item.selected)
        item.reset()
        XCTAssertFalse(item.selected)
        XCTAssertEqual(AssetNetworksFilter(rawValue: 1), .myNetworks)
        XCTAssertNil(AssetNetworksFilter(rawValue: 2))
    }

    func testPresenterRebuildsOnInputsAndRoutesActions() throws {
        let manager = try CovJSelFixture.manager()
        let wallet = CovJSelFixture.substrateWallet()
        let chainA = CovJSelFixture.chain(name: "A", assets: [])
        let chainB = CovJSelFixture.chain(name: "B", assets: [])
        let assetA = ChainAsset(chain: chainA, asset: CovJSelFixture.asset("a"))
        let assetB = ChainAsset(chain: chainB, asset: CovJSelFixture.asset("b"))
        let ethereum = ChainAsset(chain: CovJSelFixture.chain(name: "E", options: [.ethereumBased], assets: []), asset: CovJSelFixture.asset("e"))
        let factory = CovJSelAssetNetworksFactorySpy()
        factory.result = [AssetNetworksTableCellModel(iconViewModel: nil, chainNameLabelText: "A", cryptoBalanceLabelText: "1",
                                                      fiatBalanceLabelText: "$1", chainAsset: assetA, hasIssues: false)]
        let interactor = CovJSelAssetNetworksInteractorSpy()
        let router = CovJSelAssetNetworksRouterSpy()
        let view = CovJSelAssetNetworksViewSpy()
        let presenter = AssetNetworksPresenter(interactor: interactor, router: router, localizationManager: manager, wallet: wallet,
                                               viewModelFactory: factory)
        presenter.didLoad(view: view)
        XCTAssertTrue(interactor.outputs.first === presenter)

        presenter.didReceiveChainAssets([assetA, assetB])
        XCTAssertTrue(factory.calls.isEmpty, "assets alone wait for balances or settings")
        presenter.didReceive(chainSettings: [ChainSettings.defaultSettings(for: chainA.chainId)])
        XCTAssertEqual(factory.calls.last?.chainAssets.count, 2)
        XCTAssertEqual(factory.calls.last?.settings.map(\.chainId), [chainA.chainId])
        XCTAssertTrue(CovJWait.until { view.received.count == 1 })
        XCTAssertEqual(view.received.first?.first?.chainNameLabelText, "A")

        presenter.didReceiveChainsWithIssues([.network(chains: [chainA])])
        XCTAssertEqual(factory.calls.count, 2)
        XCTAssertEqual(factory.calls.last?.issues.count, 1)

        let info = CovJSelFixture.info(free: CovJSelFixture.units(2))
        presenter.didReceiveAccountInfo(result: .success(info), for: assetA)
        XCTAssertEqual(factory.calls.count, 3)
        XCTAssertEqual(factory.calls.last?.accountInfos[try CovJSelFixture.key(assetA, wallet: wallet)] ?? nil, info)
        presenter.didReceiveAccountInfo(result: .success(info), for: assetA)
        presenter.didReceiveAccountInfo(result: .success(nil), for: assetB)
        presenter.didReceiveAccountInfo(result: .failure(CovJError("balance")), for: assetB)
        presenter.didReceiveAccountInfo(result: .success(info), for: ethereum)
        XCTAssertEqual(factory.calls.count, 3, "unchanged, empty, failed and accountless balances do not rebuild")

        presenter.didChangeNetworkSwitcher(segmentIndex: 1)
        XCTAssertEqual(factory.calls.last?.filter, .myNetworks)
        presenter.didChangeNetworkSwitcher(segmentIndex: 7)
        XCTAssertEqual(factory.calls.count, 4)

        presenter.didTapSortButton()
        let shown = try XCTUnwrap(router.filters.first)
        XCTAssertEqual(shown.title, R.string.localizable.commonFilterSortHeader(preferredLanguages: manager.selectedLocale.rLanguages))
        let offered = try XCTUnwrap(shown.filters.first?.items as? [AssetNetworksSort])
        XCTAssertEqual(offered.filter(\.selected).map(\.type), [.fiat])
        XCTAssertTrue(shown.output === presenter)

        presenter.didFinishWithFilters(filters: [FilterSet(title: nil, items: AssetNetworksSort.defaultFilters(selected: .name))])
        XCTAssertEqual(factory.calls.last?.sort, .name)
        presenter.didFinishWithFilters(filters: [])
        presenter.didFinishWithFilters(filters: [FilterSet(title: nil, items: [AssetNetworksSort(type: .fiat)])])
        XCTAssertEqual(factory.calls.count, 5, "no sort selected leaves the list as it is")

        presenter.didSelect(chainAsset: assetB)
        XCTAssertEqual(router.details, [assetB])
        presenter.applyLocalization()
        XCTAssertTrue(CovJWait.until { view.received.count == 5 })
    }

    func testPresenterNarrowsIssuesToTheTappedNetwork() throws {
        let wallet = CovJSelFixture.substrateWallet()
        let chainA = CovJSelFixture.chain(name: "A", assets: [])
        let chainB = CovJSelFixture.chain(name: "B", assets: [])
        let router = CovJSelAssetNetworksRouterSpy()
        let presenter = AssetNetworksPresenter(interactor: CovJSelAssetNetworksInteractorSpy(), router: router,
                                               localizationManager: try CovJSelFixture.manager(), wallet: wallet,
                                               viewModelFactory: CovJSelAssetNetworksFactorySpy())
        presenter.didReceiveChainsWithIssues([.network(chains: [chainA, chainB]), .missingAccount(chains: [chainB])])
        presenter.didTapResolveIssue(for: ChainAsset(chain: chainA, asset: CovJSelFixture.asset("a")))

        let issues = try XCTUnwrap(router.issues.first)
        XCTAssertEqual(issues.count, 2)
        guard case let .network(networkChains) = issues[0], case let .missingAccount(missingChains) = issues[1] else {
            return XCTFail("issue kinds keep their order")
        }
        XCTAssertEqual(networkChains.map(\.chainId), [chainA.chainId])
        XCTAssertTrue(missingChains.isEmpty)
    }
}
