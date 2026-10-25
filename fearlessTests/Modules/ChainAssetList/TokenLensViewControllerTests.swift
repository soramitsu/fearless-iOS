import XCTest
import UIKit
import SSFModels
import SoraFoundation
import SoraUI
@testable import fearless

final class TokenLensViewControllerTests: XCTestCase {
    @MainActor
    func testSingletonStaysFlatAndKeepsNetworkAndTrustLabel() throws {
        let (model, _) = try fixture(single: true)
        let output = TokenLensOutputSpy()
        let controller = ChainAssetListViewController(
            bannersViewController: nil,
            output: output,
            keyboardAdoptable: false,
            localizationManager: LocalizationManager.shared
        )
        let window = try host(controller)
        defer { window.isHidden = true }
        controller.didReceive(viewModel: model)
        let table = controller.rootView.tableView
        let cell = try XCTUnwrap(
            controller
                .tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? ChainAccountBalanceTableCell
        )
        XCTAssertEqual(cell.cloudViewEdgeInsets.left, UIConstants.bigOffset)
        var pending: [UIView] = [cell]
        var labels: [String] = []
        while let next = pending.popLast() {
            if let label = next as? UILabel, let text = label.text { labels.append(text) }
            pending += next.subviews
        }
        let member = try XCTUnwrap(model.tokenRows.first?.model.children.first)
        XCTAssertTrue(labels.contains { $0.contains(member.networkName) && $0.contains("VERIFIED") })
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(output.selectedAssets, [member.chainAsset.assetKey])
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 1)
    }

    @MainActor
    func testPartialAndUnavailableGroupPricesRemainExplicit() throws {
        let (model, _) = try fixture()
        let original = try XCTUnwrap(model.tokenRows.first)
        let partial = TokenGroupRowModel(
            id: original.model.id,
            symbol: original.model.symbol,
            name: original.model.name,
            icon: nil,
            amount: 2,
            fiat: 1,
            unpricedNetworkCount: 1,
            children: original.model.children,
            zeroChildren: original.model.zeroChildren,
            isSingleNetwork: false
        )
        let cell = TokenGroupBalanceTableCell(style: .default, reuseIdentifier: nil)
        cell.bind(
            TokenGroupRowViewModel(model: partial, amountText: "2 USDT", fiatText: "$1.00"),
            expanded: false,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(cell.pricingLabel.text, "Networks without a price: 1")
        XCTAssertFalse(cell.pricingLabel.isHidden)
        cell.bind(
            TokenGroupRowViewModel(model: partial, amountText: "2 USDT", fiatText: nil),
            expanded: false,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(cell.fiatLabel.text, "Price unavailable")
        XCTAssertTrue(cell.pricingLabel.isHidden)
    }

    @MainActor
    func testExpandInsertsExactChildRowsAndKeepsZeroNetworksCollapsed() throws {
        let (model, _) = try fixture()
        let output = TokenLensOutputSpy()
        let controller = ChainAssetListViewController(
            bannersViewController: nil,
            output: output,
            keyboardAdoptable: false,
            localizationManager: LocalizationManager.shared
        )
        let window = try host(controller)
        defer { window.isHidden = true }
        controller.didReceive(viewModel: model)
        let table = controller.rootView.tableView
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 1)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 4)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(output.selectedAssets, [model.tokenRows[0].model.children[0].chainAsset.assetKey])
        controller.tableView(table, didSelectRowAt: IndexPath(row: 3, section: 0))
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 5)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 4, section: 0))
        XCTAssertEqual(output.selectedAssets.last, model.tokenRows[0].model.zeroChildren[0].chainAsset.assetKey)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 1)
    }

    @MainActor
    func testLensAndExpansionPersistPerWalletAndStaleCellActionsAreRejected() throws {
        let suite = "token-lens-test-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PortfolioCollapseStore(userDefaults: defaults)
        let (model, _) = try fixture()
        let output = TokenLensOutputSpy()
        let controller = ChainAssetListViewController(
            bannersViewController: nil,
            output: output,
            keyboardAdoptable: false,
            localizationManager: LocalizationManager.shared,
            collapseStore: store
        )
        let window = try host(controller)
        defer { window.isHidden = true }
        controller.didReceive(viewModel: model)
        let table = controller.rootView.tableView
        let oldCell = try XCTUnwrap(
            controller
                .tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? TokenGroupBalanceTableCell
        )
        let oldAction = oldCell.onAction
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(
            store.identifiers(walletId: try XCTUnwrap(model.walletId), kind: "token"),
            [model.tokenRows[0].model.id]
        )
        controller.rootView.lensControl.selectedSegmentIndex = 1
        controller.rootView.lensControl.sendActions(for: .valueChanged)
        XCTAssertEqual(output.lenses, [.network])
        XCTAssertEqual(store.lens(walletId: try XCTUnwrap(model.walletId)), .network)
        var other = model
        other.walletId = "other-wallet"
        controller.didReceive(viewModel: other)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(store.lens(walletId: "other-wallet"), .token)
        controller.didReceive(viewModel: model)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 4)
        oldAction?(.receive)
        XCTAssertTrue(output.groupActions.isEmpty, "A→B→A must not revive an old cell's action")
    }

    @MainActor
    func testOldNetworkHeaderCannotChangeAnotherWalletOrReviveAfterReturn() throws {
        var (model, _) = try fixture()
        model.lens = .network
        let suite = "network-header-scope-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PortfolioCollapseStore(userDefaults: defaults)
        let controller = ChainAssetListViewController(
            bannersViewController: nil,
            output: TokenLensOutputSpy(),
            keyboardAdoptable: false,
            localizationManager: LocalizationManager.shared,
            collapseStore: store
        )
        let window = try host(controller)
        defer { window.isHidden = true }
        controller.didReceive(viewModel: model)
        let table = controller.rootView.tableView
        let header = try XCTUnwrap(controller.tableView(table, viewForHeaderInSection: 0) as? AssetNetworkHeaderView)
        let staleAction = header.onTap
        let walletId = try XCTUnwrap(model.walletId)
        let before = controller.tableView(table, numberOfRowsInSection: 0)
        var other = model
        other.walletId = "another-wallet"
        controller.didReceive(viewModel: other)
        staleAction?()
        XCTAssertTrue(store.identifiers(walletId: "another-wallet", kind: "network").isEmpty)
        controller.didReceive(viewModel: model)
        staleAction?()
        XCTAssertTrue(store.identifiers(walletId: walletId, kind: "network").isEmpty)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), before)
        let current = try XCTUnwrap(controller.tableView(table, viewForHeaderInSection: 0) as? AssetNetworkHeaderView)
        current.onTap?()
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        XCTAssertFalse(store.identifiers(walletId: walletId, kind: "network").isEmpty)
    }

    @MainActor
    func testGroupAccessibilityExposesActionsAndPartialPricing() throws {
        let (model, _) = try fixture()
        let row = try XCTUnwrap(model.tokenRows.first)
        let cell = TokenGroupBalanceTableCell(style: .default, reuseIdentifier: nil)
        cell.bind(row, expanded: false, locale: Locale(identifier: "en"))
        XCTAssertEqual(cell.accessibilityCustomActions?.map(\.name), ["Expand", "Send", "Receive", "Hide"])
        XCTAssertTrue(cell.accessibilityLabel?.contains("Networks: 3") == true)
        XCTAssertEqual(cell.accessibilityValue, "Collapsed")
        var activated = 0
        var received: SwipableCellButtonType?
        cell.onActivate = { activated += 1 }
        cell.onAction = { received = $0 }
        XCTAssertTrue(cell.accessibilityActivate())
        XCTAssertEqual(activated, 1)
        let receive = try XCTUnwrap(cell.accessibilityCustomActions?.first { $0.name == "Receive" })
        XCTAssertTrue(receive.actionHandler?(receive) == true)
        XCTAssertEqual(received, .receive)
        cell.prepareForReuse()
        XCTAssertFalse(cell.accessibilityActivate())
        XCTAssertNil(cell.accessibilityCustomActions)
    }

    @MainActor
    func testTokenCellLargeTextFitsOnSmallScreen() throws {
        let (model, _) = try fixture()
        let controller = ChainAssetListViewController(
            bannersViewController: nil,
            output: TokenLensOutputSpy(),
            keyboardAdoptable: false,
            localizationManager: LocalizationManager.shared
        )
        let parent = UIViewController()
        parent.addChild(controller)
        parent.view.addSubview(controller.view)
        controller.view.frame = parent.view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.didMove(toParent: parent)
        parent.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: controller
        )
        let window = try host(parent)
        defer { window.isHidden = true }
        controller.didReceive(viewModel: model)
        window.layoutIfNeeded()
        let cell = try XCTUnwrap(
            controller.rootView.tableView
                .cellForRow(at: IndexPath(row: 0, section: 0)) as? TokenGroupBalanceTableCell
        )
        for label in [cell.symbolLabel, cell.networksLabel, cell.amountLabel, cell.fiatLabel, cell.pricingLabel]
            where !label.isHidden {
            let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
            XCTAssertGreaterThanOrEqual(label.bounds.height + 1, needed.height)
        }
        let image = UIGraphicsImageRenderer(bounds: controller.view.bounds)
            .image { _ in controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: image)
        attachment.name = "token-lens-small-largest-text"
        attachment.lifetime = .keepAlways
        add(attachment)
        let table = controller.rootView.tableView
        let footer = try XCTUnwrap(table.tableFooterView)
        table.scrollRectToVisible(footer.frame, animated: false)
        window.layoutIfNeeded()
        var pending: [UIView] = [footer]
        while let next = pending.popLast() {
            if let label = next as? UILabel, !label.isHidden, label.text?.isEmpty == false {
                let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                XCTAssertGreaterThanOrEqual(label.bounds.height + 1, needed.height, label.text ?? "")
            }
            pending += next.subviews
        }
        let button = controller.rootView.footerButton
        let title = try XCTUnwrap(button.titleLabel)
        XCTAssertFalse(button.currentTitle?.isEmpty ?? true)
        XCTAssertGreaterThan(title.bounds.width, 20)
        XCTAssertGreaterThan(title.bounds.height, 10)
        XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
        XCTAssertTrue(button.bounds.contains(title.frame))
        XCTAssertGreaterThanOrEqual(
            title.bounds.height + 1,
            title.sizeThatFits(CGSize(width: title.bounds.width, height: .greatestFiniteMagnitude)).height
        )
        let footerAttachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        })
        footerAttachment.name = "token-lens-footer-small-largest-text"
        footerAttachment.lifetime = .keepAlways
        add(footerAttachment)
    }

    @MainActor
    func testPortfolioActionButtonLoadingStateAndHitTarget() throws {
        let button = PortfolioActionButton(frame: CGRect(x: 0, y: 0, width: 288, height: 48))
        button.setTitle("Manage assets", for: .normal)
        let parent = UIViewController()
        parent.view.addSubview(button)
        let window = try host(parent)
        defer { window.isHidden = true }
        button.layoutIfNeeded()
        XCTAssertEqual(button.hitTest(CGPoint(x: 2, y: 2), with: nil), button)
        var actions = 0
        button.addAction(UIAction { _ in actions += 1 }, for: .touchUpInside)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(actions, 1)
        button.set(loading: true)
        XCTAssertFalse(button.isEnabled)
        XCTAssertTrue(button.configuration?.showsActivityIndicator == true)
        button.set(loading: false)
        XCTAssertTrue(button.isEnabled)
        XCTAssertFalse(button.configuration?.showsActivityIndicator == true)
        XCTAssertEqual(button.currentTitle, "Manage assets")
    }

    func testChamferKeepsOnlyTopLeftAndBottomRightCutsAndClampsSmallBounds() {
        let bounds = CGRect(x: 10, y: 20, width: 100, height: 50)
        let path = FWChamferPath.path(in: bounds)
        XCTAssertFalse(path.contains(CGPoint(x: 11, y: 21)))
        XCTAssertFalse(path.contains(CGPoint(x: 109, y: 69)))
        XCTAssertTrue(path.contains(CGPoint(x: 106, y: 24)))
        XCTAssertTrue(path.contains(CGPoint(x: 14, y: 66)))
        XCTAssertTrue(path.contains(CGPoint(x: 60, y: 45)))
        let tiny = CGRect(x: 0, y: 0, width: 4, height: 2)
        XCTAssertTrue(tiny.contains(FWChamferPath.path(in: tiny).bounds))
        XCTAssertTrue(FWChamferPath.path(in: .zero).bounds.isEmpty)
    }

    func testPortfolioStringsResolveEveryShippedLocale() {
        let keys = [
            "lens.tokens",
            "lens.networks",
            "network_count",
            "price_unavailable",
            "partial_value",
            "custom_order",
            "popular_tokens",
            "zero_tokens",
            "expand",
            "collapse",
            "hide_group",
            "choose_network",
            "empty_ready",
            "empty_fund",
            "buy",
            "buy_unavailable",
            "funding_unavailable",
            "empty_networks"
        ]
        for language in ["en", "ru", "ja", "zh-Hans", "id", "pt", "pt-PT", "tr", "vi"] {
            for suffix in keys {
                let key = "portfolio." + suffix
                let value = PortfolioStrings.text(key, locale: Locale(identifier: language))
                XCTAssertNotEqual(value, key, "\(language): \(key)")
                XCTAssertFalse(value.isEmpty)
            }
        }
        XCTAssertEqual(PortfolioStrings.text("portfolio.lens.networks", locale: Locale(identifier: "ja")), "ネットワーク")
        XCTAssertEqual(PortfolioStrings.text("ux.collapsed", locale: Locale(identifier: "pt-PT")), "Recolhido")
        XCTAssertEqual(PortfolioStrings.text("ux.expanded", locale: Locale(identifier: "pt-PT")), "Expandido")
    }

    @MainActor
    func testEmptyFundingCardFitsLocalizedCompactWindowsAndRejectsStaleActions() throws {
        for localeId in ["en", "ru", "ja"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let output = TokenLensOutputSpy()
                let localization = LocalizationManager(localization: localeId)
                let controller = ChainAssetListViewController(
                    bannersViewController: nil,
                    output: output,
                    keyboardAdoptable: false,
                    localizationManager: localization
                )
                let wrapper = UIViewController()
                wrapper.addChild(controller)
                wrapper.view.addSubview(controller.view)
                controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
                controller.didMove(toParent: wrapper)
                wrapper.setOverrideTraitCollection(
                    UITraitCollection(preferredContentSizeCategory: category),
                    forChild: controller
                )
                let window = try host(wrapper)
                defer { window.isHidden = true }
                var (model, _) = try fixture(empty: true)
                XCTAssertTrue(model.isWalletEmpty)
                model.showsFundingCard = true
                model.canReceive = true
                model.canBuy = true
                controller.didReceive(viewModel: model)
                controller.view.layoutIfNeeded()
                let card = controller.rootView.emptyWalletView
                let table = controller.rootView.tableView
                XCTAssertFalse(card.isHidden)
                XCTAssertGreaterThan(card.bounds.height, 44)
                XCTAssertEqual(
                    card.titleLabel.text,
                    PortfolioStrings.text("portfolio.empty_ready", locale: Locale(identifier: localeId))
                )
                for label in [card.titleLabel, card.messageLabel] {
                    let expected = label.sizeThatFits(CGSize(
                        width: label.bounds.width,
                        height: .greatestFiniteMagnitude
                    )).height
                    XCTAssertGreaterThanOrEqual(label.bounds.height + 1, expected)
                    XCTAssertEqual(
                        label.font.pointSize,
                        UIFont
                            .preferredFont(
                                forTextStyle: label === card.titleLabel ? .title2 : .body,
                                compatibleWith: label.traitCollection
                            ).pointSize,
                        accuracy: 0.5
                    )
                }
                let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(
                        in: window.bounds,
                        afterScreenUpdates: true
                    )
                })
                attachment.name = "empty-wallet-320x568-\(localeId)-\(category.rawValue)"
                attachment.lifetime = .keepAlways
                add(attachment)
                let stale = card.onReceive
                for (action, button) in [(PortfolioFundingAction.receive, card.receiveButton), (.buy, card.buyButton)] {
                    table.scrollRectToVisible(button.convert(button.bounds, to: table), animated: false)
                    controller.view.layoutIfNeeded()
                    let label = try XCTUnwrap(button.titleLabel)
                    XCTAssertTrue(button.bounds.insetBy(dx: -1, dy: -1).contains(label.convert(
                        label.bounds,
                        to: button
                    )))
                    XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                    let point = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: window)
                    let hit = try XCTUnwrap(window.hitTest(point, with: nil))
                    XCTAssertTrue(hit === button || hit.isDescendant(of: button))
                    button.sendActions(for: .touchUpInside)
                    XCTAssertEqual(output.fundingActions.last?.0, action)
                    XCTAssertEqual(output.fundingActions.last?.1, model.walletId)
                    if category.isAccessibilityCategory {
                        let actions = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                            window.drawHierarchy(
                                in: window.bounds,
                                afterScreenUpdates: true
                            )
                        })
                        actions.name = "empty-wallet-320x568-\(localeId)-\(action)-maximum-text"
                        actions.lifetime = .keepAlways
                        add(actions)
                    }
                }
                var other = model
                other.walletId = "other"
                controller.didReceive(viewModel: other)
                controller.didReceive(viewModel: model)
                stale?()
                XCTAssertEqual(output.fundingActions.count, 2)
                model.canBuy = false
                controller.didReceive(viewModel: model)
                XCTAssertFalse(card.buyButton.isEnabled)
                XCTAssertFalse(card.unavailableLabel.isHidden)
                controller.view.layoutIfNeeded()
                table.scrollRectToVisible(
                    card.unavailableLabel.convert(card.unavailableLabel.bounds, to: table),
                    animated: false
                )
                controller.view.layoutIfNeeded()
                XCTAssertGreaterThanOrEqual(
                    card.unavailableLabel.bounds.height + 1,
                    card.unavailableLabel.sizeThatFits(CGSize(
                        width: card.unavailableLabel.bounds.width,
                        height: .greatestFiniteMagnitude
                    )).height
                )
                let unavailable = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(
                        in: window.bounds,
                        afterScreenUpdates: true
                    )
                })
                unavailable.name = "empty-wallet-buy-unavailable-320x568-\(localeId)-\(category.rawValue)"
                unavailable.lifetime = .keepAlways
                add(unavailable)
                card.buyButton.sendActions(for: .touchUpInside)
                XCTAssertEqual(output.fundingActions.count, 2)
            }
        }
    }

    @MainActor
    func testNativeFundingPickerSearchSelectsExactClosureAfterDismissalAndCancelDoesNothing() async throws {
        let output = TokenLensOutputSpy()
        let hostController = ChainAssetListViewController(
            bannersViewController: nil,
            output: output,
            keyboardAdoptable: false,
            localizationManager: LocalizationManager.shared
        )
        let window = try host(hostController)
        defer { window.isHidden = true }
        var selected: [Int] = []
        let options = (0 ..< 3).map { index in PortfolioFundingOption(
            title: "TOKEN · Same network",
            subtitle: "Exact asset \(index)",
            select: { selected.append(index) }
        ) }
        let router = ChainAssetListRouter()
        router.showFundingOptions(
            from: hostController,
            title: "Choose a network",
            options: options,
            locale: Locale(identifier: "en")
        )
        for _ in 0 ..< 200
            where hostController.presentedViewController?
            .transitionCoordinator != nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let nav = try XCTUnwrap(hostController.presentedViewController as? UINavigationController)
        let picker = try XCTUnwrap(nav.topViewController as? PortfolioFundingPickerViewController)
        let search = try XCTUnwrap(picker.navigationItem.searchController)
        search.searchBar.text = "asset 2"
        picker.updateSearchResults(for: search)
        XCTAssertEqual(picker.tableView(picker.tableView, numberOfRowsInSection: 0), 1)
        picker.tableView(picker.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        picker.tableView(picker.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        for _ in 0 ..< 200 where selected.isEmpty {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(selected, [2])
        XCTAssertNil(hostController.presentedViewController)
        router.showFundingOptions(
            from: hostController,
            title: "Choose a network",
            options: options,
            locale: Locale(identifier: "en")
        )
        for _ in 0 ..< 200
            where hostController.presentedViewController?
            .transitionCoordinator != nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let reopened = try XCTUnwrap(
            (hostController.presentedViewController as? UINavigationController)?
                .topViewController as? PortfolioFundingPickerViewController
        )
        let close = try XCTUnwrap(reopened.navigationItem.leftBarButtonItem)
        try UIApplication.shared.sendAction(XCTUnwrap(close.action), to: close.target, from: close, for: nil)
        for _ in 0 ..< 200
            where hostController.presentedViewController != nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNil(hostController.presentedViewController)
        XCTAssertEqual(selected, [2])
    }

    @MainActor
    func testFundingPickerLocalizedRowsFitAtNormalAndMaximumText() async throws {
        for localeId in ["en", "ru", "ja"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let controller = ChainAssetListViewController(
                    bannersViewController: nil,
                    output: TokenLensOutputSpy(),
                    keyboardAdoptable: false,
                    localizationManager: LocalizationManager(localization: localeId)
                )
                let window = try host(controller)
                defer { window.isHidden = true }
                let locale = Locale(identifier: localeId)
                var selected = false
                ChainAssetListRouter().showFundingOptions(
                    from: controller,
                    title: PortfolioStrings.text("portfolio.choose_network", locale: locale),
                    options: [
                        PortfolioFundingOption(
                            title: "DOT · Polkadot",
                            subtitle: "Polkadot",
                            select: { selected = true }
                        ),
                        PortfolioFundingOption(title: "USDT · Polkadot Asset Hub", subtitle: "Tether USD", select: {})
                    ],
                    locale: locale
                )
                for _ in 0 ..< 200
                    where controller.presentedViewController?
                    .transitionCoordinator != nil {
                    try await Task.sleep(nanoseconds: 10_000_000)
                }
                let navigation = try XCTUnwrap(controller.presentedViewController as? UINavigationController)
                let picker = try XCTUnwrap(navigation.topViewController as? PortfolioFundingPickerViewController)
                if #available(iOS 17.0, *) {
                    picker.traitOverrides.preferredContentSizeCategory = category
                }
                picker.tableView.reloadData()
                picker.view.layoutIfNeeded()
                let row = try XCTUnwrap(picker.tableView.cellForRow(at: IndexPath(row: 0, section: 0)))
                XCTAssertGreaterThanOrEqual(row.bounds.height, 44)
                var pending = row.subviews
                while let child = pending.popLast() {
                    pending += child.subviews
                    if let label = child as? UILabel, label.text?.isEmpty == false {
                        XCTAssertGreaterThanOrEqual(
                            label.bounds.height + 1,
                            label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                                .height
                        )
                    }
                }
                let capture = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(
                        in: window.bounds,
                        afterScreenUpdates: true
                    )
                })
                capture.name = "funding-picker-320x568-\(localeId)-\(category.rawValue)"
                capture.lifetime = .keepAlways
                add(capture)
                for index in 0 ..< 2 {
                    picker.tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: false)
                    picker.view.layoutIfNeeded()
                    let cell = try XCTUnwrap(picker.tableView.cellForRow(at: IndexPath(row: index, section: 0)))
                    let point = cell.convert(CGPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: window)
                    let hit = try XCTUnwrap(window.hitTest(point, with: nil))
                    XCTAssertTrue(
                        hit === cell || hit.isDescendant(of: cell),
                        "The floating search control must not cover a row action"
                    )
                }
                picker.tableView(picker.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
                for _ in 0 ..< 200 where !selected {
                    try await Task.sleep(nanoseconds: 10_000_000)
                }
                XCTAssertTrue(selected)
                XCTAssertNil(controller.presentedViewController)
            }
        }
    }

    private func fixture(
        single: Bool = false,
        empty: Bool = false
    ) throws -> (ChainAssetListViewModel, MetaAccountModel) {
        var assets = try SendNetworkFixture.assets()
            .filter { CanonicalTokenGroupCatalog.bundled.group(for: $0)?.id == "usdt" }
            .sorted { $0.chain.name < $1.chain.name }
        XCTAssertEqual(assets.count, 3)
        if empty {
            assets = try SendNetworkFixture.assets()
                .filter { $0.asset.isUtility && !PortfolioTestnetChainList.bundled.isTestnet($0.chain) }
        }
        if single {
            assets = Array(assets.prefix(1))
        }
        let wallet = AccountGenerator.generateMetaAccount()
        var infos: [ChainAssetKey: AccountInfo?] = [:]
        for asset in assets.prefix(empty ? assets.count : 2) {
            guard let account = wallet.fetch(for: asset.chain.accountRequest()) else {
                if !empty {
                    XCTFail("The funded fixture must have a matching account")
                }
                continue
            }
            infos[asset.uniqueKey(accountId: account.accountId)] = AccountInfo(
                nonce: 0,
                consumers: 0,
                providers: 0,
                data: AccountData(free: empty ? 0 : 1_000_000, reserved: 0, frozen: 0, flags: 0)
            )
        }
        let factory = ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
        return (
            factory
                .buildViewModel(
                    wallet: wallet,
                    chainAssets: assets,
                    locale: Locale(identifier: "en"),
                    accountInfos: infos,
                    chainsWithIssue: [],
                    shouldRunManageAssetAnimate: false,
                    displayType: .assetChains,
                    chainSettings: [],
                    networkFilter: nil,
                    search: nil
                ),
            wallet
        )
    }

    @MainActor
    private func host(_ controller: UIViewController) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

    @MainActor
    func testGeneratedDesignColorsExistInApplicationBundleForEveryAppearance() throws {
        XCTAssertEqual(FWTokens.sourceSHA256, "18180aa767b87b8ac0bb767622e172328d95145817a1475a840905eec55b4315")
        let bundle = Bundle(for: ChainAssetListViewController.self)
        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection(traitsFrom: [
                    UITraitCollection(userInterfaceStyle: style),
                    UITraitCollection(accessibilityContrast: contrast)
                ])
                for name in FWTokens.colorsets {
                    let color = try XCTUnwrap(UIColor(named: name, in: bundle, compatibleWith: traits), name)
                    XCTAssertGreaterThan(color.resolvedColor(with: traits).cgColor.alpha, 0, name)
                }
            }
        }
    }

    @MainActor
    func testIncreasedContrastUsesTheGeneratedAlternateTextColor() throws {
        let color =
            try XCTUnwrap(UIColor(
                named: "fwTextSecondary",
                in: Bundle(for: ChainAssetListViewController.self),
                compatibleWith: nil
            ))
        let normal = color.resolvedColor(with: UITraitCollection(accessibilityContrast: .normal))
        let high = color.resolvedColor(with: UITraitCollection(accessibilityContrast: .high))
        XCTAssertFalse(normal.isEqual(high))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(high.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(red, 213 / 255.0, accuracy: 0.001)
        XCTAssertEqual(green, 218 / 255.0, accuracy: 0.001)
        XCTAssertEqual(blue, 234 / 255.0, accuracy: 0.001)
        XCTAssertEqual(alpha, 1)
    }
}

