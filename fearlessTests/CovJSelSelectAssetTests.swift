import XCTest
import UIKit
import SoraFoundation
import SSFModels
import RobinHood
@testable import fearless

final class CovJSelSelectAssetInteractorOutputSpy: SelectAssetInteractorOutput {
    private let lock = NSLock()
    private var storedChainAssets: [Result<[ChainAsset], Error>] = []
    private var storedAccountInfos: [ChainAsset] = []

    var chainAssetResults: [Result<[ChainAsset], Error>] {
        lock.lock()
        defer { lock.unlock() }
        return storedChainAssets
    }

    var accountInfoAssets: [ChainAsset] {
        lock.lock()
        defer { lock.unlock() }
        return storedAccountInfos
    }

    func didReceiveChainAssets(result: Result<[ChainAsset], Error>) {
        lock.lock()
        storedChainAssets.append(result)
        lock.unlock()
    }

    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        lock.lock()
        storedAccountInfos.append(chainAsset)
        lock.unlock()
    }
}

final class CovJSelSelectAssetInteractorSpy: SelectAssetInteractorInput {
    private(set) var setupCount = 0
    private(set) var updates: [[ChainAsset]] = []

    func setup(with _: SelectAssetInteractorOutput) { setupCount += 1 }
    func update(with chainAssets: [ChainAsset]) { updates.append(chainAssets) }
}

final class CovJSelSelectAssetListSpy: SelectAssetViewOutput {
    var items: [SelectableViewModelProtocol]
    private(set) var loaded = 0
    private(set) var disappearances = 0
    private(set) var selected: [Int] = []

    init(items: [SelectableViewModelProtocol]) {
        self.items = items
    }

    var numberOfItems: Int { items.count }
    func item(at index: Int) -> SelectableViewModelProtocol { items[index] }
    func selectItem(at index: Int) { selected.append(index) }
    func didLoad(view _: SelectAssetViewInput) { loaded += 1 }
    func willDisappear() { disappearances += 1 }
}

final class CovJSelSelectAssetTests: XCTestCase {
    private func success(_ result: Result<[ChainAsset], Error>?) -> [ChainAsset]? {
        if case let .success(assets) = result { return assets }
        return nil
    }

    private func cellModel(symbol: String, fiat: String?, icon: ImageViewModelProtocol?, selected: Bool) -> SelectAssetCellViewModel {
        SelectAssetCellViewModel(assetKey: CovJFixture.chainAsset(chainName: "Net", symbol: symbol).assetKey, name: "Network \(symbol)",
                                 symbol: symbol, icon: icon, balanceString: "1.000", fiatBalanceString: fiat, isSelected: selected,
                                 balanceDecimal: 1, fiatBalanceDecimal: nil)
    }

    func testCellBindsBalancesIconAndSelection() {
        let cell = SelectAssetCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 50)
        XCTAssertEqual(cell.backgroundColor, .clear)
        XCTAssertNotNil(cell.selectedBackgroundView)

