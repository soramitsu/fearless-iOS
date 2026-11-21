import XCTest
import UIKit
import BigInt
import RobinHood
import SoraFoundation
import SSFModels
@testable import fearless

final class CovJFinWalletBalanceAdapter: WalletBalanceSubscriptionAdapterProtocol {
    private(set) var calls: [String] = []
    private(set) var listeners: [WalletBalanceSubscriptionListener] = []

    func subscribeWalletBalance(wallet: MetaAccountModel, listener: WalletBalanceSubscriptionListener) {
        calls.append("wallet:\(wallet.metaId)")
        listeners.append(listener)
    }

    func subscribeWalletsBalances(listener: WalletBalanceSubscriptionListener) {
        calls.append("wallets")
        listeners.append(listener)
    }

    func subscribeChainAssetBalance(wallet: MetaAccountModel, chainAsset: ChainAsset, listener: WalletBalanceSubscriptionListener) {
        calls.append("chainAsset:\(wallet.metaId):\(chainAsset.asset.symbol)")
        listeners.append(listener)
    }

    func subscribeChainAssetsBalance(chainAssets: [ChainAsset], wallet: MetaAccountModel, listener: WalletBalanceSubscriptionListener) {
        calls.append("chainAssets:\(wallet.metaId):\(chainAssets.count)")
        listeners.append(listener)
    }

    func subscribeNetworkManagementBalance(wallet: MetaAccountModel, listener: WalletBalanceSubscriptionListener) {
        calls.append("network:\(wallet.metaId)")
        listeners.append(listener)
    }

    func unsubscribe(listener _: WalletBalanceSubscriptionListener) {
        calls.append("unsubscribe")
    }
}

final class CovJFinBalanceInfoOutput: BalanceInfoInteractorOutput {
    var balances: [WalletBalancesResult] = []
    var minimums: [Result<BigUInt, Error>] = []
    var locks: [Result<BalanceLocks?, Error>] = []

    func didReceiveWalletBalancesResult(_ result: WalletBalancesResult) { balances.append(result) }
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) { minimums.append(result) }
    func didReceiveBalanceLocks(result: Result<BalanceLocks?, Error>) { locks.append(result) }
}

final class CovJFinBalanceInfoInteractor: BalanceInfoInteractorInput {
    var balanceInfoType: BalanceInfoType
    weak var output: BalanceInfoInteractorOutput?
    var fetches = 0

    init(type: BalanceInfoType) { balanceInfoType = type }

    func setup(with output: BalanceInfoInteractorOutput) { self.output = output }
    func fetchBalanceInfo() { fetches += 1 }
}

final class CovJFinBalanceInfoFactory: BalanceInfoViewModelFactoryProtocol {
    var requests: [(balances: WalletBalanceInfos, infoButtonEnabled: Bool)] = []

    func buildBalanceInfo(with _: BalanceInfoType, balances: WalletBalanceInfos, infoButtonEnabled: Bool, locale _: Locale) -> BalanceInfoViewModel {
        requests.append((balances, infoButtonEnabled))
        return BalanceInfoViewModel(dayChangeAttributedString: nil, balanceString: "$\(balances.count)", infoButtonEnabled: infoButtonEnabled)
    }
}

final class CovJFinBalanceInfoView: UIViewController, BalanceInfoViewInput {
    var viewModels: [BalanceInfoViewModel?] = []
    func didReceiveViewModel(_ viewModel: BalanceInfoViewModel?) { viewModels.append(viewModel) }
}

final class CovJFinEventCenter: EventCenterProtocol {
    private(set) var observers: [EventVisitorProtocol] = []
    func notify(with event: EventProtocol) { observers.forEach { event.accept(visitor: $0) } }
    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) { observers.append(observer) }
    func remove(observer: EventVisitorProtocol) { observers.removeAll { $0 === observer } }
}

final class CovJFinBalanceInfoViewOutput: BalanceInfoViewOutput {
    var loads = 0
    func didLoad(view _: BalanceInfoViewInput) { loads += 1 }
}

