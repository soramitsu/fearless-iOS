import XCTest
import UIKit
import SoraFoundation
import SoraKeystore
import SSFModels
@testable import fearless

final class CovHWMCViewOutputSpy: WalletMainContainerViewOutput {
    private(set) var calls: [String] = []
    private(set) var homeActions: [WalletHomeAction] = []

    func didLoad(view _: WalletMainContainerViewInput) { calls.append("load") }
    func didTapOnSwitchWallet() { calls.append("switch") }
    func didTapOnQR() { calls.append("qr") }
    func didTapSearch() { calls.append("search") }
    func didTapSelectNetwork() { calls.append("network") }
    func didTapOnBalance() { calls.append("balance") }
    func addressDidCopied() { calls.append("copied") }
    func didTapAccountScore() { calls.append("score") }
    func didTapHomeAction(_ action: WalletHomeAction) { homeActions.append(action) }
}

final class CovHWMCScoreFetcher: AccountStatisticsFetching {
    func subscribeForStatistics(address _: String) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        throw NSError(domain: "cov-h-score", code: 1)
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? { nil }
}

final class CovHWMCViewTests: XCTestCase {
    private var window: UIWindow?
    private let pages = [UIViewController(), UIViewController()]

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeController() throws -> (WalletMainContainerViewController, CovHWMCViewOutputSpy) {
        let output = CovHWMCViewOutputSpy()
        let controller = WalletMainContainerViewController(
            balanceInfoViewController: UIViewController(),
            pageControllers: pages,
            output: output,
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en"))
        )
        window = CovHAssetListFixture.host(controller)
        return (controller, output)
    }

    private func scoreViewModel(address: String? = "0x01") -> AccountScoreViewModel {
        AccountScoreViewModel(
            fetcher: CovHWMCScoreFetcher(),
            address: address,
            chain: nil,
            settings: InMemorySettingsManager(),
            eventCenter: EventCenter(),
            logger: nil
        )
    }

    func testControlsReachTheOutput() throws {
        let (controller, output) = try makeController()
        let rootView = controller.rootView

        rootView.switchWalletButton.sendActions(for: .touchUpInside)
        rootView.scanQRButton.sendActions(for: .touchUpInside)
        rootView.searchButton.sendActions(for: .touchUpInside)
        rootView.selectNetworkButton.sendActions(for: .touchUpInside)
        controller.perform(NSSelectorFromString("handleBalanceDidTap"))
        rootView.accountScoreView.starView.didFinishTouchingCosmos?(4)
        [rootView.sendButton, rootView.receiveButton, rootView.buyButton, rootView.swapButton].forEach {
            $0.sendActions(for: .touchUpInside)
        }

        XCTAssertEqual(output.calls, ["load", "switch", "qr", "search", "network", "balance", "score"])
        XCTAssertEqual(output.homeActions, [.send, .receive, .buy, .swap])
    }

    func testViewModelNftAvailabilityAndScoreAreShown() throws {
        let (controller, _) = try makeController()
        let rootView = controller.rootView

        controller.didReceiveViewModel(WalletMainContainerViewModel(
            walletName: "Cov H wallet",
            selectedFilter: "All networks",
            selectedFilterImage: nil,
            address: "5Cov",
            accountScoreViewModel: scoreViewModel()
        ))
        XCTAssertEqual(rootView.switchWalletButton.accessibilityValue, "Cov H wallet")
        XCTAssertEqual(rootView.selectNetworkButton.accessibilityValue, "All networks")
        XCTAssertFalse(rootView.addressCopyableLabel.isHidden)

        controller.didReceiveViewModel(WalletMainContainerViewModel(
            walletName: "Cov H wallet",
            selectedFilter: "Popular",
            selectedFilterImage: nil,
            address: nil,
            accountScoreViewModel: nil
        ))
        XCTAssertTrue(rootView.addressCopyableLabel.isHidden)

        controller.didReceiveAccountScoreViewModel(scoreViewModel(address: nil))
        controller.didReceiveNftAvailability(isNftAvailable: false)
        XCTAssertTrue(rootView.segmentContainer.isHidden)
        controller.didReceiveNftAvailability(isNftAvailable: true)
        XCTAssertFalse(rootView.segmentContainer.isHidden)
    }

    func testSyncUpdatesDriveTheSunBadge() throws {
        let (controller, _) = try makeController()
        let badge = controller.rootView.sunBadgeView

        controller.didReceive(syncUpdate: .catalogFailed)
        XCTAssertEqual(badge.syncState, .failed(unreachable: 0))

        controller.didReceive(syncUpdate: .catalog(running: true))
        XCTAssertEqual(badge.syncState, .syncing(progress: nil))

        controller.didReceive(syncUpdate: .catalog(running: false))
        controller.didReceive(syncUpdate: .connection(chainId: "cov-h", .connected))
        XCTAssertEqual(badge.syncState, .synced)
    }