        cell.bind(viewModel: cellModel(symbol: "DOT", fiat: nil, icon: nil, selected: true))
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.nameLabel.text, "Network DOT")
        XCTAssertEqual(cell.symbolLabel.text, "DOT")
        XCTAssertEqual(cell.balanceLabel.text, "1.000")
        XCTAssertNil(cell.fiatBalanceLabel.text)
        XCTAssertTrue(cell.fiatBalanceLabel.isHidden)
        XCTAssertNotNil(cell.iconImageView.image)
        XCTAssertFalse(cell.checkmarkImageView.isHidden)

        cell.prepareForReuse()
        XCTAssertNil(cell.iconImageView.image)
        cell.bind(viewModel: cellModel(symbol: "KSM", fiat: "$4", icon: CovJSelFixture.offlineIcon, selected: false))
        XCTAssertEqual(cell.symbolLabel.text, "KSM")
        XCTAssertEqual(cell.fiatBalanceLabel.text, "$4")
        XCTAssertFalse(cell.fiatBalanceLabel.isHidden)
        XCTAssertTrue(cell.checkmarkImageView.isHidden)
        XCTAssertTrue(CovJWait.until { cell.iconImageView.image != nil })
        cell.didChangeSelection()
        XCTAssertTrue(cell.checkmarkImageView.isHidden)

        cell.bind(viewModel: SelectableIconDetailsListViewModel(title: "x", subtitle: nil, icon: nil, isSelected: true, identifier: nil))
        XCTAssertEqual(cell.symbolLabel.text, "KSM", "other view models are ignored")
    }

    func testInteractorUsesPresetAssetsAndForwardsBalances() throws {
        let wallet = CovJSelFixture.substrateWallet()
        let dot = CovJFixture.chainAsset(chainName: "Polkadot", symbol: "DOT")
        let adapter = CovJSelAccountInfoAdapterStub()
        let fetching = CovJSelChainAssetFetchingStub(result: nil)
        let output = CovJSelSelectAssetInteractorOutputSpy()
        let interactor = SelectAssetInteractor(chainAssetFetching: fetching, accountInfoSubscriptionAdapter: adapter, chainAssets: [dot], wallet: wallet)

        interactor.setup(with: output)
        XCTAssertEqual(success(output.chainAssetResults.first), [dot])
        XCTAssertEqual(adapter.subscriptions, [[dot]])
        XCTAssertNotNil(adapter.queues.first ?? nil, "balances are delivered on the interactor's own queue")
        XCTAssertTrue(fetching.requestedFilters.isEmpty)

        interactor.handleAccountInfo(result: .success(nil), accountId: try XCTUnwrap(wallet.substrateAccountId), chainAsset: dot)
        XCTAssertEqual(output.accountInfoAssets, [dot])

        interactor.update(with: [])
        XCTAssertEqual(output.chainAssetResults.count, 3)
        XCTAssertEqual(success(output.chainAssetResults[1]), [])
        if case .success = output.chainAssetResults[2] {
            XCTFail("an empty list is reported as a failure too")
        }
        let ksm = CovJFixture.chainAsset(chainName: "Kusama", symbol: "KSM")
        interactor.update(with: [ksm])
        XCTAssertEqual(success(output.chainAssetResults.last), [ksm])
        XCTAssertEqual(adapter.subscriptions.last, [ksm])
    }

    func testInteractorFetchesEnabledAssetsAndReportsEmptyAndFailedResults() {
        let wallet = CovJSelFixture.substrateWallet()
        let dot = CovJFixture.chainAsset(chainName: "Polkadot", symbol: "DOT")
        let adapter = CovJSelAccountInfoAdapterStub()
        let output = CovJSelSelectAssetInteractorOutputSpy()

        let fetching = CovJSelChainAssetFetchingStub(result: .success([dot]))
        SelectAssetInteractor(chainAssetFetching: fetching, accountInfoSubscriptionAdapter: adapter, chainAssets: nil, wallet: wallet)
            .setup(with: output)
        XCTAssertEqual(fetching.requestedFilters, [[.enabled(wallet: wallet)]])
        XCTAssertEqual(success(output.chainAssetResults.first), [dot])
        XCTAssertEqual(adapter.subscriptions, [[dot]])

        let empty = SelectAssetInteractor(chainAssetFetching: CovJSelChainAssetFetchingStub(result: .success([])),
                                          accountInfoSubscriptionAdapter: adapter, chainAssets: nil, wallet: wallet)
        empty.setup(with: output)
        XCTAssertEqual(output.chainAssetResults.count, 3)

        let failing = SelectAssetInteractor(chainAssetFetching: CovJSelChainAssetFetchingStub(result: .failure(CovJError("fetch"))),
                                            accountInfoSubscriptionAdapter: adapter, chainAssets: nil, wallet: wallet)
        failing.setup(with: output)
        XCTAssertEqual(output.chainAssetResults.count, 4)
        if case let .failure(error) = output.chainAssetResults.last {
            XCTAssertEqual(error as? CovJError, CovJError("fetch"))
        } else {
            XCTFail("expected the fetch failure")
        }

        let silent = SelectAssetInteractor(chainAssetFetching: CovJSelChainAssetFetchingStub(result: nil),
                                           accountInfoSubscriptionAdapter: adapter, chainAssets: nil, wallet: wallet)
        silent.setup(with: output)
        XCTAssertEqual(output.chainAssetResults.count, 4, "a cancelled fetch reports nothing")
        XCTAssertEqual(adapter.subscriptions.count, 2)
    }

    func testFactoryValuesPricedAssetsFirstAndMarksTheSelectedOne() throws {
        let locale = CovJFixture.locale
        let wallet = CovJSelFixture.substrateWallet()
        let currency = wallet.selectedCurrency
        let priceId = "covjsel-select-" + UUID().uuidString
        CovJSelFixture.registerPrice("2", priceId: priceId, currency: currency)
        let priced = ChainAsset(chain: CovJSelFixture.chain(name: "Priced", assets: []), asset: CovJSelFixture.asset("prc", priceId: priceId))
        let held = ChainAsset(chain: CovJSelFixture.chain(name: "Held", assets: []), asset: CovJSelFixture.asset("hld"))
        let empty = ChainAsset(chain: CovJSelFixture.chain(name: "Empty", assets: []), asset: CovJSelFixture.asset("emp"))
        let ethereum = ChainAsset(chain: CovJSelFixture.chain(name: "Ethereum", options: [.ethereumBased], assets: []),
                                  asset: CovJSelFixture.asset("eth", priceId: priceId))
        let infos: [ChainAssetKey: AccountInfo?] = [
            try CovJSelFixture.key(priced, wallet: wallet): CovJSelFixture.info(free: CovJSelFixture.units(4), reserved: CovJSelFixture.units(1)),
            try CovJSelFixture.key(held, wallet: wallet): CovJSelFixture.info(free: CovJSelFixture.units(7))
        ]
        let factory = SelectAssetViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())

        let models = factory.buildViewModel(wallet: wallet, chainAssets: [empty, held, ethereum, priced], accountInfos: infos, locale: locale,
                                            selectedAssetId: "hld")

        XCTAssertEqual(models.map(\.symbol), ["PRC", "HLD", "EMP", "ETH"])
        let first = models[0]
        XCTAssertEqual(first.name, "Priced")
        XCTAssertEqual(first.fiatBalanceDecimal, 10, "the fiat value counts free and reserved funds")
        XCTAssertEqual(first.fiatBalanceString, CovJSelFixture.fiat(10, currency: currency, locale: locale, usage: .listCrypto))
        XCTAssertEqual(first.balanceDecimal, 4)
        XCTAssertEqual(first.balanceString, Decimal(4).toString(locale: locale, minimumDigits: 3, maximumDigits: 8))
        XCTAssertFalse(first.isSelected)
        XCTAssertTrue(models[1].isSelected)
        XCTAssertNil(models[1].fiatBalanceString)
        XCTAssertEqual(models[2].balanceString, Decimal(0).toString(locale: locale, minimumDigits: 0, maximumDigits: 0))
        XCTAssertNil(models[3].fiatBalanceDecimal, "no account, no value")
        XCTAssertNil(models[3].icon)
    }

    func testPresenterReportsFailuresAndUnknownRowsAndForwardsUpdates() throws {
        let wallet = CovJSelFixture.substrateWallet()
        let router = CovJSelDismissSpy()
        let output = CovJSelSelectAssetOutputSpy()
        let interactor = CovJSelSelectAssetInteractorSpy()
        let view = CovJSelListViewSpy()
        let presenter = SelectAssetPresenter(
            viewModelFactory: SelectAssetViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory()),
            wallet: wallet,
            selectedAssetId: nil,
            searchTextsViewModel: .searchAssetPlaceholder,
            interactor: interactor,
            router: router,
            output: output,
            localizationManager: try CovJSelFixture.manager(),
            contextTag: 9
        )
        presenter.selectItem(at: 0)
        XCTAssertTrue(output.completions.isEmpty, "nothing happens before the view loads")

        presenter.didLoad(view: view)
        XCTAssertEqual(interactor.setupCount, 1)
        XCTAssertEqual(view.boundSearch, [.searchAssetPlaceholder])

        presenter.didReceiveChainAssets(result: .failure(CovJError("assets")))
        XCTAssertEqual(router.errors.compactMap { $0 as? CovJError }, [CovJError("assets")])
        presenter.didReceiveAccountInfo(result: .failure(CovJError("balance")), for: CovJFixture.chainAsset())
        XCTAssertTrue(CovJWait.until { router.errors.count == 2 })

        presenter.selectItem(at: 3)
        XCTAssertEqual(output.completions.count, 1)
        XCTAssertNil(output.completions.first?.chainAsset)
        XCTAssertEqual(output.completions.first?.tag, 9)
        XCTAssertEqual(router.dismissed.count, 1)

        let dot = CovJFixture.chainAsset(chainName: "Polkadot", symbol: "DOT")
        presenter.update(with: [dot])
        XCTAssertEqual(interactor.updates, [[dot]])

        presenter.didReceiveChainAssets(result: .success([dot]))
        presenter.applyLocalization()
        XCTAssertEqual(presenter.numberOfItems, 0, "rows wait for the first balance")
        let ethereum = ChainAsset(chain: CovJSelFixture.chain(name: "Ethereum", options: [.ethereumBased], assets: []), asset: CovJSelFixture.asset("e"))
        presenter.didReceiveAccountInfo(result: .success(nil), for: ethereum)
        CovJWait.drain(0.2)
        XCTAssertEqual(presenter.numberOfItems, 0, "a balance without an account does not count")
        presenter.didReceiveAccountInfo(result: .success(nil), for: dot)
        XCTAssertTrue(CovJWait.until { presenter.numberOfItems == 1 && view.reloadCount >= 1 })
        presenter.selectItem(at: 0)
        presenter.willDisappear()
        XCTAssertEqual(output.completions.last?.chainAsset, dot)
        XCTAssertEqual(router.dismissed.count, 2)
    }

    func testControllerForHalfScreenEmbedsAndForwardsDisappearance() throws {
        let manager = try CovJSelFixture.manager()
        let presenter = CovJSelSelectAssetListSpy(items: [cellModel(symbol: "DOT", fiat: "$1", icon: nil, selected: false)])
        let controller = SelectAssetViewController(isFullSize: false, output: presenter, localizationManager: manager, embed: true)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }

        XCTAssertEqual(presenter.loaded, 1)
        let root = controller.rootView
        XCTAssertEqual(root.titleLabel.text, R.string.localizable.commonSelectAsset(preferredLanguages: manager.selectedLocale.rLanguages))
        XCTAssertTrue(root.indicator.isHidden, "an embedded list has no grabber")
        XCTAssertEqual(root.layer.cornerRadius, 0)
        let halfScreen = UIScreen.main.bounds.height / 2
        XCTAssertTrue(root.contentStackView.constraints.contains { $0.firstAttribute == .height && abs($0.constant - halfScreen) < 0.5 })
        let cell = try XCTUnwrap(controller.tableView(root.tableView, cellForRowAt: IndexPath(row: 0, section: 0)) as? SelectAssetCell)
        XCTAssertEqual(cell.symbolLabel.text, "DOT")
        controller.tableView(root.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(presenter.selected, [0])
        controller.applyLocalization()
        XCTAssertEqual(root.locale, manager.selectedLocale)
        controller.viewWillDisappear(false)
        XCTAssertEqual(presenter.disappearances, 1)

        let router = SelectAssetRouter()
        router.complete(on: CovJSelListViewSpy(), selecting: nil)
        XCTAssertEqual(presenter.disappearances, 1)
    }
}