enum CovJFinBalanceFixture {
    static func info(
        fiat: Decimal = 50,
        accountInfos: [ChainAssetKey: AccountInfo?] = [:],
        filteredPart: WalletBalanceFilteredPart? = nil
    ) -> WalletBalanceInfo {
        WalletBalanceInfo(
            totalFiatValue: fiat + 10,
            enabledAssetFiatBalance: fiat,
            dayChangePercent: Decimal(string: "0.05") ?? 0,
            dayChangeValue: Decimal(string: "2.5") ?? 0,
            totalDayChangePercent: Decimal(string: "-0.1") ?? 0,
            totalDayChangeValue: Decimal(string: "-4") ?? 0,
            currency: Currency.defaultCurrency(),
            prices: [],
            accountInfos: accountInfos,
            exclusions: PortfolioExclusions(),
            filteredPart: filteredPart
        )
    }
}

final class CovJFinBalanceInfoFactoryTests: XCTestCase {
    private let locale = CovJFixture.locale
    private let factory = BalanceInfoViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())

    private func fiat(_ value: Decimal) -> String {
        AssetBalanceFormatterFactory()
            .createTokenFormatter(for: AssetBalanceDisplayInfo.forCurrency(Currency.defaultCurrency()), usageCase: .fiat)
            .value(for: locale).stringFromDecimal(value) ?? ""
    }

    private func token(_ value: Decimal, _ chainAsset: ChainAsset) -> String {
        AssetBalanceFormatterFactory().createTokenFormatter(for: chainAsset.asset.displayInfo, usageCase: .listCrypto)
            .value(for: locale).stringFromDecimal(value) ?? ""
    }

    private func change(_ percent: String, _ value: Decimal) -> String {
        "\((Decimal(string: percent) ?? 0).percentString(locale: locale) ?? "") (\(fiat(abs(value))))"
    }

    private func key(_ chainAsset: ChainAsset, _ wallet: MetaAccountModel) throws -> ChainAssetKey {
        chainAsset.uniqueKey(accountId: try XCTUnwrap(wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId))
    }

    private func build(_ type: BalanceInfoType, _ balances: WalletBalanceInfos, info: Bool = true) -> BalanceInfoViewModel {
        factory.buildBalanceInfo(with: type, balances: balances, infoButtonEnabled: info, locale: locale)
    }

    func testWalletBalanceShowsFiatTotalAndColouredDayChange() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let empty = build(.wallet(wallet: wallet), [:])
        XCTAssertEqual(empty.balanceString, "$0")
        XCTAssertFalse(empty.infoButtonEnabled)
        XCTAssertNil(empty.dayChangeAttributedString)

        let viewModel = build(.wallet(wallet: wallet), [wallet.metaId: CovJFinBalanceFixture.info(fiat: 50)])
        XCTAssertEqual(viewModel.balanceString, "$50")
        XCTAssertFalse(viewModel.infoButtonEnabled)
        XCTAssertNil(viewModel.filteredPartString)
        let dayChange = try XCTUnwrap(viewModel.dayChangeAttributedString)
        XCTAssertEqual(dayChange.string, change("0.05", 2.5))
        let color = dayChange.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, FWSunlit.Palette.change(Decimal(string: "0.05") ?? 0))
        let valueColor = dayChange.attribute(.foregroundColor, at: dayChange.length - 1, effectiveRange: nil) as? UIColor
        XCTAssertEqual(valueColor, R.color.colorLightGray())
    }

    func testChainAssetBalanceUsesTransferableAmountAndAssetChange() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovJFixture.chainAsset(chainName: "Alpha", symbol: "alp")
        let type = BalanceInfoType.chainAsset(wallet: wallet, chainAsset: chainAsset)
        XCTAssertEqual(build(type, [:]).balanceString, "0 ALP")
        XCTAssertFalse(build(type, [:]).infoButtonEnabled)

        let missing = build(type, [wallet.metaId: CovJFinBalanceFixture.info()], info: true)
        XCTAssertEqual(missing.balanceString, "0 ALP")
        XCTAssertTrue(missing.infoButtonEnabled)
        XCTAssertNil(missing.dayChangeAttributedString)

        let accountInfo = CovJFinClaimFixture.accountInfo(free: 1_500_000_000_000, frozen: 500_000_000_000)
        let funded = build(type, [wallet.metaId: CovJFinBalanceFixture.info(accountInfos: [try key(chainAsset, wallet): accountInfo])], info: true)
        XCTAssertEqual(funded.balanceString, token(1, chainAsset))
        XCTAssertTrue(funded.infoButtonEnabled)
        XCTAssertEqual(funded.dayChangeAttributedString?.string, change("-0.1", -4))

        let noAccount = CovJFinClaimFixture.walletWithoutAccounts()
        let unreachable = build(.chainAsset(wallet: noAccount, chainAsset: chainAsset), [noAccount.metaId: CovJFinBalanceFixture.info()])
        XCTAssertEqual(unreachable.balanceString, "0 ALP")
        XCTAssertFalse(unreachable.infoButtonEnabled)
    }

    func testChainAssetsBalanceSumsEveryNetwork() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let first = CovJFixture.chainAsset(chainName: "First", symbol: "usd")
        let second = CovJFixture.chainAsset(chainName: "Second", symbol: "usd")
        let infos: [ChainAssetKey: AccountInfo?] = [
            try key(first, wallet): CovJFinClaimFixture.accountInfo(free: 1_000_000_000_000),
            try key(second, wallet): CovJFinClaimFixture.accountInfo(free: 2_000_000_000_000)
        ]
        let type = BalanceInfoType.chainAssets(chainAssets: [first, second], wallet: wallet)
        XCTAssertEqual(build(type, [:]).balanceString, "0 USD")

        let summed = build(type, [wallet.metaId: CovJFinBalanceFixture.info(accountInfos: infos)], info: false)
        XCTAssertEqual(summed.balanceString, token(3, first))
        XCTAssertFalse(summed.infoButtonEnabled)
        XCTAssertEqual(summed.dayChangeAttributedString?.string, change("-0.1", -4))

        let partial = build(type, [wallet.metaId: CovJFinBalanceFixture.info(accountInfos: [try key(second, wallet): nil])])
        XCTAssertEqual(partial.balanceString, token(0, first))

        let none = build(.chainAssets(chainAssets: [], wallet: wallet), [wallet.metaId: CovJFinBalanceFixture.info()], info: true)
        XCTAssertEqual(none.balanceString, "0")
        XCTAssertTrue(none.infoButtonEnabled)
        XCTAssertEqual(build(.chainAssets(chainAssets: [], wallet: wallet), [:]).balanceString, "0 ")
    }

    func testNetworkManagementShowsFilteredPartForEachFilter() {
        let wallet = AccountGenerator.generateMetaAccount()
        let type = BalanceInfoType.networkManagement(wallet: wallet)
        XCTAssertEqual(build(type, [:]).balanceString, "$0")

        func caption(_ filter: NetworkManagmentFilter, name: String?) -> String? {
            let part = WalletBalanceFilteredPart(filter: filter, networkName: name, fiatBalance: 20)
            let viewModel = build(type, [wallet.metaId: CovJFinBalanceFixture.info(fiat: 50, filteredPart: part)])
            XCTAssertEqual(viewModel.balanceString, "$50")
            return viewModel.filteredPartString
        }

        let popular = R.string.localizable.networkManagementPopular(preferredLanguages: locale.rLanguages)
        let favourite = R.string.localizable.networkManagmentFavourite(preferredLanguages: locale.rLanguages)
        let popularCaption = caption(.popular, name: nil)
        XCTAssertTrue(popularCaption?.contains(popular) == true, popularCaption ?? "nil")
        XCTAssertTrue(popularCaption?.contains(fiat(20)) == true, popularCaption ?? "nil")
        XCTAssertTrue(caption(.favourite, name: nil)?.contains(favourite) == true)
        XCTAssertTrue(caption(.chain("alpha"), name: "Alpha")?.contains("Alpha") == true)
        XCTAssertNil(caption(.chain("alpha"), name: nil))
        XCTAssertNil(caption(.all, name: nil))
        XCTAssertNil(build(type, [wallet.metaId: CovJFinBalanceFixture.info()]).filteredPartString)
    }
}

