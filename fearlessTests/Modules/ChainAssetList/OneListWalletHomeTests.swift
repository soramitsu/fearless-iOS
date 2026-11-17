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
        XCTAssertLessThanOrEqual(
            layout.headerScrollView.contentSize.height,
            layout.headerScrollView.bounds.height + 0.5,
            "While folded the list fills the page under the top rows, and the page does not scroll"
        )
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
        XCTAssertEqual(layout.pageViewControllerContainer.frame.minY, listTop, accuracy: 0.5)
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

    // MARK: - The page: the header, then the list

    /// The walk on 2026-11-16 (one network chosen through a chip) showed the round actions partly under the list:
    /// the header was capped to leave the list 220 pt and scrolled inside that. The header and the list now scroll as
    /// one page, so at rest the list starts under the whole header, at every text size.
    func testNoPartOfTheHeaderRestsUnderTheListAtAnyTextSize() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Live text size needs trait overrides") }
        let fixture = try hostWallet(width: 402, height: 874)
        defer {
            close(fixture.window)
            fixture.defaults.removePersistentDomain(forName: fixture.suite)
        }
        // The floating tab bar keeps the page 80 pt above the home indicator, as on an iPhone 17 Pro.
        fixture.controller.additionalSafeAreaInsets.bottom = 80
        let layout = fixture.controller.rootView
        let page = layout.headerScrollView
        let categories: [UIContentSizeCategory] = [
            .large, .extraExtraExtraLarge, .accessibilityLarge, .accessibilityExtraExtraExtraLarge
        ]
        for category in categories {
            for oneNetwork in [false, true] {
                let tag = "\(category.rawValue) \(oneNetwork ? "one network" : "all networks")"
                fixture.window.traitOverrides.preferredContentSizeCategory = category
                bindHeader(fixture, oneNetwork: oneNetwork)
                page.setContentOffset(.zero, animated: false)
                await settle(fixture.window)

                let listTop = frame(of: layout.pageViewControllerContainer, in: fixture.window).minY
                for section in [layout.sunlit.heroSurface, layout.sunlit.actionsStack] {
                    XCTAssertLessThanOrEqual(frame(of: section, in: fixture.window).maxY, listTop + 0.5, tag)
                }
                XCTAssertLessThanOrEqual(frame(of: layout.contentView, in: fixture.window).maxY, listTop + 0.5, tag)
                XCTAssertEqual(layout.addressCopyableLabel.isHidden, !oneNetwork, tag)

                // Every control of the header can be scrolled into view and takes the touch there.
                var controls: [UIView] = [
                    layout.switchWalletButton, layout.searchButton, layout.scanQRButton, layout.selectNetworkButton
                ] + layout.sunlit.actionButtons
                if oneNetwork {
                    controls.append(layout.addressCopyableLabel)
                }
                for control in controls {
                    page.scrollRectToVisible(control.convert(control.bounds, to: page), animated: false)
                    fixture.window.layoutIfNeeded()
                    let shown = frame(of: control, in: fixture.window)
                    let viewport = frame(of: page, in: fixture.window)
                    XCTAssertGreaterThanOrEqual(shown.minY, viewport.minY - 0.5, tag)
                    XCTAssertLessThanOrEqual(shown.maxY, viewport.maxY + 0.5, tag)
                    let hit = fixture.window.hitTest(CGPoint(x: shown.midX, y: shown.midY), with: nil)
                    XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true, tag)
                }

                // Scrolled all the way, the header is away and the list has the whole page.
                page.setContentOffset(
                    CGPoint(x: 0, y: max(0, page.contentSize.height - page.bounds.height)),
                    animated: false
                )
                fixture.window.layoutIfNeeded()
                let list = frame(of: layout.pageViewControllerContainer, in: fixture.window)
                let viewport = frame(of: page, in: fixture.window)
                XCTAssertEqual(list.minY, viewport.minY, accuracy: 0.5, tag)
                XCTAssertEqual(list.maxY, viewport.maxY, accuracy: 0.5, tag)
            }
        }
    }

    func testAListScrolledByTheAppTakesThePageAndTheListsDragsWaitForTheHeader() async throws {
        let fixture = try hostWallet(width: 402, height: 874)
        defer {
            close(fixture.window)
            fixture.defaults.removePersistentDomain(forName: fixture.suite)
        }
        let layout = fixture.controller.rootView
        let page = layout.headerScrollView
        fixture.list.didReceive(viewModel: model(walletId: "wallet-a", rows: 40))
        bindHeader(fixture, oneNetwork: true)
        await settle(fixture.window)
        let table = fixture.list.rootView.tableView
        XCTAssertTrue(page.nestedScrollView === table, "The page follows the list it shows")
        XCTAssertTrue(
            page.gestureRecognizer(page.panGestureRecognizer, shouldRecognizeSimultaneouslyWith: table.panGestureRecognizer)
        )
        let pageMax = page.contentSize.height - page.bounds.height
        XCTAssertGreaterThan(pageMax, 0)

        // The app shows rows further down (for example after Manage assets): the header makes way.
        table.setContentOffset(CGPoint(x: 0, y: 300 - table.adjustedContentInset.top), animated: false)
        XCTAssertEqual(page.contentOffset.y, pageMax, accuracy: 0.5)
        // While the list is in its rows the page waits.
        page.contentOffset.y = pageMax / 2
        XCTAssertEqual(page.contentOffset.y, pageMax, accuracy: 0.5)
        // Back at its top, the list lets the page bring the header back.
        table.setContentOffset(CGPoint(x: 0, y: -table.adjustedContentInset.top), animated: false)
        page.setContentOffset(.zero, animated: false)
        XCTAssertEqual(page.contentOffset.y, 0, accuracy: 0.5)
        XCTAssertEqual(table.contentOffset.y, -table.adjustedContentInset.top, accuracy: 0.5)

        // A different page (NFTs) is followed instead; side by side nothing is chained.
        layout.pageViewController.setViewControllers([fixture.other], direction: .forward, animated: false)
        layout.setNeedsLayout()
        layout.layoutIfNeeded()
        XCTAssertFalse(page.nestedScrollView === table)
    }

    func testOneDragMovesEitherTheHeaderOrTheListNeverBoth() {
        typealias Chain = WalletHomeScrollChain
        let pageMax: CGFloat = 400
        // Dragging up with the header on screen: the page scrolls, the list stays at its top.
        XCTAssertEqual(Chain.resolve(.init(page: 120, list: 12), pageMax: pageMax, moved: .list), .init(page: 120, list: 0))
        // The header is away: the list scrolls.
        XCTAssertEqual(Chain.resolve(.init(page: 400, list: 30), pageMax: pageMax, moved: .list), .init(page: 400, list: 30))
        // Dragging down while the list is in its rows: the list goes back first, the page waits.
        XCTAssertEqual(Chain.resolve(.init(page: 380, list: 30), pageMax: pageMax, moved: .page), .init(page: 400, list: 30))
        // Back at its top, the page brings the header back; the list is not pulled meanwhile.
        XCTAssertEqual(Chain.resolve(.init(page: 380, list: 0), pageMax: pageMax, moved: .page), .init(page: 380, list: 0))
        XCTAssertEqual(Chain.resolve(.init(page: 380, list: -8), pageMax: pageMax, moved: .list), .init(page: 380, list: 0))
        // With the whole header shown, a pull reaches the list (pull to refresh).
        XCTAssertEqual(Chain.resolve(.init(page: 0, list: -60), pageMax: pageMax, moved: .list), .init(page: 0, list: -60))
        // Rows the app scrolled to take the page.
        XCTAssertEqual(
            Chain.resolve(.init(page: 0, list: 250), pageMax: pageMax, moved: .listProgrammatically),
            .init(page: 400, list: 250)
        )
        // A page that does not scroll (folded for a search) never holds the list.
        XCTAssertEqual(Chain.resolve(.init(page: 0, list: 90), pageMax: 0, moved: .list), .init(page: 0, list: 90))
    }

    private func bindHeader(_ fixture: WalletFixture, oneNetwork: Bool) {
        fixture.balance.didReceiveViewModel(BalanceInfoViewModel(
            dayChangeAttributedString: NSAttributedString(string: "-1.07% ($0.000811324)"),
            balanceString: "$0.0756237",
            infoButtonEnabled: false,
            filteredPartString: oneNetwork ? "Showing Solana · $0.0756237" : nil
        ))
        fixture.controller.rootView.bind(viewModel: WalletMainContainerViewModel(
            walletName: "One list walk",
            selectedFilter: oneNetwork ? "Solana" : "All networks",
            selectedFilterImage: nil,
            address: oneNetwork ? "SyntheticSo1anaAddress1111111111111111111111" : nil,
            accountScoreViewModel: nil
        ))
    }

    private func frame(of view: UIView, in window: UIWindow) -> CGRect {
        view.convert(view.bounds, to: window)
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
        let balance: BalanceInfoViewController
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
        let balance = BalanceInfoViewController(output: OneListBalanceOutputSpy(), localizationManager: localization)
        let controller = WalletMainContainerViewController(
            balanceInfoViewController: balance,
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
            window: window, controller: controller, balance: balance, list: list, other: other,
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

/// Switching away from the wallet must leave each other root's vertical scroller eligible.
@MainActor
final class MainTabRootScrollToTopTests: XCTestCase {
    func testEarnRetainsOneScrollToTopViewAfterWalletTabSwitches() async throws {
        try await assertRootScrollsToTop(.defi)
    }

    func testSwapRetainsOneScrollToTopViewWithVisibleBannersAfterWalletTabSwitches() async throws {
        try await assertRootScrollsToTop(.polkaswap)
    }

    func testTransferRetainsOneScrollToTopViewAfterWalletTabSwitches() async throws {
        try await assertRootScrollsToTop(.crossChain)
    }

    func testSettingsRetainsOneScrollToTopViewAfterWalletTabSwitches() async throws {
        try await assertRootScrollsToTop(.settings)
    }

    func testSettingsColumnsHaveOneScrollToTopView() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Trait overrides need iOS 17") }
        let controller = ProfileViewController(
            presenter: CovJUiProfilePresenterSpy(), iconGenerating: CovCUBIconGenerator(),
            localizationManager: LocalizationManager.shared
        )
        let window = try CovDFixtures.host(controller, size: CGSize(width: 1194, height: 834))
        defer { CovDFixtures.tearDown(window) }
        window.traitOverrides.userInterfaceIdiom = .pad
        window.traitOverrides.horizontalSizeClass = .regular
        await settle(window)

        XCTAssertTrue(controller.rootView.usesColumns)
        XCTAssertFalse(controller.rootView.secondaryTableView.isHidden)
        let eligible = visibleScrollToTopViews(in: window, window: window)
        XCTAssertEqual(eligible.count, 1, "The settings columns must not compete for the status-bar tap")
        XCTAssertTrue(eligible.first === controller.rootView.tableView)
    }

    private func assertRootScrollsToTop(_ destination: MainTabBarDestination) async throws {
        let localization = LocalizationManager.shared
        let suite = "tab-root-scroll-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let list = ChainAssetListViewController(
            bannersViewController: nil, output: OneListOutputSpy(), keyboardAdoptable: true,
            localizationManager: localization, collapseStore: PortfolioCollapseStore(userDefaults: defaults)
        )
        let wallet = WalletMainContainerViewController(
            balanceInfoViewController: BalanceInfoViewController(
                output: OneListBalanceOutputSpy(), localizationManager: localization
            ),
            pageControllers: [list], output: OneListHeaderOutputSpy(), localizationManager: localization
        )
        let account = CovDFixtures.wallet()
        let earn = DeFiHubViewController(
            wallet: account,
            positionsAggregator: DeFiPositionsAggregator(sources: [], explicitlyUnavailableRows: [])
        )
        let banners = BannersViewController(output: CovJBannersViewOutput(), localizationManager: localization)
        let swap = PolkaswapAdjustmentViewController(
            output: CovDAdjustmentTapSpy(), bannersViewController: banners, localizationManager: localization
        )
        let transfer = CrossChainRootViewController(wallet: account, providers: [], unavailableRouteInventory: [])
        let settings = ProfileViewController(
            presenter: CovJUiProfilePresenterSpy(), iconGenerating: CovCUBIconGenerator(),
            localizationManager: localization
        )
        let roots: [UIViewController] = [wallet, earn, swap, transfer, settings]
        let navigation = zip(MainTabBarDestination.allCases, roots).map { destination, root in
            let controller = FearlessNavigationController(rootViewController: root)
            controller.tabBarItem = MainTabBarViewFactory.createTabBarItem(for: destination)
            return controller
        }
        let tabs = MainTabBarViewController(
            viewControllers: navigation, presenter: CovDTabPresenterSpy(),
            localizationManager: localization, idiom: .phone
        )
        let window = try CovDFixtures.host(tabs)
        defer { CovDFixtures.tearDown(window) }
        await settle(window)

        for _ in 0 ..< 2 {
            tabs.select(destination: destination)
            await settle(window)
            let expected: UIScrollView
            switch destination {
            case .defi:
                expected = try XCTUnwrap(CovDFixtures.findTableView(in: earn.view))
            case .polkaswap:
                banners.didReceive(viewModel: BannersViewModelFactory().createViewModel(
                    banners: [.buyXor], locale: Locale(identifier: "en")
                ))
                await settle(window)
                XCTAssertFalse(banners.rootView.collectionView.isHidden)
                expected = swap.rootView.contentView.scrollView
            case .crossChain:
                expected = try XCTUnwrap(CovDFixtures.findTableView(in: transfer.view))
            case .settings:
                expected = settings.rootView.tableView
            case .portfolio:
                return XCTFail("This regression checks the other four tab roots")
            }
            let eligible = visibleScrollToTopViews(in: window, window: window)
            XCTAssertEqual(eligible.count, 1, "\(destination) has competing scroll views: \(eligible)")
            XCTAssertTrue(eligible.first === expected, "\(destination)'s page must receive the status-bar tap")
            tabs.select(destination: .portfolio)
            await settle(window)
        }
    }

    private func visibleScrollToTopViews(in view: UIView, window: UIWindow) -> [UIScrollView] {
        guard !view.isHidden, view.alpha > 0.01 else { return [] }
        let own = (view as? UIScrollView).map { scroll -> [UIScrollView] in
            scroll.scrollsToTop && !scroll.bounds.isEmpty && scroll.convert(scroll.bounds, to: window).intersects(window.bounds)
                ? [scroll] : []
        } ?? []
        return own + view.subviews.flatMap { visibleScrollToTopViews(in: $0, window: window) }
    }

    private func settle(_ window: UIWindow) async {
        try? await Task.sleep(nanoseconds: 450_000_000)
        window.layoutIfNeeded()
    }
}

