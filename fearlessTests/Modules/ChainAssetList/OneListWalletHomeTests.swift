import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

/// One-list wallet home: the list's own search field and network chips, and the wallet header around them.
@MainActor
final class OneListWalletHomeTests: XCTestCase {
    private let chips = [
        PortfolioNetworkChip(id: "all", title: "All networks", selected: true),
        PortfolioNetworkChip(id: "chain-a", title: "Alpha", selected: false)
    ]

    // MARK: - Discovery view

    func testDiscoveryViewWaitsForAPauseKeepsTheTypedTextAndShowsTheSearchOutcome() async throws {
        let discovery = PortfolioDiscoveryView()
        let window = try host(discovery)
        defer { close(window) }
        var queries: [String] = []
        var selected: [String] = []
        var more = 0
        var active: [Bool] = []
        discovery.onSearch = { queries.append($0) }
        discovery.onSelectNetwork = { selected.append($0) }
        discovery.onMoreNetworks = { more += 1 }
        discovery.onSearchActiveChange = { active.append($0) }
        discovery.bind(search: "", chips: chips, showsMigration: false, searchAll: false, foundNothing: false)
        XCTAssertEqual(discovery.chipButtons.map(\.chipId), ["all", "chain-a", "more"])
        let first = discovery.chipButtons
        discovery.bind(search: "", chips: chips, showsMigration: false, searchAll: false, foundNothing: false)
        XCTAssertTrue(zip(first, discovery.chipButtons).allSatisfy { $0 === $1 }, "A balance update keeps the chips")

        XCTAssertTrue(discovery.focusSearch())
        XCTAssertEqual(active, [true])
        XCTAssertTrue(discovery.searchWell.controlFocused)
        for text in ["us", "usd"] {
            discovery.searchField.text = text
            discovery.searchField.sendActions(for: .editingChanged)
        }
        XCTAssertTrue(queries.isEmpty, "The list waits for a pause in typing")
        // A list built for an older keystroke arrives while typing: the field keeps what was typed.
        discovery.bind(search: "us", chips: chips, showsMigration: false, searchAll: false, foundNothing: false)
        XCTAssertEqual(discovery.searchField.text, "usd")
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(queries, ["usd"])
        discovery.searchField.text = "usdt"
        discovery.searchField.sendActions(for: .editingChanged)
        XCTAssertTrue(discovery.textFieldShouldReturn(discovery.searchField))
        XCTAssertEqual(queries, ["usd", "usdt"], "The Search key sends at once")
        XCTAssertEqual(active, [true, false])
        XCTAssertFalse(discovery.searchWell.controlFocused)

        let chosen = [chips[0].with(selected: false), chips[1].with(selected: true)]
        discovery.bind(search: "zzz", chips: chosen, showsMigration: false, searchAll: true, foundNothing: true)
        XCTAssertEqual(discovery.searchField.text, "zzz", "Not typing: the field shows the list's search")
        XCTAssertEqual(discovery.noResultsLabel.superview?.isHidden, false)
        XCTAssertEqual(discovery.noResultsLabel.text, "No networks or assets were found :(")
        XCTAssertEqual(discovery.searchAllButton.superview?.isHidden, false)
        XCTAssertEqual(discovery.chipButtons.map(\.isSelected), [false, true, false])
        XCTAssertEqual(discovery.chipButtons[1].surface.style, .inset, "The chosen chip is pressed in")
        XCTAssertEqual(discovery.chipButtons[0].surface.style, .raised1)
        XCTAssertTrue(discovery.chipButtons[1].accessibilityTraits.contains(.selected))
        XCTAssertEqual(discovery.chipButtons[1].accessibilityIdentifier, "portfolioNetwork:chain-a")
        discovery.searchAllButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, ["all"])
        for chip in discovery.chipButtons {
            chip.sendActions(for: .touchUpInside)
        }
        XCTAssertEqual(selected, ["all", "all", "chain-a"])
        XCTAssertEqual(more, 1)
        discovery.bind(search: "zzz", chips: chosen, showsMigration: true, searchAll: false, foundNothing: false)
        XCTAssertEqual(discovery.migrationCard.superview?.isHidden, false)
        XCTAssertEqual(discovery.searchAllButton.superview?.isHidden, true)
        XCTAssertEqual(discovery.noResultsLabel.superview?.isHidden, true)
    }

    func testDiscoveryControlsKeepTheirSizeAtAccessibilityTextSizes() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Trait overrides need iOS 17") }
        let discovery = PortfolioDiscoveryView()
        let window = try host(discovery)
        defer { close(window) }
        discovery.locale = Locale(identifier: "ru")
        discovery.bind(search: "", chips: chips, showsMigration: true, searchAll: true, foundNothing: true)
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            window.traitOverrides.preferredContentSizeCategory = category
            await settle(window)
            let chipFont = UIFont.fw(.labelM, compatibleWith: discovery.traitCollection)
            for chip in discovery.chipButtons {
                XCTAssertGreaterThanOrEqual(chip.bounds.height, max(44, ceil(chipFont.lineHeight) + 20) - 0.5)
                XCTAssertEqual(chip.titleLabel.font.pointSize, chipFont.pointSize, accuracy: 0.5)
                XCTAssertGreaterThanOrEqual(chip.titleLabel.bounds.width + 1, chip.titleLabel.intrinsicContentSize.width)
            }
            XCTAssertGreaterThanOrEqual(discovery.searchWell.bounds.height, 48)
            let font = try XCTUnwrap(discovery.searchField.font)
            XCTAssertGreaterThanOrEqual(discovery.searchField.bounds.height, ceil(font.lineHeight))
            XCTAssertEqual(discovery.migrationLabel.text, "Все ваши активы в одном списке. Найдите токен через поиск или выберите сеть.")
            XCTAssertGreaterThanOrEqual(
                discovery.migrationLabel.bounds.height + 1,
                discovery.migrationLabel.sizeThatFits(
                    CGSize(width: discovery.migrationLabel.bounds.width, height: .greatestFiniteMagnitude)
                ).height
            )
            XCTAssertGreaterThanOrEqual(discovery.searchAllButton.bounds.height, 44)
        }
        XCTAssertEqual(discovery.chipButtons.last?.titleLabel.text, "Другие сети \u{203A}")
    }

    // MARK: - The list

    func testListRoutesSearchAndChipsForTheShownWalletAndKeepsTheFieldWhenNothingIsFound() async throws {
        let (controller, output, window, defaults, suite) = try hostList()
        defer {
            close(window)
            defaults.removePersistentDomain(forName: suite)
        }
        controller.didReceive(viewModel: model(walletId: "wallet-a", rows: 2))
        await settle(window)
        let discovery = controller.rootView.discoveryView
        XCTAssertFalse(discovery.isHidden)
        XCTAssertTrue(discovery.isDescendant(of: controller.rootView.tableView), "Above the rows, scrolling with them")
        discovery.searchField.text = "dot"
        discovery.searchField.sendActions(for: .editingChanged)
        discovery.deliverPendingSearch()
        discovery.chipButtons[1].sendActions(for: .touchUpInside)
        discovery.chipButtons[2].sendActions(for: .touchUpInside)
        XCTAssertEqual(output.searches.map(\.0), ["dot"])
        XCTAssertEqual(output.networks.map(\.0), ["chain-a"])
        XCTAssertEqual(output.moreNetworks, ["wallet-a"])
        XCTAssertEqual(Set(output.searches.map(\.1) + output.networks.map(\.1)), ["wallet-a"])

        // A search that finds nothing keeps the field in the list and says so under it, with no empty page.
        var nothing = model(walletId: "wallet-a", state: .search(cells: []))
        nothing.searchText = "zzz"
        nothing.searchFoundNothing = true
        controller.didReceive(viewModel: nothing)
        await settle(window)
        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertTrue(discovery.isDescendant(of: controller.rootView.tableView))
        XCTAssertEqual(discovery.noResultsLabel.superview?.isHidden, false)

        // An action from the old wallet's chips does nothing once another wallet is shown.
        let staleSelect = discovery.onSelectNetwork
        controller.didReceive(viewModel: model(walletId: "wallet-b", rows: 2))
        staleSelect?("chain-a")
        XCTAssertEqual(output.networks.count, 1)
        discovery.onSelectNetwork?("chain-a")
        XCTAssertEqual(output.networks.last?.1, "wallet-b")

        // The search screen's list has its own field: no discovery, and its empty search keeps the empty page.
        var screen = nothing
        screen.showsDiscovery = false
        controller.didReceive(viewModel: screen)
        XCTAssertTrue(discovery.isHidden)
        XCTAssertTrue(controller.shouldDisplayEmptyState)
        XCTAssertFalse(controller.focusInlineSearch())
    }

    func testFocusingTheListSearchScrollsToItAndTheKeyboardSkipsTheSpaceUnderTheList() async throws {
        let (controller, _, window, defaults, suite) = try hostList(bottomGap: 80)
        defer {
            close(window)
            defaults.removePersistentDomain(forName: suite)
        }
        var active: [Bool] = []
        controller.onInlineSearchActiveChange = { active.append($0) }
        controller.didReceive(viewModel: model(walletId: "wallet-a", rows: 30))
        await settle(window)
        let table = controller.rootView.tableView
        table.setContentOffset(CGPoint(x: 0, y: 400), animated: false)
        XCTAssertTrue(controller.focusInlineSearch())
        XCTAssertEqual(table.contentOffset.y, -table.adjustedContentInset.top, accuracy: 0.5)
        XCTAssertTrue(controller.rootView.discoveryView.searchField.isFirstResponder)
        XCTAssertEqual(active, [true])
        // The list ends 80 pt above the window's bottom (the tab bar): only the rest of the keyboard covers it.
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(300), -80, accuracy: 0.5)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(50), -50, accuracy: 0.5)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(0), 0)
        // Opening a row lets the keyboard go first.
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertFalse(controller.rootView.discoveryView.searchField.isFirstResponder)
        XCTAssertEqual(active, [true, false])
    }

    // MARK: - The wallet header

    func testHeaderSearchButtonFocusesTheListFieldAndTheBalanceCardFoldsWhileTyping() async throws {
        let fixture = try hostWallet(width: 390, height: 844)
        defer {
            close(fixture.window)
            fixture.defaults.removePersistentDomain(forName: fixture.suite)
        }
        let layout = fixture.controller.rootView
        let field = fixture.list.rootView.discoveryView.searchField
        let headerHeight = layout.headerScrollView.frame.height
        let listTop = layout.pageViewControllerContainer.frame.minY
        XCTAssertFalse(layout.isSearchFolded)

        layout.searchButton.sendActions(for: .touchUpInside)
        await settle(fixture.window)
        XCTAssertTrue(fixture.output.actions.isEmpty, "The list's own field, not the search screen")
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertTrue(layout.isSearchFolded)
        XCTAssertLessThan(layout.headerScrollView.frame.height, headerHeight - 200)
        XCTAssertLessThan(layout.pageViewControllerContainer.frame.minY, listTop - 200, "The matches get the page")
        XCTAssertEqual(layout.sunlit.heroSurface.alpha, 0)
        XCTAssertEqual(layout.sunlit.actionsStack.alpha, 0)
        XCTAssertTrue(layout.sunlit.heroSurface.accessibilityElementsHidden)
        XCTAssertFalse(layout.headerScrollView.isScrollEnabled)
        // The wallet badge in the top row lights the page while the sun's card is folded away.
        layout.updateSunPosition()
        let badge = layout.switchWalletButton
        let badgeCenter = badge.convert(CGPoint(x: badge.bounds.midX, y: badge.bounds.midY), to: nil)
        let sun = try XCTUnwrap(FWSunAnchor.shared.centerInWindow)
        XCTAssertEqual(sun.x, badgeCenter.x, accuracy: 1)
        XCTAssertEqual(sun.y, badgeCenter.y, accuracy: 1)

        fixture.list.rootView.discoveryView.endSearchEditing()
        await settle(fixture.window)
        XCTAssertFalse(layout.isSearchFolded)
        XCTAssertEqual(layout.headerScrollView.frame.height, headerHeight, accuracy: 0.5)
        XCTAssertEqual(layout.sunlit.heroSurface.alpha, 1)
        XCTAssertFalse(layout.sunlit.heroSurface.accessibilityElementsHidden)
        layout.updateSunPosition()
        let sunBadge = layout.sunBadgeView
        let back = try XCTUnwrap(FWSunAnchor.shared.centerInWindow)
        XCTAssertEqual(back.y, sunBadge.convert(CGPoint(x: sunBadge.bounds.midX, y: sunBadge.bounds.midY), to: nil).y, accuracy: 1)

        // Another page (NFTs) keeps the search screen.
        layout.pageViewController.setViewControllers([fixture.other], direction: .forward, animated: false)
        layout.searchButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(fixture.output.actions, ["search"])
    }

    // MARK: - Fixtures

    private func model(
        walletId: String,
        state: AssetListState = .defaultList(cells: [], withAnimate: false),
        rows: Int = 0
    ) -> ChainAssetListViewModel {
        var model = ChainAssetListViewModel(displayState: state, networkSections: [])
        model.walletId = walletId
        model.showsDiscovery = true
        model.networkChips = chips
        model.tokenRows = (0 ..< rows).map { index in
            TokenGroupRowViewModel(
                model: TokenGroupRowModel(
                    id: "group:\(index)", symbol: "T\(index)", name: "Token \(index)", icon: nil, amount: 1, fiat: 0,
                    unpricedNetworkCount: 0, children: [], zeroChildren: [], isSingleNetwork: false
                ),
                amountText: "1 T\(index)",
                fiatText: nil
            )
        }
        return model
    }

    private func scene() throws -> UIWindowScene {
        try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    }

    private func host(_ view: UIView) throws -> UIWindow {
        let window = UIWindow(windowScene: try scene())
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        window.overrideUserInterfaceStyle = .dark
        let controller = UIViewController()
        controller.view.backgroundColor = FWSunlit.Palette.background
        controller.view.addSubview(view)
        view.snp.makeConstraints { make in
            make.top.equalTo(controller.view.safeAreaLayoutGuide).offset(20)
            make.leading.trailing.equalToSuperview()
        }
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

    private func hostList(
        bottomGap: CGFloat = 0
    ) throws -> (ChainAssetListViewController, OneListOutputSpy, UIWindow, UserDefaults, String) {
        let suite = "one-list-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let output = OneListOutputSpy()
        let controller = ChainAssetListViewController(
            bannersViewController: nil,
            output: output,
            keyboardAdoptable: true,
            localizationManager: LocalizationManager.shared,
            collapseStore: PortfolioCollapseStore(userDefaults: defaults)
        )
        let window = UIWindow(windowScene: try scene())
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        window.overrideUserInterfaceStyle = .dark
        let parent = UIViewController()
        parent.addChild(controller)
        parent.view.addSubview(controller.view)
        controller.view.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(bottomGap)
        }
        controller.didMove(toParent: parent)
        window.rootViewController = parent
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return (controller, output, window, defaults, suite)
    }

    private struct WalletFixture {
        let window: UIWindow
        let controller: WalletMainContainerViewController
        let list: ChainAssetListViewController
        let other: UIViewController
        let output: OneListHeaderOutputSpy
        let defaults: UserDefaults
        let suite: String
    }

    private func hostWallet(width: CGFloat, height: CGFloat) throws -> WalletFixture {
        let suite = "one-list-wallet-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let localization = LocalizationManager.shared
        let list = ChainAssetListViewController(
            bannersViewController: nil,
            output: OneListOutputSpy(),
            keyboardAdoptable: true,
            localizationManager: localization,
            collapseStore: PortfolioCollapseStore(userDefaults: defaults)
        )
        let other = UIViewController()
        let output = OneListHeaderOutputSpy()
        let controller = WalletMainContainerViewController(
            balanceInfoViewController: BalanceInfoViewController(
                output: OneListBalanceOutputSpy(),
                localizationManager: localization
            ),
            pageControllers: [list, other],
            output: output,
            localizationManager: localization
        )
        let window = UIWindow(windowScene: try scene())
        window.frame = CGRect(x: 0, y: 0, width: width, height: height)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        list.loadViewIfNeeded()
        list.didReceive(viewModel: model(walletId: "wallet-a", rows: 3))
        window.layoutIfNeeded()
        return WalletFixture(
            window: window, controller: controller, list: list, other: other,
            output: output, defaults: defaults, suite: suite
        )
    }

    private func settle(_ window: UIWindow) async {
        try? await Task.sleep(nanoseconds: 450_000_000)
        window.layoutIfNeeded()
    }

    private func close(_ window: UIWindow) {
        window.endEditing(true)
        window.isHidden = true
        window.rootViewController = nil
    }
}