final class CovJFinBalanceInfoModuleTests: XCTestCase {
    func testInteractorSubscribesForEachNonAssetTypeAndForwardsResults() {
        let wallet = AccountGenerator.generateMetaAccount()
        let adapter = CovJFinWalletBalanceAdapter()
        let interactor = BalanceInfoInteractor(
            balanceInfoType: .wallet(wallet: wallet),
            walletBalanceSubscriptionAdapter: adapter,
            operationManager: OperationManager(operationQueue: OperationQueue()),
            storageRequestFactory: CovJFinStorageRequestFactory()
        )
        let output = CovJFinBalanceInfoOutput()
        interactor.setup(with: output)
        XCTAssertEqual(adapter.calls, ["unsubscribe", "wallet:\(wallet.metaId)"])
        XCTAssertTrue(adapter.listeners.first === interactor)
        guard case let .wallet(listenerWallet) = interactor.type else { return XCTFail("wallet listener expected") }
        XCTAssertEqual(listenerWallet.metaId, wallet.metaId)

        let chainAsset = CovJFixture.chainAsset()
        interactor.balanceInfoType = .chainAssets(chainAssets: [chainAsset, chainAsset], wallet: wallet)
        interactor.fetchBalanceInfo()
        interactor.balanceInfoType = .networkManagement(wallet: wallet)
        interactor.fetchBalanceInfo()
        XCTAssertEqual(adapter.calls.suffix(4), ["unsubscribe", "chainAssets:\(wallet.metaId):2", "unsubscribe", "network:\(wallet.metaId)"])
        guard case .networkManagement = interactor.type else { return XCTFail("network listener expected") }

        interactor.balanceInfoType = .chainAsset(wallet: wallet, chainAsset: chainAsset)
        guard case let .chainAsset(_, listenerAsset) = interactor.type else { return XCTFail("chain asset listener expected") }
        XCTAssertEqual(listenerAsset.chainAssetId, chainAsset.chainAssetId)
        interactor.balanceInfoType = .chainAssets(chainAssets: [chainAsset], wallet: wallet)
        guard case let .chainAssets(assets, _) = interactor.type else { return XCTFail("chain assets listener expected") }
        XCTAssertEqual(assets.count, 1)

        interactor.handle(result: .success([wallet.metaId: CovJFinBalanceFixture.info()]))
        interactor.handle(result: .failure(CovJError("balances")))
        XCTAssertEqual(output.balances.count, 2)
        if case let .success(infos) = output.balances.first {
            XCTAssertEqual(infos[wallet.metaId]?.enabledAssetFiatBalance, 50)
        } else {
            XCTFail("success expected first")
        }
        XCTAssertTrue(output.minimums.isEmpty)
        XCTAssertTrue(output.locks.isEmpty)
    }