private final class TokenLensOutputSpy: ChainAssetListViewOutput {
    var fundingActions: [(PortfolioFundingAction, String)] = []
    func didTapFunding(_ action: PortfolioFundingAction, walletId: String) { fundingActions.append((action, walletId)) }
    var selectedAssets: [AssetKey] = []
    var lenses: [PortfolioLens] = []
    var groupActions: [SwipableCellButtonType] = []
    func didLoad(view _: ChainAssetListViewInput) {}
    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel) {
        selectedAssets.append(viewModel.chainAsset.assetKey)
    }

    func didTapAction(actionType _: SwipableCellButtonType, viewModel _: ChainAccountBalanceCellViewModel) {}
    func didSelectLens(_ lens: PortfolioLens, walletId _: String) { lenses.append(lens) }
    func didTapTokenAction(actionType: SwipableCellButtonType, groupId _: String, walletId _: String) {
        groupActions.append(actionType)
    }

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

/// Native presentation baseline. Synthetic holdings and no remote image requests.
@MainActor
final class PortfolioListPresentationTests: XCTestCase {
    private let languages = ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"]

    func testBothLensesAtEveryLocaleAndTextSize() async throws {
        for language in languages {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                for lens in PortfolioLens.allCases {
                    let fixture = try makeFixture(language: language, category: category, lens: lens)
                    let table = fixture.controller.rootView.tableView
                    await settle(fixture.window)
                    let prefix = "portfolio-list-\(language)-\(category.rawValue)-\(lens.rawValue)"
                    assertLabelsFit(fixture.controller.rootView.lensControl)
                    for label in labels(fixture.controller.rootView.lensControl) where isShown(label) {
                        XCTAssertGreaterThanOrEqual(
                            label.font.pointSize + 0.5,
                            UIFont.fw(.labelM, compatibleWith: label.traitCollection).pointSize
                        )
                    }
                    capture(fixture, name: prefix + "-top")
                    if lens == .token {
                        let group = try XCTUnwrap(
                            table
                                .cellForRow(at: IndexPath(row: 0, section: 0)) as? TokenGroupBalanceTableCell
                        )
                        assertLabelsFit(group.cloudView)
                        XCTAssertEqual(
                            group.amountLabel.font.pointSize,
                            UIFont.fw(.numberM, compatibleWith: group.traitCollection).pointSize,
                            accuracy: 0.5
                        )
                        XCTAssertFalse(
                            group.amountLabel.font.fontName.contains("Sora"),
                            "Numeric values must use the planned tabular system role"
                        )
                        XCTAssertTrue(group.accessibilityActivate())
                        await settle(fixture.window)
                        XCTAssertGreaterThan(fixture.controller.tableView(table, numberOfRowsInSection: 0), 1)
                        table.scrollToRow(at: IndexPath(row: 1, section: 0), at: .top, animated: false)
                        await settle(fixture.window)
                        let child = try XCTUnwrap(
                            table
                                .cellForRow(at: IndexPath(row: 1, section: 0)) as? ChainAccountBalanceTableCell
                        )
                        assertAsset(child, language: language)
                        let expected = try XCTUnwrap(
                            fixture.model.tokenRows.first?.model.children.first?.chainAsset
                                .assetKey
                        )
                        fixture.controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
                        fixture.controller.swipeCellDidTap(on: .receive, with: IndexPath(row: 1, section: 0))
                        XCTAssertEqual(fixture.output.selectedAssets, [expected])
                        XCTAssertEqual(fixture.output.assetActions.map(\.1), [expected])
                        capture(fixture, name: prefix + "-child")
                    } else {
                        let header = try XCTUnwrap(table.headerView(forSection: 0) as? AssetNetworkHeaderView)
                        assertLabelsFit(header.contentView)
                        XCTAssertEqual(header.accessibilityValue, text("ux.expanded", language))
                        let child = try XCTUnwrap(
                            table
                                .cellForRow(at: IndexPath(row: 0, section: 0)) as? ChainAccountBalanceTableCell
                        )
                        assertAsset(child, language: language)
                        let count = fixture.controller.tableView(table, numberOfRowsInSection: 0)
                        XCTAssertTrue(header.accessibilityActivate())
                        await settle(fixture.window)
                        XCTAssertEqual(fixture.controller.tableView(table, numberOfRowsInSection: 0), 0)
                        let collapsed = try XCTUnwrap(table.headerView(forSection: 0) as? AssetNetworkHeaderView)
                        XCTAssertEqual(collapsed.accessibilityValue, text("ux.collapsed", language))
                        capture(fixture, name: prefix + "-collapsed")
                        XCTAssertTrue(collapsed.accessibilityActivate())
                        await settle(fixture.window)
                        XCTAssertEqual(fixture.controller.tableView(table, numberOfRowsInSection: 0), count)
                        table.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
                        await settle(fixture.window)
                        let expected = try XCTUnwrap(
                            fixture.model.networkSections.first?.rows.first?.chainAsset
                                .assetKey
                        )
                        fixture.controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
                        fixture.controller.swipeCellDidTap(on: .receive, with: IndexPath(row: 0, section: 0))
                        XCTAssertEqual(fixture.output.selectedAssets, [expected])
                        XCTAssertEqual(fixture.output.assetActions.map(\.1), [expected])
                        capture(fixture, name: prefix + "-asset")
                    }
                    let footer = fixture.controller.rootView.footerButton
                    // Self-sizing offscreen rows refine the content extent while scrolling.
                    // The diagnostic proves this converges in three passes at AX5.
                    for _ in 0 ..< 8 {
                        table.scrollRectToVisible(footer.convert(footer.bounds, to: table), animated: false)
                        await settle(fixture.window)
                        let viewport = table.convert(
                            table.bounds.inset(by: table.adjustedContentInset),
                            to: fixture.window
                        )
                        let frame = footer.convert(footer.bounds, to: fixture.window)
                        if viewport.insetBy(dx: -0.5, dy: -0.5).contains(frame) { break }
                    }
                    assertLabelsFit(footer)
                    let point = footer.convert(
                        CGPoint(x: footer.bounds.midX, y: footer.bounds.midY),
                        to: fixture.window
                    )
                    let hit = fixture.window.hitTest(point, with: nil)
                    XCTAssertTrue(hit === footer || hit?.isDescendant(of: footer) == true)
                    footer.sendActions(for: .touchUpInside)
                    XCTAssertEqual(fixture.output.manageCalls, 1)
                    capture(fixture, name: prefix + "-footer")
                    close(fixture)
                }
            }
        }
    }

    func testLiveLocaleTypeAndWidthRefreshPresentationWithoutChangingAssetIdentity() async throws {
        let fixture = try makeFixture(language: "en", category: .large, lens: .network)
        defer { close(fixture) }
        await settle(fixture.window)
        let table = fixture.controller.rootView.tableView
        let originalCell = try XCTUnwrap(
            table
                .cellForRow(at: IndexPath(row: 0, section: 0)) as? ChainAccountBalanceTableCell
        )
        let expected = try XCTUnwrap(fixture.model.networkSections.first?.rows.first?.chainAsset.assetKey)
        let originalLabel = try XCTUnwrap(labels(originalCell.cloudView).first { $0.text == "1,250.40" })
        let originalSize = originalLabel.font.pointSize
        fixture.localization.selectedLocalization = "ru"
        fixture.controller.applyLocalization()
        // The real presenter republishes localized view models. Keep its wallet/asset identities
        // while emulating that public input; an absent fixture presenter is not a production bug.
        let sections = fixture.model.networkSections.map { section in
            AssetNetworkSectionViewModel(
                id: section.id, chainId: section.chainId, kind: section.kind, networkName: section.networkName,
                ecosystemName: section.ecosystemName, address: section.address, fiatSubtotal: section.fiatSubtotal,
                syncStatus: section.rows.first.flatMap {
                    NetworkScanStateStore.state(for: $0.chainAsset.chain, walletId: fixture.model.walletId ?? "")
                        .attentionText(now: Date(), locale: Locale(identifier: "ru"))
                }, detectedCount: section.detectedCount,
                rows: section.rows.map { offlineCell($0, language: "ru") }, parentSectionId: section.parentSectionId
            )
        }
        var localizedModel = ChainAssetListViewModel(
            displayState: .defaultList(cells: sections.flatMap(\.rows), withAnimate: false),
            networkSections: sections
        )
        localizedModel.walletId = fixture.model.walletId
        localizedModel.lens = .network
        fixture.controller.didReceive(viewModel: localizedModel)
        if #available(iOS 17.0, *) {
            fixture.window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        }
        fixture.window.frame.size.width = 640
        await settle(fixture.window)
        fixture.window.frame.size.width = 320
        await settle(fixture.window)
        XCTAssertEqual(
            fixture.controller.rootView.footerButton.currentTitle,
            R.string.localizable.walletManageAssets(preferredLanguages: ["ru"])
        )
        let cell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)) as? ChainAccountBalanceTableCell)
        assertAsset(cell, language: "ru")
        let amount = try XCTUnwrap(labels(cell.cloudView).first { $0.text == "1,250.40" })
        XCTAssertGreaterThan(amount.font.pointSize, originalSize)
        fixture.controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(fixture.output.selectedAssets, [expected])
        capture(fixture, name: "portfolio-list-live-ru-AX5-narrow")
    }

    func testReusedAssetCellRefreshesEveryActionTitleFromNewLocale() throws {
        let cell = ChainAccountBalanceTableCell(style: .default, reuseIdentifier: nil)
        for language in ["en", "ru", "ja", "tr"] {
            let model = try makeModel(language: language, lens: .network)
            let row = try XCTUnwrap(model.networkSections.first?.rows.first)
            cell.bind(to: row, showsNetwork: true)
            let actions = cell.leftMenuButtons + cell.rightMenuButtons
            XCTAssertEqual(
                actions.first { $0.type == .send }?.currentTitle,
                R.string.localizable.commonActionSend(preferredLanguages: [language])
            )
            XCTAssertEqual(
                actions.first { $0.type == .receive }?.currentTitle,
                R.string.localizable.commonActionReceive(preferredLanguages: [language])
            )
            XCTAssertEqual(
                actions.first { $0.type == .hide }?.currentTitle,
                R.string.localizable.swipableCellButtonHide(preferredLanguages: [language])
            )
            cell.prepareForReuse()
        }
    }

    func testNativeLensButtonsHitTestingSelectionAndBoldText() async throws {
        guard FWAppearance.portfolioListRestyled else { return }
        let fixture = try makeFixture(language: "ru", category: .accessibilityExtraExtraExtraLarge, lens: .token)
        defer { close(fixture) }
        await settle(fixture.window)
        let control = fixture.controller.rootView.lensControl
        let original = try XCTUnwrap(control.segmentButtons.first?.titleLabel?.font)
        for (index, button) in control.segmentButtons.enumerated() {
            let center = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: fixture.window)
            let hit = fixture.window.hitTest(center, with: nil)
            XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
            XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
            button.sendActions(for: .touchUpInside)
            XCTAssertEqual(control.selectedSegmentIndex, index)
            XCTAssertTrue(button.accessibilityTraits.contains(.selected))
            XCTAssertFalse(control.segmentButtons[1 - index].accessibilityTraits.contains(.selected))
        }
        XCTAssertEqual(fixture.output.lenses, [.token, .network])
        if #available(iOS 17.0, *) {
            fixture.window.traitOverrides.legibilityWeight = .bold
            await settle(fixture.window)
            let bold = try XCTUnwrap(control.segmentButtons.first?.titleLabel?.font)
            func weight(_ font: UIFont) -> CGFloat {
                (
                    font.fontDescriptor
                        .object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
                )?[.weight] as? CGFloat ?? 0
            }
            XCTAssertGreaterThan(weight(bold), weight(original))
            XCTAssertEqual(bold.pointSize, original.pointSize, accuracy: 0.5)
            assertLabelsFit(control)
            capture(fixture, name: "portfolio-list-ru-AX5-bold-native-lens")
            fixture.window.traitOverrides.legibilityWeight = .regular
            await settle(fixture.window)
            XCTAssertEqual(control.segmentButtons.first?.titleLabel?.font, original)
        }
    }

    func testSelectedLocaleAttentionAndDetectedHeaderStates() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        for language in languages {
            let locale = Locale(identifier: language)
            for (success, error, key) in [
                (Optional(now), true, "portfolio.balance.update_failed"),
                (Date?.none, false, "portfolio.balance.not_loaded"),
                (Optional(now.addingTimeInterval(-37 * 3600)), false, "portfolio.balance.outdated")
            ] {
                let state = NetworkScanState(
                    lastAttempt: now,
                    lastSuccess: success,
                    hasError: error,
                    coverage: .complete
                )
                XCTAssertEqual(state.attentionText(now: now, locale: locale), text(key, language))
            }
            XCTAssertNil(
                NetworkScanState(lastAttempt: now, lastSuccess: now, hasError: false, coverage: .complete)
                    .attentionText(now: now, locale: locale)
            )
            guard FWAppearance.portfolioListRestyled else { continue }
            let model = try makeModel(language: language, lens: .network)
            let source = try XCTUnwrap(model.networkSections.first)
            let header = AssetNetworkHeaderView(reuseIdentifier: nil)
            for kind in [AssetNetworkSectionKind.detected, .zeroNetworks(count: 3)] {
                header.bind(AssetNetworkSectionViewModel(
                    id: source.id, chainId: source.chainId, kind: kind, networkName: source.networkName,
                    ecosystemName: source.ecosystemName, address: source.address, fiatSubtotal: nil,
                    syncStatus: nil, detectedCount: 2, rows: []
                ), collapsed: true, locale: locale)
                XCTAssertEqual(header.accessibilityValue, text("ux.collapsed", language))
                let expected = kind == .detected
                    ? String(format: text("portfolio.asset.detected_count", language), 2)
                    : String(format: text("portfolio.zero_networks", language), 3)
                XCTAssertTrue(header.accessibilityLabel?.contains(expected) == true)
            }
        }
    }

    func testDetectedAndMissingMetadataRowsInEveryLocaleAndSize() async throws {
        guard FWAppearance.portfolioListRestyled else { return }
        for language in languages {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                for trust in [AssetMetadataTrust.unverified, .missing] {
                    let fixture = try makeFixture(language: language, category: category, lens: .network)
                    let section = try XCTUnwrap(fixture.model.networkSections.first)
                    let source = try XCTUnwrap(section.rows.first)
                    let row = offlineCell(source, language: language, trust: trust)
                    let detected = AssetNetworkSectionViewModel(
                        id: section.id, chainId: section.chainId, kind: .detected, networkName: section.networkName,
                        ecosystemName: section.ecosystemName, address: section.address, fiatSubtotal: nil,
                        syncStatus: nil, detectedCount: 1, rows: [row]
                    )
                    var model = ChainAssetListViewModel(
                        displayState: .defaultList(cells: [row], withAnimate: false), networkSections: [detected]
                    )
                    model.walletId = fixture.model.walletId
                    model.lens = .network
                    fixture.controller.didReceive(viewModel: model)
                    await settle(fixture.window)
                    let table = fixture.controller.rootView.tableView
                    let header = try XCTUnwrap(table.headerView(forSection: 0) as? AssetNetworkHeaderView)
                    assertLabelsFit(header.contentView)
                    XCTAssertTrue(
                        header.accessibilityLabel?
                            .contains(text("portfolio.asset.detected_review", language)) == true
                    )
                    XCTAssertTrue(header.accessibilityActivate())
                    await settle(fixture.window)
                    table.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
                    await settle(fixture.window)
                    let cell = try XCTUnwrap(
                        table
                            .cellForRow(at: IndexPath(row: 0, section: 0)) as? ChainAccountBalanceTableCell
                    )
                    let key = trust == .missing ? "portfolio.asset.metadata_missing" : "portfolio.asset.detected"
                    XCTAssertTrue(
                        labels(cell.cloudView)
                            .contains { $0.text?.contains(text(key, language).uppercased()) == true }
                    )
                    assertLabelsFit(cell.cloudView)
                    XCTAssertEqual(cell.rightMenuButtons.map(\.type), [.hide, .show])
                    XCTAssertEqual(
                        cell.rightMenuButtons.last?.currentTitle,
                        R.string.localizable.commonShow(preferredLanguages: [language])
                    )
                    fixture.controller.swipeCellDidTap(on: .receive, with: IndexPath(row: 0, section: 0))
                    XCTAssertEqual(fixture.output.assetActions.map(\.1), [source.chainAsset.assetKey])
                    capture(fixture, name: "portfolio-list-\(language)-\(category.rawValue)-\(trust.rawValue)-row")
                    close(fixture)
                }
            }
        }
    }

    func testCompiledRollbackRetainsNativeLensAndExactAssetRoutes() async throws {
        guard !FWAppearance.portfolioListRestyled else { return }
        for language in ["en", "ru", "ja"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let fixture = try makeFixture(language: language, category: category, lens: .network)
                defer { close(fixture) }
                await settle(fixture.window)
                let lens = try XCTUnwrap(
                    descendants(fixture.controller.rootView.lensControl)
                        .compactMap { $0 as? UISegmentedControl }.first
                )
                let row = try XCTUnwrap(
                    fixture.controller.rootView.tableView.cellForRow(at: IndexPath(row: 0, section: 0))
                        as? ChainAccountBalanceTableCell
                )
                let amount = try XCTUnwrap(labels(row).first { $0.text == "1,250.40" })
                XCTAssertEqual(amount.lineBreakMode, .byCharWrapping)
                XCTAssertEqual(lens.selectedSegmentIndex, 1)
                lens.selectedSegmentIndex = 0
                lens.sendActions(for: .valueChanged)
                XCTAssertEqual(fixture.output.lenses, [.token])
                let expected = try XCTUnwrap(fixture.model.networkSections.first?.rows.first?.chainAsset.assetKey)
                fixture.controller.tableView(
                    fixture.controller.rootView.tableView,
                    didSelectRowAt: IndexPath(row: 0, section: 0)
                )
                XCTAssertEqual(fixture.output.selectedAssets, [expected])
                capture(fixture, name: "portfolio-list-rollback-\(language)-\(category.rawValue)")
            }
        }
    }

    func testLoadingIndicatorTracksLiveTextSizeAndLoadedTransition() async throws {
        guard FWAppearance.portfolioListRestyled else { return }
        let fixture = try makeFixture(language: "ja", category: .large, lens: .network)
        defer { close(fixture) }
        func publishLoading(_ isLoading: Bool) {
            let sections = fixture.model.networkSections.map { section in
                AssetNetworkSectionViewModel(
                    id: section.id, chainId: section.chainId, kind: section.kind, networkName: section.networkName,
                    ecosystemName: section.ecosystemName, address: section.address, fiatSubtotal: section.fiatSubtotal,
                    syncStatus: section.syncStatus, detectedCount: section.detectedCount,
                    rows: section.rows.map { source in
                        var row = source
                        row.isColdBoot = isLoading
                        return row
                    }, parentSectionId: section.parentSectionId
                )
            }
            var model = ChainAssetListViewModel(
                displayState: .defaultList(cells: sections.flatMap(\.rows), withAnimate: false),
                networkSections: sections
            )
            model.walletId = fixture.model.walletId
            model.lens = .network
            fixture.controller.didReceive(viewModel: model)
        }
        func assertBars(_ skeleton: UIView) {
            let bars = descendants(skeleton).flatMap { view in
                (view.layer.sublayers ?? []).compactMap { layer -> CGRect? in
                    guard layer is CAGradientLayer else { return nil }
                    return view.convert(layer.frame, to: skeleton)
                }
            }
            XCTAssertEqual(bars.count, 3)
            for (index, bar) in bars.prefix(3).enumerated() {
                XCTAssertGreaterThan(bar.width, 0)
                XCTAssertGreaterThan(bar.height, 0)
                XCTAssertTrue(
                    skeleton.bounds.insetBy(dx: -0.5, dy: -0.5).contains(bar),
                    "Skeleton bar outside row: \(bar)"
                )
                let text = ["$1.00", "1,250.40", "$1,250.40"][index]
                if let target = labels(skeleton.superview ?? skeleton).first(where: { $0.text == text }) {
                    let frame = target.convert(target.bounds, to: skeleton)
                    XCTAssertEqual(bar.midY, frame.midY, accuracy: 0.5, "Loading bar follows its actual amount label")
                    if skeleton.traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
                        XCTAssertEqual(
                            bar.minX,
                            frame.minX,
                            accuracy: 0.5,
                            "Stacked loading bars follow left-aligned values"
                        )
                    }
                } else {
                    XCTFail("Loading target label missing: \(text)")
                }
                for other in bars.dropFirst(index + 1) {
                    XCTAssertFalse(
                        bar.intersects(other),
                        "Skeleton bars overlap: \(bar) and \(other)"
                    )
                }
            }
            let metrics = bars.map { NSCoder.string(for: $0) }
            let attachment = XCTAttachment(string: metrics.joined(separator: "\n"))
            attachment.name = "portfolio-loading-rendered-bars"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        publishLoading(true)
        await settle(fixture.window)
        let table = fixture.controller.rootView.tableView
        let indexPath = IndexPath(row: 0, section: 0)
        let cell = try XCTUnwrap(table.cellForRow(at: indexPath) as? ChainAccountBalanceTableCell)
        let skeleton = try XCTUnwrap(descendants(cell).first { $0 is SkrullableView })
        let content = try XCTUnwrap(skeleton.superview)
        let originalSize = content.bounds.size
        XCTAssertEqual(skeleton.frame, content.bounds)
        assertBars(skeleton)
        capture(fixture, name: "portfolio-list-loading-ja-Large")
        if #available(iOS 17.0, *) {
            fixture.window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        }
        await settle(fixture.window)
        table.scrollToRow(at: indexPath, at: .middle, animated: false)
        await settle(fixture.window)
        let currentCell = try XCTUnwrap(table.cellForRow(at: indexPath) as? ChainAccountBalanceTableCell)
        XCTAssertTrue(currentCell.window === fixture.window)
        let resizedSkeleton = try XCTUnwrap(descendants(currentCell).first { $0 is SkrullableView })
        let resizedContent = try XCTUnwrap(resizedSkeleton.superview)
        XCTAssertGreaterThan(resizedContent.bounds.height, originalSize.height)
        XCTAssertEqual(
            resizedSkeleton.frame,
            resizedContent.bounds,
            "Loading indicator must follow the full-width AX5 row"
        )
        assertBars(resizedSkeleton)
        let visible = resizedSkeleton.convert(resizedSkeleton.bounds, to: fixture.window)
        XCTAssertTrue(visible.intersects(table.convert(table.bounds, to: fixture.window)))
        capture(fixture, name: "portfolio-list-loading-ja-AX5-visible")
        publishLoading(false)
        await settle(fixture.window)
        table.scrollToRow(at: indexPath, at: .middle, animated: false)
        await settle(fixture.window)
        let loadedCell = try XCTUnwrap(table.cellForRow(at: indexPath) as? ChainAccountBalanceTableCell)
        XCTAssertFalse(descendants(loadedCell).contains { $0 is SkrullableView })
        XCTAssertTrue(labels(loadedCell).contains { $0.text == "1,250.40" && $0.alpha == 1 })
        capture(fixture, name: "portfolio-list-loaded-ja-AX5-visible")
    }

    func testDiagnoseSettledFooterReachabilityAndNativeCellFill() async throws {
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            let fixture = try makeFixture(language: "en", category: category, lens: .token)
            defer { close(fixture) }
            let table = fixture.controller.rootView.tableView
            await settle(fixture.window)
            let group = try XCTUnwrap(
                table
                    .cellForRow(at: IndexPath(row: 0, section: 0)) as? TokenGroupBalanceTableCell
            )
            XCTAssertTrue(group.accessibilityActivate())
            await settle(fixture.window)
            let footer = fixture.controller.rootView.footerButton
            var observations: [[String: Any]] = []
            for attempt in 0 ..< 8 {
                table.scrollRectToVisible(footer.convert(footer.bounds, to: table), animated: false)
                await settle(fixture.window)
                let rect = footer.convert(footer.bounds, to: fixture.window)
                let point = CGPoint(x: rect.midX, y: rect.midY)
                let hit = fixture.window.hitTest(point, with: nil)
                observations.append([
                    "attempt": attempt, "footer": NSCoder.string(for: rect),
                    "viewport": NSCoder
                        .string(
                            for: table
                                .convert(table.bounds.inset(by: table.adjustedContentInset), to: fixture.window)
                        ),
                    "contentSize": NSCoder.string(for: table.contentSize),
                    "offset": NSCoder.string(for: table.contentOffset),
                    "hitClass": hit.map { String(describing: type(of: $0)) } ?? "nil",
                    "hitFooter": hit === footer || hit?.isDescendant(of: footer) == true,
                    "fills": descendants(table).compactMap { view -> [String: Any]? in
                        guard let shape = view as? TriangularedView,
                              let layer = shape.layer as? CAShapeLayer else { return nil }
                        return ["view": String(describing: type(of: shape)), "fillAlpha": shape.fillColor.cgColor.alpha,
                                "layerAlpha": layer.fillColor?.alpha ?? -1, "opaque": shape.isOpaque,
                                "layerFill": layer.fillColor?.components ?? [],
                                "viewFrame": NSCoder.string(for: shape.convert(shape.bounds, to: fixture.window))]
                    }
                ])
                if hit === footer || hit?.isDescendant(of: footer) == true { break }
            }
            let point = footer.convert(CGPoint(x: footer.bounds.midX, y: footer.bounds.midY), to: fixture.window)
            let hit = fixture.window.hitTest(point, with: nil)
            XCTAssertTrue(hit === footer || hit?.isDescendant(of: footer) == true)
            capture(fixture, name: "portfolio-list-diagnostic-\(category.rawValue)-footer")
            let attachment = XCTAttachment(
                data: try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys]),
                uniformTypeIdentifier: "public.json"
            )
            attachment.name = "portfolio-list-diagnostic-\(category.rawValue)-native-geometry"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private struct Fixture {
        let controller: ChainAssetListViewController
        let output: PortfolioListOutput
        let window: UIWindow
        let localization: LocalizationManager
        let model: ChainAssetListViewModel
        let defaults: UserDefaults
        let suite: String
    }

    private func makeFixture(language: String, category: UIContentSizeCategory, lens: PortfolioLens) throws -> Fixture {
        let localization = try XCTUnwrap(LocalizationManager(localization: language))
        let output = PortfolioListOutput()
        let suite = "portfolio-presentation-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let controller = ChainAssetListViewController(
            bannersViewController: nil,
            output: output,
            keyboardAdoptable: false,
            localizationManager: localization,
            collapseStore: PortfolioCollapseStore(userDefaults: defaults)
        )
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        window.traitCollection.performAsCurrent {
            let parent = UIViewController()
            parent.view.backgroundColor = UIColor(named: "fwBgBase")
            parent.addChild(controller)
            parent.view.addSubview(controller.view)
            controller.view.snp.makeConstraints { $0.edges.equalToSuperview() }
            controller.didMove(toParent: parent)
            window.rootViewController = parent
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
        }
        let model = try makeModel(language: language, lens: lens)
        controller.didReceive(viewModel: model)
        return Fixture(
            controller: controller,
            output: output,
            window: window,
            localization: localization,
            model: model,
            defaults: defaults,
            suite: suite
        )
    }

    private func makeModel(language: String, lens: PortfolioLens) throws -> ChainAssetListViewModel {
        let assets = try SendNetworkFixture.assets()
            .filter { CanonicalTokenGroupCatalog.bundled.group(for: $0)?.id == "usdt" }
            .sorted { $0.chain.name < $1.chain.name }
        XCTAssertEqual(assets.count, 3)
        let wallet = AccountGenerator.generateMetaAccount()
        var infos: [ChainAssetKey: AccountInfo?] = [:]
        for asset in assets {
            let account = try XCTUnwrap(wallet.fetch(for: asset.chain.accountRequest()))
            infos[asset.uniqueKey(accountId: account.accountId)] = AccountInfo(
                nonce: 0,
                consumers: 0,
                providers: 0,
                data: AccountData(free: 1_250_400_000, reserved: 0, frozen: 0, flags: 0)
            )
        }
        let raw = ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
            .buildViewModel(
                wallet: wallet,
                chainAssets: assets,
                locale: Locale(identifier: language),
                accountInfos: infos,
                chainsWithIssue: [],
                shouldRunManageAssetAnimate: false,
                displayType: .assetChains,
                chainSettings: [],
                networkFilter: nil,
                search: nil,
                lens: lens
            )
        let rows = raw.displayState.rows.map { offlineCell($0, language: language) }
        let sections = raw.networkSections.map { section in
            AssetNetworkSectionViewModel(
                id: section.id,
                chainId: section.chainId,
                kind: section.kind,
                networkName: section.networkName,
                ecosystemName: section.ecosystemName,
                address: section.address,
                fiatSubtotal: "$1,250.40",
                syncStatus: section.syncStatus,
                detectedCount: section.detectedCount,
                rows: section.rows.map { offlineCell($0, language: language) },
                parentSectionId: section.parentSectionId
            )
        }
        var model = ChainAssetListViewModel(
            displayState: .defaultList(cells: rows, withAnimate: false),
            networkSections: sections
        )
        model.walletId = wallet.metaId
        model.lens = lens
        model.tokenChildCells = raw.tokenChildCells.mapValues { offlineCell($0, language: language) }
        model.tokenRows = raw.tokenRows.map { row in
            let m = row.model
            let group = TokenGroupRowModel(
                id: m.id,
                symbol: m.symbol,
                name: m.name,
                icon: nil,
                amount: m.amount,
                fiat: m.fiat,
                unpricedNetworkCount: m.unpricedNetworkCount,
                children: m.children,
                zeroChildren: m.zeroChildren,
                isSingleNetwork: m.isSingleNetwork
            )
            return TokenGroupRowViewModel(model: group, amountText: "3,751.20 USDT", fiatText: "$3,751.20")
        }
        return model
    }

    private func offlineCell(
        _ row: ChainAccountBalanceCellViewModel,
        language: String,
        trust: AssetMetadataTrust? = nil
    ) -> ChainAccountBalanceCellViewModel {
        ChainAccountBalanceCellViewModel(
            assetContainsChainAssets: row.assetContainsChainAssets,
            chainIconViewViewModel: .init(maxImagesCount: 0, chainImages: []),
            chainAsset: row.chainAsset,
            metadataTrust: trust.map { AssetMetadataTrustInfo(trust: $0, provenance: .indexer) } ?? row.metadataTrust,
            assetName: row.assetName,
            assetInfo: row.assetInfo,
            imageViewModel: nil,
            balanceString: .normal("1,250.40"),
            priceAttributedString: .normal("$1.00"),
            totalAmountString: .normal("$1,250.40"),
            options: nil,
            isColdBoot: false,
            locale: Locale(identifier: language),
            hideButtonIsVisible: true,
            swipeActionsEnabled: true,
            transferableString: nil
        )
    }

    private func assertAsset(_ cell: ChainAccountBalanceTableCell, language: String) {
        assertLabelsFit(cell.cloudView)
        if FWAppearance.portfolioListRestyled,
           let amount = labels(cell.cloudView).first(where: { $0.text == "1,250.40" }) {
            XCTAssertEqual(
                amount.font.pointSize,
                UIFont.fw(.numberL, compatibleWith: cell.traitCollection).pointSize,
                accuracy: 0.5
            )
            XCTAssertFalse(amount.font.fontName.contains("Sora"))
        }
        let expectedTrust = text("portfolio.asset.verified", language).uppercased()
        XCTAssertTrue(
            labels(cell.cloudView).contains { $0.text?.contains(expectedTrust) == true },
            "Missing selected-locale trust label: \(language)"
        )
        XCTAssertEqual(
            cell.leftMenuButtons.first { $0.type == .receive }?.currentTitle,
            R.string.localizable.commonActionReceive(preferredLanguages: [language])
        )
        XCTAssertEqual(
            cell.rightMenuButtons.first { $0.type == .hide }?.currentTitle,
            R.string.localizable.swipableCellButtonHide(preferredLanguages: [language])
        )
    }

    private func assertLabelsFit(_ view: UIView) {
        for label in labels(view) where isShown(label) && label.text?.isEmpty == false {
            XCTAssertGreaterThan(label.bounds.width, 0, label.text ?? "")
            let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
            XCTAssertGreaterThanOrEqual(label.bounds.height + 1, needed.height, label.text ?? "")
            if label.numberOfLines == 1 {
                let width = ((label.text ?? "") as NSString).size(withAttributes: [.font: label.font as Any]).width
                XCTAssertGreaterThanOrEqual(
                    label.bounds.width + 1,
                    width,
                    "Single-line truncation: \(label.text ?? "")"
                )
            }
        }
    }

    private func text(_ key: String, _ language: String) -> String {
        Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))?
            .localizedString(forKey: key, value: nil, table: nil) ?? key
    }

    private func labels(_ view: UIView) -> [UILabel] { ([view] + view.subviews.flatMap(descendants))
        .compactMap { $0 as? UILabel }
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
    private func isShown(_ view: UIView) -> Bool { !view.isHidden && view
        .alpha > 0.01 && (view.superview.map(isShown) ?? true)
    }

    private func settle(_ window: UIWindow) async {
        try? await Task.sleep(nanoseconds: 100_000_000); window.layoutIfNeeded()
    }

    private func close(_ fixture: Fixture) {
        fixture.window.isHidden = true; fixture.window.rootViewController = nil; fixture.defaults
            .removePersistentDomain(forName: fixture.suite)
    }

    private func capture(_ fixture: Fixture, name: String) {
        // ChainAssetList is a transparent child in the real portfolio. Include its native
        // parent background rather than interpreting an RGBA child PNG on an arbitrary matte.
        let view = fixture.window.rootViewController!.view!
        let image = UIGraphicsImageRenderer(bounds: view.bounds)
            .image { _ in view.drawHierarchy(in: view.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let metrics: [[String: Any]] = labels(view).filter(isShown).map { [
            "text": $0.text ?? "",
            "font": $0.font.fontName,
            "size": $0.font.pointSize,
            "bounds": NSCoder.string(for: $0.bounds),
            "frame": NSCoder.string(for: $0.convert($0.bounds, to: view)),
        ] }
        if let data = try? JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys]) {
            let detail = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            detail.name = name + "-metrics"
            detail.lifetime = .keepAlways
            add(detail)
        }
    }
}

