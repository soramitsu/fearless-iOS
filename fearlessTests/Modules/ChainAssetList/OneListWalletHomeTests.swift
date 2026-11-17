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