    func testPresenterBuildsViewModelsAndFollowsSelectedAccount() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = CovJFinBalanceInfoInteractor(type: .wallet(wallet: wallet))
        let factory = CovJFinBalanceInfoFactory()
        let events = CovJFinEventCenter()
        let presenter = BalanceInfoPresenter(
            balanceInfoViewModelFactoryProtocol: factory, interactor: interactor, router: BalanceInfoRouter(),
            logger: Logger.shared, localizationManager: LocalizationManager.shared, eventCenter: events
        )
        XCTAssertTrue(events.observers.first === presenter)
        let view = CovJFinBalanceInfoView()
        presenter.didLoad(view: view)
        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(view.viewModels.count, 1)
        XCTAssertNil(view.viewModels.first ?? nil)

        presenter.didReceiveWalletBalancesResult(.success([wallet.metaId: CovJFinBalanceFixture.info()]))
        XCTAssertTrue(CovJWait.until { view.viewModels.count == 2 })
        XCTAssertEqual(view.viewModels.last??.balanceString, "$1")
        XCTAssertEqual(factory.requests.last?.infoButtonEnabled, false)

        presenter.didReceiveBalanceLocks(result: .success(try CovJFinClaimFixture.balanceLocks([("vesting ", 1)])))
        presenter.didReceiveBalanceLocks(result: .failure(CovJError("locks")))
        presenter.didReceiveMinimumBalance(result: .success(10))
        presenter.didReceiveMinimumBalance(result: .failure(CovJError("minimum")))
        presenter.didReceiveWalletBalancesResult(.failure(CovJError("balances")))
        presenter.didReceiveWalletBalancesResult(.success([:]))
        XCTAssertTrue(CovJWait.until { view.viewModels.count == 3 })
        XCTAssertEqual(factory.requests.count, 2)
        XCTAssertEqual(factory.requests.last?.infoButtonEnabled, true)
        XCTAssertEqual(view.viewModels.last??.balanceString, "$0")