private final class PortfolioListOutput: ChainAssetListViewOutput {
    var selectedAssets: [AssetKey] = []
    var assetActions: [(SwipableCellButtonType, AssetKey)] = []
    var manageCalls = 0
    var lenses: [PortfolioLens] = []
    func didLoad(view _: ChainAssetListViewInput) {}
    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel) {
        selectedAssets.append(viewModel.chainAsset.assetKey)
    }

    func didTapAction(actionType: SwipableCellButtonType, viewModel: ChainAccountBalanceCellViewModel) {
        assetActions.append((actionType, viewModel.chainAsset.assetKey))
    }

    func didTapFunding(_: PortfolioFundingAction, walletId _: String) {}
    func didSelectLens(_ lens: PortfolioLens, walletId _: String) { lenses.append(lens) }
    func didTapTokenAction(actionType _: SwipableCellButtonType, groupId _: String, walletId _: String) {}
    func didPullToRefresh() {}
    func didTapManageAsset() { manageCalls += 1 }
    func didTapHiddenAssetsNotIncluded() {}
    func didTapTestnetAssetsNotIncluded() {}
    func didTapReviewHiddenFunds() {}
    func didTapKeepHiddenFunds(assetKeys _: [AssetKey]) {}
    func didFinishManageAssetAnimate() {}
    func didTapResolveNetworkIssue(for _: ChainModel) {}
    func didTapResolveAccountIssue(for _: ChainModel) {}
}