/// Status-bar scroll to top on the wallet home: the wallet header stays outside the horizontal pager, exactly one scroll
/// view of the home is eligible in every state, and a tap brings the whole home (header and list) to its top.
@MainActor
final class HomeEmptyStateScrollToTopTests: XCTestCase {
    func testPopulatedHomeHasOnlyTheOuterPageEligibleIncludingBannersAndChips() async throws {
        let fixture = try hostWallet(showsBanners: true)
        defer { close(fixture) }
        await settle(fixture.window)

        assertOnlyOuterPageIsEligible(fixture)
        XCTAssertFalse(fixture.list.rootView.tableView.scrollsToTop)
        XCTAssertFalse(fixture.list.rootView.discoveryView.chipsScrollView.scrollsToTop)
        XCTAssertFalse(fixture.banners.rootView.collectionView.scrollsToTop)
        XCTAssertFalse(fixture.banners.view.isHidden)
        XCTAssertTrue(fixture.wallet.rootView.headerScrollView.nestedScrollView === fixture.list.rootView.tableView)
        assertHeaderOutsidePager(fixture)
    }

    func testStatusBarRequestReturnsBothDeepAssetOffsetsAndRevealsHeaderAndFirstRow() async throws {
        let fixture = try hostWallet()
        defer { close(fixture) }
        await settle(fixture.window)
        let table = fixture.list.rootView.tableView
        scrollDeep(fixture, list: table)
        XCTAssertGreaterThan(fixture.wallet.rootView.headerScrollView.contentOffset.y, 100)
        XCTAssertGreaterThan(table.contentOffset.y + table.adjustedContentInset.top, 500)
        capture(fixture.window, name: "home-assets-deep-scroll")

        requestScrollToTop(fixture)
        fixture.window.layoutIfNeeded()
        capture(fixture.window, name: "home-assets-after-scroll-to-top")
        assertAtTop(fixture, list: table)
        assertOnlyOuterPageIsEligible(fixture)
        assertHeaderTakesTouches(fixture)
        let row = table.convert(table.rectForRow(at: IndexPath(row: 0, section: 0)), to: fixture.window)
        XCTAssertTrue(row.intersects(fixture.window.bounds), "The first asset row returns with the wallet header")
        XCTAssertTrue(table.indexPathsForVisibleRows?.contains(IndexPath(row: 0, section: 0)) == true)
    }