private extension PortfolioNetworkChip {
    func with(selected: Bool) -> PortfolioNetworkChip {
        PortfolioNetworkChip(id: id, title: title, selected: selected)
    }
}

private final class OneListOutputSpy: ChainAssetListViewOutput {
    var searches: [(String, String)] = []
    var networks: [(String, String)] = []
    var moreNetworks: [String] = []
    var lenses: [PortfolioLens] = []
    var selectedAssets: [AssetKey] = []
    func didLoad(view _: ChainAssetListViewInput) {}
    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel) {
        selectedAssets.append(viewModel.chainAsset.assetKey)
    }

    func didTapAction(actionType _: SwipableCellButtonType, viewModel _: ChainAccountBalanceCellViewModel) {}
    func didSelectLens(_ lens: PortfolioLens, walletId _: String) { lenses.append(lens) }
    func didSearch(_ query: String, walletId: String) { searches.append((query, walletId)) }
    func didSelectNetwork(_ identifier: String, walletId: String) { networks.append((identifier, walletId)) }
    func didTapMoreNetworks(walletId: String) { moreNetworks.append(walletId) }
    func didTapTokenAction(actionType _: SwipableCellButtonType, groupId _: String, walletId _: String) {}
    func didPullToRefresh() {}
    func didTapManageAsset() {}
    func didTapHiddenAssetsNotIncluded() {}
    func didTapTestnetAssetsNotIncluded() {}
    func didTapReviewHiddenFunds() {}
    func didTapKeepHiddenFunds(assetKeys _: [AssetKey]) {}
    func didFinishManageAssetAnimate() {}
    func didTapResolveNetworkIssue(for _: ChainModel) {}
    func didTapResolveAccountIssue(for _: ChainModel) {}
}

private final class OneListBalanceOutputSpy: BalanceInfoViewOutput {
    func didLoad(view _: BalanceInfoViewInput) {}
}

private final class OneListHeaderOutputSpy: WalletMainContainerViewOutput {
    var actions: [String] = []
    func didLoad(view _: WalletMainContainerViewInput) {}
    func didTapOnSwitchWallet() { actions.append("wallet") }
    func didTapOnQR() { actions.append("qr") }
    func didTapSearch() { actions.append("search") }
    func didTapSelectNetwork() { actions.append("network") }
    func didTapOnBalance() { actions.append("balance") }
    func addressDidCopied() { actions.append("copy") }
    func didTapAccountScore() { actions.append("score") }
}