        let other = AccountGenerator.generateMetaAccount()
        let chainAsset = CovJFixture.chainAsset()
        presenter.replace(infoType: .chainAsset(wallet: wallet, chainAsset: chainAsset))
        XCTAssertEqual(interactor.fetches, 1)
        events.notify(with: SelectedAccountChanged(account: other))
        guard case let .chainAsset(newWallet, newAsset) = interactor.balanceInfoType else { return XCTFail("chain asset type expected") }
        XCTAssertEqual(newWallet.metaId, other.metaId)
        XCTAssertEqual(newAsset.chainAssetId, chainAsset.chainAssetId)

        interactor.balanceInfoType = .wallet(wallet: wallet)
        presenter.processSelectedAccountChanged(event: SelectedAccountChanged(account: other))
        guard case let .wallet(walletAfter) = interactor.balanceInfoType else { return XCTFail("wallet type expected") }
        XCTAssertEqual(walletAfter.metaId, other.metaId)

        interactor.balanceInfoType = .chainAssets(chainAssets: [chainAsset], wallet: wallet)
        presenter.processSelectedAccountChanged(event: SelectedAccountChanged(account: other))
        guard case let .chainAssets(assets, assetsWallet) = interactor.balanceInfoType else { return XCTFail("chain assets type expected") }
        XCTAssertEqual(assets.count, 1)
        XCTAssertEqual(assetsWallet.metaId, other.metaId)

        interactor.balanceInfoType = .networkManagement(wallet: wallet)
        presenter.processSelectedAccountChanged(event: SelectedAccountChanged(account: other))
        guard case let .networkManagement(networkWallet) = interactor.balanceInfoType else { return XCTFail("network type expected") }
        XCTAssertEqual(networkWallet.metaId, other.metaId)
        XCTAssertEqual(interactor.fetches, 5)
        XCTAssertEqual(interactor.balanceInfoType.wallet.metaId, other.metaId)
        presenter.applyLocalization()
        XCTAssertEqual(view.viewModels.count, 3)
    }

    func testControllerShowsSkeletonUntilAViewModelArrives() throws {
        let output = CovJFinBalanceInfoViewOutput()
        let controller = BalanceInfoViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = try XCTUnwrap(controller.view as? BalanceInfoViewLayout)
        var loadingStates: [Bool] = []
        root.onLoadingChange = { loadingStates.append($0) }
        XCTAssertEqual(output.loads, 1)

        controller.didReceiveViewModel(nil)
        XCTAssertTrue(root.isLoadingTotal)
        root.frame = CGRect(x: 0, y: 0, width: 300, height: 120)
        controller.viewDidLayoutSubviews()
        XCTAssertTrue(root.isLoadingTotal)
        root.didAppearSkeleton()
        root.didDisappearSkeleton()

        let dayChange = NSAttributedString(string: "+5% ($2.50)")
        controller.didReceiveViewModel(BalanceInfoViewModel(dayChangeAttributedString: dayChange, balanceString: "$50", infoButtonEnabled: true))
        XCTAssertFalse(root.isLoadingTotal)
        XCTAssertEqual(loadingStates, [true, false])
        let labels = CovJViewFixture.descendants(UILabel.self, in: root)
        XCTAssertEqual(CovJViewFixture.descendants(FWRollingLabel.self, in: root).first?.text, "$50")
        XCTAssertTrue(labels.contains { $0.attributedText?.string == "+5% ($2.50)" })
        root.stopLoadingIfNeeded()
        XCTAssertFalse(root.isLoadingTotal)
        controller.applyLocalization()
    }

    func testPortfolioPresentationMarksTheTotalAsHeaderWhenRestyled() throws {
        let layout = BalanceInfoViewLayout()
        let window = try CovJViewFixture.host(layout)
        defer { window.isHidden = true }
        let total = try XCTUnwrap(CovJViewFixture.descendants(FWRollingLabel.self, in: layout).first)
        XCTAssertFalse(total.accessibilityTraits.contains(.header))

        layout.configurePortfolioPresentation(locale: CovJFixture.locale)
        layout.configurePortfolioPresentation(locale: CovJFixture.locale)
        layout.traitCollectionDidChange(nil)

        XCTAssertEqual(total.accessibilityTraits.contains(.header), FWAppearance.walletHeaderRestyled)
        if FWAppearance.walletHeaderRestyled {
            XCTAssertEqual(total.textColor, FWSunlit.Palette.textPrimary)
        }
        XCTAssertFalse(layout.isLoadingTotal)
    }
}