    func testNftGridAndListReturnBothOffsetsAfterEveryAppearanceSwitch() async throws {
        let fixture = try hostWallet()
        defer { close(fixture) }
        fixture.wallet.didSelect(1)
        await settle(fixture.window)

        for appearance in [NftCollectionAppearance.collection, .table, .collection] {
            let list = selectNftAppearance(appearance, fixture: fixture)
            await settle(fixture.window)
            assertOnlyOuterPageIsEligible(fixture)
            XCTAssertTrue(fixture.wallet.rootView.headerScrollView.nestedScrollView === list)
            scrollDeep(fixture, list: list)
            XCTAssertGreaterThan(list.contentOffset.y + list.adjustedContentInset.top, 500)
            let name = appearance == .table ? "list" : "grid"
            capture(fixture.window, name: "home-nft-\(name)-deep-scroll")

            requestScrollToTop(fixture)
            fixture.window.layoutIfNeeded()
            capture(fixture.window, name: "home-nft-\(name)-after-scroll-to-top")
            assertAtTop(fixture, list: list)
            assertHeaderTakesTouches(fixture)
            if appearance == .table {
                XCTAssertTrue(fixture.nft.rootView.tableView.indexPathsForVisibleRows?.contains(IndexPath(row: 0, section: 0)) == true)
            } else {
                XCTAssertTrue(fixture.nft.rootView.collectionView.indexPathsForVisibleItems.contains(IndexPath(item: 0, section: 0)))
            }
        }
    }