    func testDebugSyncSeamPlaysSyntheticNetworks() throws {
        let (controller, _) = try makeController()
        let badge = controller.rootView.sunBadgeView

        NotificationCenter.default.post(name: FWShikibanDebugSeams.syncNotification, object: nil, userInfo: ["failures": 2])
        CovHAssetListFixture.spin { badge.syncState != .idle }
        guard case .syncing = badge.syncState else { return XCTFail("The synthetic networks start connecting") }

        CovHAssetListFixture.spin(timeout: 6) { badge.syncState == .failed(unreachable: 2) }
        XCTAssertEqual(badge.syncState, .failed(unreachable: 2))
    }

    func testSegmentsSwitchPagesAndFlightTiersCoverTheScreen() throws {
        let (controller, _) = try makeController()
        let pageController = controller.rootView.pageViewController

        controller.didSelect(1)
        CovHAssetListFixture.spin { pageController.viewControllers?.first === self.pages[1] }
        XCTAssertTrue(pageController.viewControllers?.first === pages[1])

        controller.didSelect(0)
        CovHAssetListFixture.spin { pageController.viewControllers?.first === self.pages[0] }
        XCTAssertTrue(pageController.viewControllers?.first === pages[0])

        XCTAssertEqual(UIPageViewController.NavigationDirection(from: 0), .reverse)
        XCTAssertEqual(UIPageViewController.NavigationDirection(from: 1), .forward)
        XCTAssertNil(UIPageViewController.NavigationDirection(from: 2))

        let tiers = controller.flightTiers
        XCTAssertEqual(tiers.map(\.tier), [0, 1, 2, 4])
        XCTAssertTrue(tiers.last?.view === controller.rootView.flightTiers.last?.view)
    }

    func testViewModelFactoryNamesEveryFilter() throws {
        let factory = WalletMainContainerViewModelFactory(accountScoreFetcher: CovHWMCScoreFetcher(), settings: InMemorySettingsManager())
        let wallet = AccountGenerator.generateMetaAccount()
        let locale = Locale(identifier: "en")
        let languages = locale.rLanguages
        let chain = CovHAssetListFixture.chain(name: "Cov H chain")
        let iconChain = ChainModel(
            rank: nil, disabled: false, chainId: "cov-h-icon", parentId: nil, paraId: nil, name: "Icon chain", xcm: nil,
            nodes: [], addressPrefix: 42, types: nil, icon: URL(string: "https://cov-h.invalid/icon.svg"), options: nil,
            externalApi: nil, selectedNode: nil, customNodes: nil, iosMinAppVersion: nil, identityChain: nil
        )

        let byChain = factory.buildViewModel(selectedFilter: .chain(iconChain.chainId), selectedChains: [chain, iconChain], selectedMetaAccount: wallet, locale: locale)
        XCTAssertEqual(byChain.selectedFilter, "Icon chain")
        XCTAssertNotNil(byChain.selectedFilterImage)
        XCTAssertEqual(byChain.walletName, wallet.name)
        XCTAssertEqual(byChain.accountScoreViewModel?.address, wallet.ethereumAddress?.toHex(includePrefix: true))

        let missing = factory.buildViewModel(selectedFilter: .chain("cov-h-missing"), selectedChains: [chain], selectedMetaAccount: wallet, locale: locale)
        XCTAssertEqual(missing.selectedFilter, "")
        XCTAssertNil(missing.selectedFilterImage)
        XCTAssertNil(missing.address)

        let all = factory.buildViewModel(selectedFilter: .all, selectedChains: [], selectedMetaAccount: wallet, locale: locale)
        XCTAssertEqual(all.selectedFilter, R.string.localizable.chainSelectionAllNetworks(preferredLanguages: languages))
        let popular = factory.buildViewModel(selectedFilter: .popular, selectedChains: [], selectedMetaAccount: wallet, locale: locale)
        XCTAssertEqual(popular.selectedFilter, R.string.localizable.networkManagementPopular(preferredLanguages: languages))
        let favourite = factory.buildViewModel(selectedFilter: .favourite, selectedChains: [], selectedMetaAccount: wallet, locale: locale)
        XCTAssertEqual(favourite.selectedFilter, R.string.localizable.networkManagmentFavourite(preferredLanguages: languages))
        XCTAssertTrue(favourite.accountScoreViewModel?.scoringEnabled ?? false, "Scoring is on by default for a wallet with an EVM address")
        let off = InMemorySettingsManager()
        off.accountScoreEnabled = false
        let disabled = WalletMainContainerViewModelFactory(accountScoreFetcher: CovHWMCScoreFetcher(), settings: off)
            .buildViewModel(selectedFilter: .favourite, selectedChains: [], selectedMetaAccount: wallet, locale: locale)
        XCTAssertFalse(disabled.accountScoreViewModel?.scoringEnabled ?? true, "Turning scoring off in settings disables it")
    }
}