    func testEmptyErrorSearchAndRepeatedDeliveriesKeepOnlyTheOuterPageEligible() async throws {
        let fixture = try hostWallet()
        defer { close(fixture) }
        let chain = CovDFixtures.soraChain(nodeURL: nil)
        let states: [(AssetListState, Int)] = [
            (.defaultList(cells: [], withAnimate: false), 40),
            (.chainHasNetworkIssue(chain: chain), 0),
            (.chainHasNetworkIssue(chain: chain), 0),
            (.chainHasAccountIssue(chain: chain), 0),
            (.allIsHidden, 0),
            (.defaultList(cells: [], withAnimate: false), 0),
            (.search(cells: []), 0),
            (.defaultList(cells: [], withAnimate: false), 40)
        ]

        for (state, rows) in states {
            fixture.list.didReceive(viewModel: model(state: state, rows: rows))
            await settle(fixture.window)
            assertOnlyOuterPageIsEligible(fixture)
            assertHeaderOutsidePager(fixture)
            // An empty state covers the list: the page follows (and resets) the scroll view on screen.
            let active = try XCTUnwrap(scrollAncestor(of: fixture.list.rootView.discoveryView))
            XCTAssertTrue(fixture.wallet.rootView.headerScrollView.nestedScrollView === active)
            let page = fixture.wallet.rootView.headerScrollView
            page.setContentOffset(CGPoint(x: 0, y: max(0, page.contentSize.height - page.bounds.height)), animated: false)
            active.setContentOffset(CGPoint(x: 0, y: 120 - active.adjustedContentInset.top), animated: false)
            requestScrollToTop(fixture)
            assertAtTop(fixture, list: active)
            assertHeaderTakesTouches(fixture)

            // Banner/localization deliveries may resize the list header but never move the wallet header into it.
            fixture.list.reloadBanners()
            fixture.list.applyLocalization()
            await settle(fixture.window)
            assertOnlyOuterPageIsEligible(fixture)
            assertHeaderOutsidePager(fixture)
            assertHeaderTakesTouches(fixture)
        }
    }

    func testNftLoadingEmptyAndPopulatedModesKeepOnlyTheOuterPageEligible() async throws {
        let fixture = try hostWallet()
        defer { close(fixture) }
        fixture.wallet.didSelect(1)
        await settle(fixture.window)
        let populated = CovHNftCellModels.sections(chain: CovHNftFixtures.chain(), count: 32)
        let deliveries: [[NftNetworkSectionModel]?] = [nil, [], populated, [], populated]

        for delivery in deliveries {
            fixture.nft.didReceive(viewModels: delivery)
            for appearance in [NftCollectionAppearance.table, .collection] {
                let active = selectNftAppearance(appearance, fixture: fixture)
                await settle(fixture.window)
                assertOnlyOuterPageIsEligible(fixture)
                assertHeaderOutsidePager(fixture)
                XCTAssertTrue(fixture.wallet.rootView.headerScrollView.nestedScrollView === active)
            }
        }
    }

    func testNftModeChangeImmediatelyBeforeStatusBarRequestUsesTheNewList() async throws {
        let fixture = try hostWallet()
        defer { close(fixture) }
        fixture.wallet.didSelect(1)
        await settle(fixture.window)
        let grid = fixture.nft.rootView.collectionView
        let table = fixture.nft.rootView.tableView
        scrollDeep(fixture, list: grid)
        table.setContentOffset(CGPoint(x: 0, y: 600 - table.adjustedContentInset.top), animated: false)

        _ = selectNftAppearance(.table, fixture: fixture)
        requestScrollToTop(fixture)
        assertAtTop(fixture, list: table)
        XCTAssertTrue(fixture.wallet.rootView.headerScrollView.nestedScrollView === table)

        scrollDeep(fixture, list: table)
        _ = selectNftAppearance(.collection, fixture: fixture)
        requestScrollToTop(fixture)
        assertAtTop(fixture, list: grid)
        XCTAssertTrue(fixture.wallet.rootView.headerScrollView.nestedScrollView === grid)
    }

    func testCurrenciesNftSwitchKeepsHeaderStationaryDuringAndAfterTheSlide() async throws {
        let fixture = try hostWallet()
        defer { close(fixture) }
        await settle(fixture.window)
        let layout = fixture.wallet.rootView
        let headerFrame = layout.contentView.convert(layout.contentView.bounds, to: fixture.window)
        let pagerFrame = layout.pageViewControllerContainer.convert(layout.pageViewControllerContainer.bounds, to: fixture.window)

        for index in [1, 0] {
            fixture.wallet.didSelect(index)
            try await Task.sleep(nanoseconds: 80_000_000)
            fixture.window.layoutIfNeeded()
            capture(
                fixture.window,
                name: index == 1 ? "home-currencies-to-nft-mid-transition" : "home-nft-to-currencies-mid-transition",
                afterScreenUpdates: false
            )
            assertHeaderOutsidePager(fixture)
            let movingHeader = layout.contentView.convert(layout.contentView.bounds, to: fixture.window)
            XCTAssertEqual(movingHeader.minX, headerFrame.minX, accuracy: 0.5)
            XCTAssertEqual(movingHeader.minY, headerFrame.minY, accuracy: 0.5)
            XCTAssertEqual(movingHeader.width, headerFrame.width, accuracy: 0.5)
            XCTAssertEqual(layout.pageViewControllerContainer.convert(CGPoint.zero, to: fixture.window).y, pagerFrame.minY, accuracy: 0.5)
            assertOnlyOuterPageIsEligible(fixture)

            await settle(fixture.window)
            assertHeaderOutsidePager(fixture)
            assertHeaderTakesTouches(fixture)
            assertOnlyOuterPageIsEligible(fixture)
            let active: UIScrollView = index == 0 ? fixture.list.rootView.tableView : fixture.nft.rootView.collectionView
            XCTAssertTrue(layout.headerScrollView.nestedScrollView === active)
            scrollDeep(fixture, list: active)
            requestScrollToTop(fixture)
            assertAtTop(fixture, list: active)
        }
    }

    /// Side by side the list scrolls on its own beside the header, which seldom scrolls: the list takes the tap. On
    /// the page (the iPad column, compact width) the page takes it and brings the list with it.
    func testIpadSplitColumnAndCompactResizesKeepOneOwnerAndResetTheShownList() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Trait overrides need iOS 17") }
        let fixture = try hostWallet(size: CGSize(width: 1194, height: 834))
        defer { close(fixture) }
        fixture.window.traitOverrides.userInterfaceIdiom = .pad

        for index in [0, 1] {
            fixture.wallet.didSelect(index)
            await settle(fixture.window)
            for width in [CGFloat(1194), 800, 390, 1194] {
                fixture.window.traitOverrides.horizontalSizeClass = width == 390 ? .compact : .regular
                fixture.window.frame.size = CGSize(width: width, height: 834)
                fixture.wallet.view.setNeedsLayout()
                await settle(fixture.window)
                let layout = fixture.wallet.rootView
                let page = layout.headerScrollView
                let active: UIScrollView = index == 0 ? fixture.list.rootView.tableView : fixture.nft.rootView.collectionView
                assertSoleScrollToTop(fixture, is: width == 1194 ? active : page)
                assertHeaderOutsidePager(fixture)
                XCTAssertEqual(layout.contentView.bounds.width, page.bounds.width, accuracy: 0.5)
                if width == 1194 {
                    XCTAssertNil(page.nestedScrollView, "Split columns retain independent drag behavior")
                    let header = page.convert(page.bounds, to: fixture.window)
                    let list = layout.pageViewControllerContainer.convert(layout.pageViewControllerContainer.bounds, to: fixture.window)
                    XCTAssertLessThanOrEqual(header.maxX, list.minX)
                    XCTAssertEqual(page.contentOffset.y, -page.adjustedContentInset.top, accuracy: 0.5)
                } else {
                    XCTAssertTrue(page.nestedScrollView === active)
                }
                active.setContentOffset(CGPoint(x: 0, y: 600 - active.adjustedContentInset.top), animated: false)
                requestScrollToTop(fixture, x: active.convert(active.bounds, to: fixture.window).midX)
                assertAtTop(fixture, list: active)
                assertHeaderTakesTouches(fixture)
            }
        }
    }

    /// A list scrolled side by side keeps its place when the window narrows to the column, and the header makes way
    /// for its rows. The width change leaves the table's top rows estimated: brought to its top it measures them and
    /// shifts itself, which must not leave the page held with the header away.
    func testListScrolledSideBySideReturnsWithTheHeaderAfterNarrowingToTheColumn() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Trait overrides need iOS 17") }
        let fixture = try hostWallet(size: CGSize(width: 1194, height: 834))
        defer { close(fixture) }
        fixture.window.traitOverrides.userInterfaceIdiom = .pad
        fixture.window.traitOverrides.horizontalSizeClass = .regular
        await settle(fixture.window)
        let page = fixture.wallet.rootView.headerScrollView
        let table = fixture.list.rootView.tableView
        table.setContentOffset(CGPoint(x: 0, y: 600 - table.adjustedContentInset.top), animated: false)

        fixture.window.frame.size = CGSize(width: 800, height: 834)
        fixture.wallet.view.setNeedsLayout()
        await settle(fixture.window)
        XCTAssertTrue(page.nestedScrollView === table)
        XCTAssertGreaterThan(page.contentOffset.y, 100, "The header made way for the list's rows")
        XCTAssertGreaterThan(table.contentOffset.y + table.adjustedContentInset.top, 500)
        assertOnlyOuterPageIsEligible(fixture)

        requestScrollToTop(fixture)
        assertAtTop(fixture, list: table)
        assertOnlyOuterPageIsEligible(fixture)
        assertHeaderTakesTouches(fixture)
    }

    /// Folded for a search the page cannot scroll: the matches take the tap. When the keyboard goes with the matches
    /// scrolled, the header makes way for them and the page takes the tap again, bringing the matches with it.
    func testSearchMatchesTakeTheTapWhileFoldedAndThePageAfterUnfolding() async throws {
        let fixture = try hostWallet()
        defer { close(fixture) }
        await settle(fixture.window)
        let layout = fixture.wallet.rootView
        let table = fixture.list.rootView.tableView

        layout.setSearchFocused(true, animated: false)
        await settle(fixture.window)
        XCTAssertTrue(layout.isSearchFolded)
        table.setContentOffset(CGPoint(x: 0, y: 300 - table.adjustedContentInset.top), animated: false)
        assertSoleScrollToTop(fixture, is: table)
        requestScrollToTop(fixture)
        assertAtTop(fixture, list: table)
        assertOnlyOuterPageIsEligible(fixture)

        table.setContentOffset(CGPoint(x: 0, y: 300 - table.adjustedContentInset.top), animated: false)
        layout.setSearchFocused(false, animated: false)
        await settle(fixture.window)
        XCTAssertFalse(layout.isSearchFolded)
        XCTAssertGreaterThan(table.contentOffset.y + table.adjustedContentInset.top, 200, "Unfolding keeps the matches' place")
        assertOnlyOuterPageIsEligible(fixture)
        requestScrollToTop(fixture)
        assertAtTop(fixture, list: table)
        assertOnlyOuterPageIsEligible(fixture)
        assertHeaderTakesTouches(fixture)
    }

    func testTheTapGoesToThePageUnlessThePageRestsAtItsTopAboveScrolledRows() {
        typealias Chain = WalletHomeScrollChain
        // The header has scrolled away (the list's rows may be scrolled too): the page, which resets the list.
        XCTAssertEqual(Chain.scrollToTopTarget(.init(page: 400, list: 900)), .page)
        XCTAssertEqual(Chain.scrollToTopTarget(.init(page: 400, list: 0)), .page)
        XCTAssertEqual(Chain.scrollToTopTarget(.init(page: 120, list: 0)), .page)
        // Everything at its top, or the list pulled down to refresh: nothing to scroll, the page keeps it.
        XCTAssertEqual(Chain.scrollToTopTarget(.init(page: 0, list: 0)), .page)
        XCTAssertEqual(Chain.scrollToTopTarget(.init(page: 0, list: -60)), .page)
        // The page rests at its top above scrolled rows (folded, unfolded, rotated): only the list can move up.
        XCTAssertEqual(Chain.scrollToTopTarget(.init(page: 0, list: 300)), .list)
        XCTAssertEqual(Chain.scrollToTopTarget(.init(page: 0.4, list: 300)), .list)
    }

    /// The status bar's own handler, as a tap on it calls it on iOS 27: UIKit's choice among the home's scroll views,
    /// not a model of it. Compact width only (the tap's x is a screen position on the test's iPhone).
    func testStatusBarHandlerReturnsTheWholeHomeToItsTop() async throws {
        let fixture = try hostWallet()
        defer { close(fixture) }
        await settle(fixture.window)
        let layout = fixture.wallet.rootView
        let page = layout.headerScrollView
        let table = fixture.list.rootView.tableView
        let x = fixture.window.bounds.midX

        // The header away and the rows deep.
        scrollDeep(fixture, list: table)
        capture(fixture.window, name: "uikit-assets-deep-scroll")
        try await tapStatusBar(fixture.window, x: x) { atTop(page, table) }
        capture(fixture.window, name: "uikit-assets-after-status-bar-tap")
        assertAtTop(fixture, list: table)
        assertHeaderTakesTouches(fixture)

        // Folded for a search, the matches scrolled: the list itself takes the tap.
        layout.setSearchFocused(true, animated: false)
        await settle(fixture.window)
        table.setContentOffset(CGPoint(x: 0, y: 300 - table.adjustedContentInset.top), animated: false)
        try await tapStatusBar(fixture.window, x: x) { atTop(page, table) }
        assertAtTop(fixture, list: table)

        // Unfolded with the matches scrolled: the header made way, the page takes the tap and brings them.
        table.setContentOffset(CGPoint(x: 0, y: 300 - table.adjustedContentInset.top), animated: false)
        layout.setSearchFocused(false, animated: false)
        await settle(fixture.window)
        try await tapStatusBar(fixture.window, x: x) { atTop(page, table) }
        assertAtTop(fixture, list: table)

        // The NFT grid, header away and items deep.
        fixture.wallet.didSelect(1)
        await settle(fixture.window)
        let grid = fixture.nft.rootView.collectionView
        scrollDeep(fixture, list: grid)
        capture(fixture.window, name: "uikit-nft-deep-scroll")
        try await tapStatusBar(fixture.window, x: x) { atTop(page, grid) }
        capture(fixture.window, name: "uikit-nft-after-status-bar-tap")
        assertAtTop(fixture, list: grid)
        assertHeaderTakesTouches(fixture)
    }

    func testReturningToTopKeepsRefreshControlAndHeaderLaunchTiers() async throws {
        let fixture = try hostWallet()
        defer { close(fixture) }
        await settle(fixture.window)
        let layout = fixture.wallet.rootView
        let table = fixture.list.rootView.tableView
        let refresh = try XCTUnwrap(table.refreshControl)
        scrollDeep(fixture, list: table)
        requestScrollToTop(fixture)
        assertAtTop(fixture, list: table)
        // Back at the top a pull reaches the list again (pull to refresh).
        table.setContentOffset(CGPoint(x: 0, y: -table.adjustedContentInset.top - 60), animated: false)
        XCTAssertEqual(layout.headerScrollView.contentOffset.y, 0, accuracy: 0.5)
        XCTAssertLessThan(table.contentOffset.y, 0)
        refresh.sendActions(for: .valueChanged)
        XCTAssertFalse(refresh.isRefreshing)
        XCTAssertTrue(table.refreshControl === refresh)

        let tiers = fixture.wallet.flightTiers
        XCTAssertEqual(tiers.first(where: { $0.view === layout.sunlit.heroSurface })?.tier, 0)
        XCTAssertEqual(tiers.first(where: { $0.view === layout.sunlit.actionsStack })?.tier, 1)
        for tier in tiers where tier.tier < 3 {
            XCTAssertFalse(tier.view.isDescendant(of: layout.pageViewControllerContainer), "Header launch tiers remain outside the tier-4 list")
        }
        XCTAssertTrue(fixture.balance.parent === fixture.wallet)
    }

    // MARK: - Hosted fixture and the scroll-to-top contract

    private struct Fixture {
        let window: UIWindow
        let wallet: WalletMainContainerViewController
        let balance: BalanceInfoViewController
        let list: ChainAssetListViewController
        let nft: MainNftContainerViewController
        let banners: BannersViewController
        let defaults: UserDefaults
        let suite: String
    }

    private func hostWallet(size: CGSize = CGSize(width: 402, height: 874), showsBanners: Bool = false) throws -> Fixture {
        let suite = "home-outer-scroll-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let localization = LocalizationManager.shared
        let banners = BannersViewController(output: CovJBannersViewOutput(), localizationManager: localization)
        let list = ChainAssetListViewController(
            bannersViewController: showsBanners ? banners : nil, output: OneListOutputSpy(), keyboardAdoptable: true,
            localizationManager: localization, collapseStore: PortfolioCollapseStore(userDefaults: defaults)
        )
        let nft = MainNftContainerViewController(output: CovHNftMainViewOutputSpy(), localizationManager: localization)
        let balance = BalanceInfoViewController(output: OneListBalanceOutputSpy(), localizationManager: localization)
        let wallet = WalletMainContainerViewController(
            balanceInfoViewController: balance, pageControllers: [list, nft],
            output: OneListHeaderOutputSpy(), localizationManager: localization
        )
        let window = try CovDFixtures.host(wallet, size: size)
        window.overrideUserInterfaceStyle = .dark
        wallet.didReceiveNftAvailability(isNftAvailable: true)
        balance.didReceiveViewModel(BalanceInfoViewModel(
            dayChangeAttributedString: NSAttributedString(string: "+0%"), balanceString: "$12.00",
            infoButtonEnabled: false, filteredPartString: nil
        ))
        wallet.rootView.bind(viewModel: WalletMainContainerViewModel(
            walletName: "Scroll test wallet", selectedFilter: "All networks", selectedFilterImage: nil,
            address: nil, accountScoreViewModel: nil
        ))
        list.didReceive(viewModel: model(rows: 60))
        nft.loadViewIfNeeded()
        nft.didReceive(viewModels: CovHNftCellModels.sections(chain: CovHNftFixtures.chain(), count: 32))
        if showsBanners {
            banners.didReceive(viewModel: BannersViewModelFactory().createViewModel(banners: [.buyXor], locale: Locale(identifier: "en")))
        }
        window.layoutIfNeeded()
        return Fixture(window: window, wallet: wallet, balance: balance, list: list, nft: nft, banners: banners, defaults: defaults, suite: suite)
    }

    private func model(state: AssetListState = .defaultList(cells: [], withAnimate: false), rows: Int) -> ChainAssetListViewModel {
        var model = ChainAssetListViewModel(displayState: state, networkSections: [])
        model.walletId = "home-outer-scroll-wallet"
        model.showsDiscovery = true
        model.networkChips = [
            PortfolioNetworkChip(id: "all", title: "All networks", selected: true),
            PortfolioNetworkChip(id: "network", title: "Test network", selected: false)
        ]
        model.tokenRows = (0 ..< rows).map { index in
            TokenGroupRowViewModel(
                model: TokenGroupRowModel(
                    id: "outer-scroll:\(index)", symbol: "T\(index)", name: "Token \(index)", icon: nil,
                    amount: 1, fiat: 0, unpricedNetworkCount: 0, children: [], zeroChildren: [], isSingleNetwork: false
                ),
                amountText: "1 T\(index)", fiatText: nil
            )
        }
        return model
    }

    private func selectNftAppearance(_ appearance: NftCollectionAppearance, fixture: Fixture) -> UIScrollView {
        switch appearance {
        case .collection:
            fixture.nft.rootView.nftContentControl.collectionButton.sendActions(for: .touchUpInside)
            return fixture.nft.rootView.collectionView
        case .table:
            fixture.nft.rootView.nftContentControl.tableButton.sendActions(for: .touchUpInside)
            return fixture.nft.rootView.tableView
        }
    }

    private func scrollDeep(_ fixture: Fixture, list: UIScrollView) {
        let page = fixture.wallet.rootView.headerScrollView
        page.setContentOffset(CGPoint(x: 0, y: max(0, page.contentSize.height - page.bounds.height)), animated: false)
        list.setContentOffset(CGPoint(x: 0, y: 1200 - list.adjustedContentInset.top), animated: false)
        fixture.window.layoutIfNeeded()
    }

    /// A model of UIKit's handling of a status-bar tap (measured through the status bar's own handler on iOS 27 and
    /// 18.4): only visible eligible scroll views under the tap's x position that can still move up are candidates; the
    /// candidate's delegate is asked, then it scrolls to its top and is told. With several candidates UIKit's choice
    /// depends on the hierarchy (a nested pair goes to the inner one, the base home's competing views scrolled nothing),
    /// so the model takes the innermost and the home tests require exactly one eligible view.
    private func requestScrollToTop(_ fixture: Fixture, x: CGFloat? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let tapX = x ?? fixture.window.bounds.midX
        let candidates = visibleScrollToTopViews(in: fixture.window, window: fixture.window).filter { scroll in
            let frame = scroll.convert(scroll.bounds, to: fixture.window)
            return frame.minX <= tapX && tapX < frame.maxX && scroll.contentOffset.y > -scroll.adjustedContentInset.top + 0.5
        }
        let depth: (UIView) -> Int = { view in Array(sequence(first: view, next: { $0.superview })).count }
        guard let target = candidates.max(by: { depth($0) < depth($1) }) else { return }
        let allowed = target.delegate?.scrollViewShouldScrollToTop?(target) ?? true
        XCTAssertTrue(allowed, file: file, line: line)
        if allowed {
            target.setContentOffset(CGPoint(x: target.contentOffset.x, y: -target.adjustedContentInset.top), animated: false)
            target.delegate?.scrollViewDidScrollToTop?(target)
        }
    }

    private func atTop(_ scrollViews: UIScrollView...) -> Bool {
        scrollViews.allSatisfy { abs($0.contentOffset.y + $0.adjustedContentInset.top) <= 0.5 }
    }

    /// Calls the status bar's scroll-to-top handler of the window's scene with the tap's x position, then waits for
    /// UIKit's animated scroll to finish.
    private func tapStatusBar(
        _ window: UIWindow, x: CGFloat, until settled: () -> Bool,
        file: StaticString = #filePath, line: UInt = #line
    ) async throws {
        let manager = try XCTUnwrap(window.windowScene?.statusBarManager, file: file, line: line)
        let selector = NSSelectorFromString("_handleScrollToTopAtXPosition:")
        guard manager.responds(to: selector) else { throw XCTSkip("This iOS has no status-bar scroll-to-top handler") }
        typealias Handler = @convention(c) (AnyObject, Selector, Double) -> Void
        unsafeBitCast(manager.method(for: selector), to: Handler.self)(manager, selector, Double(x))
        let deadline = Date().addingTimeInterval(5)
        while !settled(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        window.layoutIfNeeded()
    }

    private func assertAtTop(_ fixture: Fixture, list: UIScrollView, file: StaticString = #filePath, line: UInt = #line) {
        let page = fixture.wallet.rootView.headerScrollView
        XCTAssertEqual(page.contentOffset.y, -page.adjustedContentInset.top, accuracy: 0.5, file: file, line: line)
        XCTAssertEqual(list.contentOffset.y, -list.adjustedContentInset.top, accuracy: 0.5, file: file, line: line)
    }

    private func assertSoleScrollToTop(_ fixture: Fixture, is expected: UIScrollView, file: StaticString = #filePath, line: UInt = #line) {
        let eligible = visibleScrollToTopViews(in: fixture.window, window: fixture.window)
        XCTAssertEqual(eligible.count, 1, "Competing home scrollers: \(eligible)", file: file, line: line)
        XCTAssertTrue(eligible.first === expected, "\(String(describing: eligible.first)) instead of \(expected)", file: file, line: line)
    }

    private func assertOnlyOuterPageIsEligible(_ fixture: Fixture, file: StaticString = #filePath, line: UInt = #line) {
        assertSoleScrollToTop(fixture, is: fixture.wallet.rootView.headerScrollView, file: file, line: line)
    }

    private func assertHeaderOutsidePager(_ fixture: Fixture, file: StaticString = #filePath, line: UInt = #line) {
        let layout = fixture.wallet.rootView
        XCTAssertTrue(layout.contentView.superview === layout.headerScrollView, file: file, line: line)
        XCTAssertFalse(layout.contentView.isDescendant(of: layout.pageViewControllerContainer), file: file, line: line)
        XCTAssertTrue(fixture.balance.parent === fixture.wallet, file: file, line: line)
    }

    private func assertHeaderTakesTouches(_ fixture: Fixture, file: StaticString = #filePath, line: UInt = #line) {
        let button = fixture.wallet.rootView.switchWalletButton
        let point = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: fixture.window)
        XCTAssertTrue(fixture.window.bounds.contains(point), file: file, line: line)
        let hit = fixture.window.hitTest(point, with: nil)
        XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true, "The header stays visible and tappable", file: file, line: line)
    }

    private func visibleScrollToTopViews(in view: UIView, window: UIWindow) -> [UIScrollView] {
        guard !view.isHidden, view.alpha > 0.01 else { return [] }
        let own = (view as? UIScrollView).map { scroll -> [UIScrollView] in
            scroll.scrollsToTop && !scroll.bounds.isEmpty && scroll.convert(scroll.bounds, to: window).intersects(window.bounds)
                ? [scroll] : []
        } ?? []
        return own + view.subviews.flatMap { visibleScrollToTopViews(in: $0, window: window) }
    }

    private func scrollAncestor(of view: UIView) -> UIScrollView? {
        var ancestor = view.superview
        while let current = ancestor {
            if let scroll = current as? UIScrollView { return scroll }
            ancestor = current.superview
        }
        return nil
    }

    private func capture(_ window: UIWindow, name: String, afterScreenUpdates: Bool = true) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: afterScreenUpdates)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func settle(_ window: UIWindow) async {
        try? await Task.sleep(nanoseconds: 450_000_000)
        window.layoutIfNeeded()
    }

    private func close(_ fixture: Fixture) {
        fixture.window.endEditing(true)
        CovDFixtures.tearDown(fixture.window)
        fixture.defaults.removePersistentDomain(forName: fixture.suite)
    }
}
