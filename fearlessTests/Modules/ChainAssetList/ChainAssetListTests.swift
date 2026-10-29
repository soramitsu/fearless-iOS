import BigInt
import RobinHood
import SoraFoundation
import class SoraKeystore.InMemoryKeychain
import enum SoraKeystore.KeystoreError
import SSFModels
import XCTest

@testable import fearless

final class ChainAssetListTests: XCTestCase {
    @MainActor
    func testGroupReceiveChoicesCarryExactNetwork() throws {
        let (presenter, view, router, _, wallet) = try tokenPresenter(fundedCount: 1)
        let row = try XCTUnwrap(view.models.last?.tokenRows.first)
        presenter.didTapTokenAction(actionType: .receive, groupId: row.model.id, walletId: wallet.metaId)
        let options = try XCTUnwrap(router.fundingOptions.last)
        XCTAssertEqual(options.count, 3)
        let selected = row.model.allChildren.sorted { $0.networkName < $1.networkName }[1]
        XCTAssertEqual(options[1].title, selected.chainAsset.asset.symbolUppercased + " · " + selected.networkName)
        options[1].select()
        XCTAssertEqual(router.receivedAssets, [selected.chainAsset.assetKey])
    }

    @MainActor
    func testGroupSendShortcutsOnlySingleTransferableMember() throws {
        let (presenter, view, router, _, wallet) = try tokenPresenter(fundedCount: 1)
        let row = try XCTUnwrap(view.models.last?.tokenRows.first)
        presenter.didTapTokenAction(actionType: .send, groupId: row.model.id, walletId: wallet.metaId)
        XCTAssertTrue(router.fundingOptions.isEmpty)
        XCTAssertEqual(router.sentAssets, [row.model.children[0].chainAsset.assetKey])
        let (multiple, manyView, manyRouter, _, manyWallet) = try tokenPresenter(fundedCount: 2)
        let many = try XCTUnwrap(manyView.models.last?.tokenRows.first)
        multiple.didTapTokenAction(actionType: .send, groupId: many.model.id, walletId: manyWallet.metaId)
        let picker = try XCTUnwrap(manyRouter.fundingOptions.last)
        XCTAssertEqual(picker.count, 2)
        XCTAssertTrue(manyRouter.sentAssets.isEmpty)
        picker[0].select()
        let selected = try XCTUnwrap(many.model.children
            .first { $0.chainAsset.asset.symbolUppercased + " · " + $0.networkName == picker[0].title })
        XCTAssertEqual(manyRouter.sentAssets, [selected.chainAsset.assetKey])
    }

    @MainActor
    func testGroupHideConfirmsListedVisibleMembersAndDoesNotHideZeroChildren() throws {
        let (presenter, view, router, interactor, wallet) = try tokenPresenter(fundedCount: 2)
        let row = try XCTUnwrap(view.models.last?.tokenRows.first)
        presenter.didTapTokenAction(actionType: .hide, groupId: row.model.id, walletId: wallet.metaId)
        let sheet = try XCTUnwrap(router.groupHideViewModels.last)
        XCTAssertEqual(
            sheet.message,
            row.model.children.map { $0.chainAsset.asset.symbolUppercased + " · " + $0.networkName }
                .joined(separator: "\n")
        )
        XCTAssertTrue(interactor.hiddenAssets.isEmpty)
        sheet.actions[0].handler?()
        XCTAssertEqual(Set(interactor.hiddenAssets), Set(row.model.children.map { $0.chainAsset.assetKey }))
        XCTAssertFalse(interactor.hiddenAssets.contains(row.model.zeroChildren[0].chainAsset.assetKey))
    }

    @MainActor
    func testGroupPickerCannotActAfterWalletChangesAwayAndBack() throws {
        let (presenter, view, router, _, wallet) = try tokenPresenter(fundedCount: 1)
        let row = try XCTUnwrap(view.models.last?.tokenRows.first)
        presenter.didTapTokenAction(actionType: .receive, groupId: row.model.id, walletId: wallet.metaId)
        let options = try XCTUnwrap(router.fundingOptions.last)
        presenter.handleWalletChanged(wallet: AccountGenerator.generateMetaAccount())
        presenter.handleWalletChanged(wallet: wallet)
        presenter.didReceiveChainAssets(result: .success(row.model.allChildren.map(\.chainAsset)))
        presenter.didReceiveAccountInfo(
            result: .success(AccountInfo(ethBalance: 1_000_000)),
            for: row.model.children[0].chainAsset
        )
        drainPortfolioDeliveries()
        XCTAssertEqual(view.models.last?.walletId, wallet.metaId)
        options[0].select()
        XCTAssertTrue(router.receivedAssets.isEmpty)
    }

    @MainActor
    func testGroupSendChoicesSortTransferableAndRejectUpdatedZeroBalance() throws {
        let (presenter, view, router, _, wallet) = try tokenPresenter(fundedCount: 2)
        let initial = try XCTUnwrap(view.models.last?.tokenRows.first)
        let changed = initial.model.children[1].chainAsset
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 9_000_000)), for: changed)
        drainPortfolioDeliveries()
        let row = try XCTUnwrap(view.models.last?.tokenRows.first)
        presenter.didTapTokenAction(actionType: .send, groupId: row.model.id, walletId: wallet.metaId)
        let options = try XCTUnwrap(router.fundingOptions.last)
        let sorted = row.model.children.sorted { $0.value.transferable > $1.value.transferable }
        XCTAssertEqual(
            options.map(\.title),
            sorted.map { $0.chainAsset.asset.symbolUppercased + " · " + $0.networkName }
        )
        let selected = try XCTUnwrap(sorted.first)
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 0)), for: selected.chainAsset)
        drainPortfolioDeliveries()
        options[0].select()
        XCTAssertTrue(router.sentAssets.isEmpty)
    }

    @MainActor
    func testGroupHideRejectsChangedVisibleMembersAndWalletReturn() throws {
        for change in ["members", "wallet"] {
            let (presenter, view, router, interactor, wallet) = try tokenPresenter(fundedCount: 2)
            let row = try XCTUnwrap(view.models.last?.tokenRows.first)
            presenter.didTapTokenAction(actionType: .hide, groupId: row.model.id, walletId: wallet.metaId)
            let sheet = try XCTUnwrap(router.groupHideViewModels.last)
            if change == "members" {
                presenter
                    .didReceiveChainAssets(result: .success(Array(row.model.allChildren.dropFirst()).map(\.chainAsset)))
            } else {
                presenter.handleWalletChanged(wallet: AccountGenerator.generateMetaAccount())
                presenter.handleWalletChanged(wallet: wallet)
                presenter.didReceiveChainAssets(result: .success(row.model.allChildren.map(\.chainAsset)))
                for child in row.model.children {
                    presenter.didReceiveAccountInfo(
                        result: .success(AccountInfo(ethBalance: 1_000_000)),
                        for: child.chainAsset
                    )
                }
            }
            drainPortfolioDeliveries()
            sheet.actions[0].handler?()
            XCTAssertTrue(interactor.hiddenAssets.isEmpty)
        }
    }

    @MainActor
    func testNativeGroupHideFitsLocalizedWindowsAndCancelsWithoutWrites() async throws {
        for localeId in ["en", "ru", "ja"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let (presenter, view, router, interactor, wallet) = try tokenPresenter(
                    fundedCount: 2,
                    localeId: localeId,
                    drainDeliveries: false
                )
                await settleGroup { view.models.last?.tokenRows.isEmpty == false }
                router.presentsNativeGroupActions = true
                let window = try await groupWindow(view: view, presenter: presenter, category: category)
                defer { window.isHidden = true; window.rootViewController = nil }
                let row = try XCTUnwrap(view.models.last?.tokenRows.first)
                presenter.didTapTokenAction(actionType: .hide, groupId: row.model.id, walletId: wallet.metaId)
                let sheet = try XCTUnwrap(view.controller.presentedViewController as? PortfolioGroupHideViewController)
                await settleGroup { !sheet.isBeingPresented && sheet.transitionCoordinator == nil }
                sheet.view.layoutIfNeeded()
                XCTAssertTrue(window.bounds.insetBy(dx: -1, dy: -1).contains(sheet.view.convert(
                    sheet.view.bounds,
                    to: window
                )))
                XCTAssertEqual(
                    sheet.confirmButton.configuration?.background.backgroundColor,
                    UIColor(named: "fwFillTop")
                )
                XCTAssertTrue(sheet.view.accessibilityViewIsModal)
                XCTAssertTrue(sheet.titleLabel.accessibilityTraits.contains(.header))
                for label in [sheet.titleLabel, sheet.messageLabel] {
                    XCTAssertGreaterThanOrEqual(
                        label.bounds.height + 1,
                        label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height
                    )
                    XCTAssertLessThanOrEqual(label.bounds.width, 280)
                }
                XCTAssertEqual(
                    sheet.messageLabel.font.pointSize,
                    UIFont.preferredFont(forTextStyle: .body, compatibleWith: sheet.traitCollection).pointSize,
                    accuracy: 0.5
                )
                captureGroup(window: window, name: "hide-\(localeId)-\(category.rawValue)")
                for button in [sheet.confirmButton, sheet.cancelButton] {
                    let label = try XCTUnwrap(button.titleLabel)
                    XCTAssertEqual(
                        label.font.pointSize,
                        UIFont.preferredFont(forTextStyle: .headline, compatibleWith: button.traitCollection).pointSize,
                        accuracy: 0.5
                    )
                    XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                    XCTAssertTrue(button.bounds.insetBy(dx: -1, dy: -1).contains(label.convert(
                        label.bounds,
                        to: button
                    )))
                    sheet.scrollView.scrollRectToVisible(
                        button.convert(button.bounds, to: sheet.scrollView),
                        animated: false
                    )
                    sheet.view.layoutIfNeeded()
                    XCTAssertTrue(sheet.scrollView.bounds.insetBy(dx: -1, dy: -1).contains(button.convert(
                        button.bounds,
                        to: sheet.scrollView
                    )))
                    let hit = try XCTUnwrap(window.hitTest(
                        button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: window),
                        with: nil
                    ))
                    XCTAssertTrue(hit === button || hit.isDescendant(of: button))
                }
                if category.isAccessibilityCategory {
                    XCTAssertGreaterThan(sheet.scrollView.contentSize.height, sheet.scrollView.bounds.height)
                    captureGroup(window: window, name: "hide-\(localeId)-AX5-actions")
                }
                let closeHit = try XCTUnwrap(window.hitTest(
                    sheet.closeButton.convert(CGPoint(x: 22, y: 22), to: window),
                    with: nil
                ))
                XCTAssertTrue(closeHit === sheet.closeButton || closeHit.isDescendant(of: sheet.closeButton))
                if #available(iOS 17.0, *), category == .large {
                    sheet.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
                    sheet.updateTraitsIfNeeded()
                    sheet.view.layoutIfNeeded()
                    XCTAssertEqual(
                        sheet.messageLabel.font.pointSize,
                        UIFont.preferredFont(forTextStyle: .body, compatibleWith: sheet.traitCollection).pointSize,
                        accuracy: 0.5
                    )
                }
                sheet.cancelButton.sendActions(for: .touchUpInside)
                await settleGroup { view.controller.presentedViewController == nil }
                XCTAssertTrue(interactor.hiddenAssets.isEmpty)
            }
        }
    }

    @MainActor
    func testNativeGroupHideConfirmsOnceAfterDismissalAndRejectsStaleWallet() async throws {
        for action in ["confirm", "stale", "close", "escape"] {
            let (presenter, view, router, interactor, wallet) = try tokenPresenter(
                fundedCount: 2,
                drainDeliveries: false
            )
            await settleGroup { view.models.last?.tokenRows.isEmpty == false }
            router.presentsNativeGroupActions = true
            let window = try await groupWindow(view: view, presenter: presenter, category: .large)
            defer { window.isHidden = true; window.rootViewController = nil }
            let row = try XCTUnwrap(view.models.last?.tokenRows.first)
            presenter.didTapTokenAction(actionType: .hide, groupId: row.model.id, walletId: wallet.metaId)
            let sheet = try XCTUnwrap(view.controller.presentedViewController as? PortfolioGroupHideViewController)
            await settleGroup { !sheet.isBeingPresented && sheet.transitionCoordinator == nil }
            presenter.didTapTokenAction(actionType: .hide, groupId: row.model.id, walletId: wallet.metaId)
            XCTAssertTrue(view.controller.presentedViewController === sheet)
            XCTAssertNil(sheet.presentedViewController)
            if action == "stale" {
                presenter.handleWalletChanged(wallet: AccountGenerator.generateMetaAccount())
                presenter.handleWalletChanged(wallet: wallet)
            }
            switch action {
            case "close": sheet.closeButton.sendActions(for: .touchUpInside)
            case "escape": XCTAssertTrue(sheet.accessibilityPerformEscape())
            default:
                sheet.confirmButton.sendActions(for: .touchUpInside)
                sheet.confirmButton.sendActions(for: .touchUpInside)
                XCTAssertTrue(interactor.hiddenAssets.isEmpty, "The write must wait until dismissal completes")
            }
            await settleGroup { view.controller.presentedViewController == nil }
            if action == "confirm" {
                await settleGroup { interactor.hiddenAssets.count == row.model.children.count }
                XCTAssertEqual(Set(interactor.hiddenAssets), Set(row.model.children.map { $0.chainAsset.assetKey }))
                XCTAssertFalse(interactor.hiddenAssets.contains(row.model.zeroChildren[0].chainAsset.assetKey))
            } else {
                XCTAssertTrue(interactor.hiddenAssets.isEmpty)
            }
        }
    }

    @MainActor
    func testNativeGroupNetworkChoicesFitAndRouteExactAssetsAfterDismissalOnce() async throws {
        for action in [SwipableCellButtonType.send, .receive] {
            for localeId in ["en", "ru", "ja"] {
                for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                    let (presenter, view, router, _, wallet) = try tokenPresenter(
                        fundedCount: 2,
                        localeId: localeId,
                        drainDeliveries: false
                    )
                    await settleGroup { view.models.last?.tokenRows.isEmpty == false }
                    router.presentsNativeGroupActions = true
                    let window = try await groupWindow(view: view, presenter: presenter, category: category)
                    defer { window.isHidden = true; window.rootViewController = nil }
                    let row = try XCTUnwrap(view.models.last?.tokenRows.first)
                    presenter.didTapTokenAction(actionType: action, groupId: row.model.id, walletId: wallet.metaId)
                    let navigation = try XCTUnwrap(view.controller.presentedViewController as? UINavigationController)
                    let picker = try XCTUnwrap(navigation.topViewController as? PortfolioFundingPickerViewController)
                    await settleGroup { !navigation.isBeingPresented && navigation.transitionCoordinator == nil }
                    picker.view.layoutIfNeeded()
                    navigation.view.layoutIfNeeded()
                    let bar = navigation.navigationBar
                    let barFrame = bar.convert(bar.bounds, to: window)
                    var pendingViews = bar.subviews
                    var controls: [UIControl] = []
                    while let child = pendingViews.popLast() {
                        pendingViews += child.subviews
                        if let control = child as? UIControl, !control.isHidden,
                           control.bounds.width > 1, control.bounds.height > 1 {
                            controls.append(control)
                        }
                    }
                    let geometry =
                        XCTAttachment(
                            string: "window=\(window.bounds), safe=\(window.safeAreaInsets); nav=\(navigation.view.frame), safe=\(navigation.view.safeAreaInsets); bar=\(barFrame); controls=" +
                                controls.map {
                                    "\(type(of: $0)): \($0.convert($0.bounds, to: window)); label=\($0.accessibilityLabel ?? "nil")"
                                }.joined(separator: "\n")
                        )
                    var accessibilityViews = [bar as UIView]
                    var accessibilityRows: [String] = []
                    while let child = accessibilityViews.popLast() {
                        accessibilityViews += child.subviews
                        accessibilityRows.append("\(type(of: child)): label=\(child.accessibilityLabel ?? "nil"); element=\(child.isAccessibilityElement); frame=\(child.convert(child.bounds, to: window)); elements=\(String(describing: child.accessibilityElements))")
                    }
                    let accessibility = XCTAttachment(string: accessibilityRows.joined(separator: "\n"))
                    accessibility.name = "token-group-accessibility-\(action)-\(localeId)-\(category.rawValue)"
                    accessibility.lifetime = .keepAlways
                    add(accessibility)
                    geometry.name = "token-group-bar-\(action)-\(localeId)-\(category.rawValue)"
                    geometry.lifetime = .keepAlways
                    add(geometry)
                    XCTAssertTrue(
                        window.bounds.contains(barFrame),
                        "The native bar must stay inside the presenting window"
                    )
                    // UIKit 27 exposes native bar accessibility separately from its private UIView tree.
                    // Assert the public item semantics and actual leading hit targets independently.
                    let closeItem = try XCTUnwrap(picker.navigationItem.leftBarButtonItem)
                    XCTAssertEqual(closeItem.accessibilityLabel, PortfolioStrings.text(
                        "common.cancel", locale: Locale(identifier: localeId)
                    ))
                    XCTAssertNotNil(closeItem.image)
                    XCTAssertTrue(closeItem.isEnabled)
                    let closeControls = controls.filter {
                        $0.convert($0.bounds, to: window).midX < barFrame.minX + barFrame.width / 4
                    }
                    XCTAssertFalse(closeControls.isEmpty, "The leading native close control must be rendered")
                    for control in controls {
                        let frame = control.convert(control.bounds, to: window)
                        XCTAssertTrue(
                            window.bounds.insetBy(dx: -1, dy: -1).contains(frame),
                            "The full native close hit target must be visible: \(frame)"
                        )
                        if closeControls.contains(where: { $0 === control }) {
                            let hit = try XCTUnwrap(window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil))
                            let hitDetails = XCTAttachment(string:
                                "probe=\(type(of: control)); hit=\(type(of: hit)); hitFrame=\(hit.convert(hit.bounds, to: window))"
                            )
                            hitDetails.name = "token-group-close-hit-\(action)-\(localeId)-\(category.rawValue)"
                            hitDetails.lifetime = .keepAlways
                            add(hitDetails)
                            XCTAssertTrue(closeControls.contains {
                                hit === $0 || hit.isDescendant(of: $0)
                            }, "The center must resolve to the native leading close control")
                        }
                    }
                    let options = try XCTUnwrap(router.fundingOptions.last)
                    XCTAssertEqual(options.count, action == .send ? 2 : 3)
                    captureGroup(window: window, name: "\(action)-\(localeId)-\(category.rawValue)")
                    for index in options.indices {
                        let path = IndexPath(row: index, section: 0)
                        picker.tableView.scrollToRow(at: path, at: .middle, animated: false)
                        picker.view.layoutIfNeeded()
                        let cell = try XCTUnwrap(picker.tableView.cellForRow(at: path))
                        XCTAssertGreaterThanOrEqual(cell.bounds.height, 44)
                        var descendants = cell.subviews
                        while let child = descendants.popLast() {
                            descendants += child.subviews
                            if let label = child as? UILabel, label.text?.isEmpty == false {
                                XCTAssertGreaterThanOrEqual(
                                    label.bounds.height + 1,
                                    label.sizeThatFits(CGSize(
                                        width: label.bounds.width,
                                        height: .greatestFiniteMagnitude
                                    )).height
                                )
                            }
                        }
                        let hit = try XCTUnwrap(window.hitTest(
                            cell.convert(CGPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: window),
                            with: nil
                        ))
                        XCTAssertTrue(hit === cell || hit.isDescendant(of: cell))
                    }
                    let choice = try XCTUnwrap(options.last)
                    let expected = try XCTUnwrap(row.model.allChildren.first {
                        $0.chainAsset.asset.symbolUppercased + " · " + $0.networkName == choice.title
                    })
                    let last = IndexPath(row: options.count - 1, section: 0)
                    picker.tableView(picker.tableView, didSelectRowAt: last)
                    picker.tableView(picker.tableView, didSelectRowAt: last)
                    XCTAssertTrue(router.sentAssets.isEmpty && router.receivedAssets.isEmpty)
                    await settleGroup { view.controller.presentedViewController == nil }
                    await settleGroup { !(action == .send ? router.sentAssets : router.receivedAssets).isEmpty }
                    XCTAssertEqual(
                        action == .send ? router.sentAssets : router.receivedAssets,
                        [expected.chainAsset.assetKey]
                    )
                }
            }
        }
    }

    @MainActor
    func testNativeGroupPickerCannotRouteAfterWalletReturnsOrCancel() async throws {
        for stale in [false, true] {
            let (presenter, view, router, _, wallet) = try tokenPresenter(fundedCount: 2, drainDeliveries: false)
            await settleGroup { view.models.last?.tokenRows.isEmpty == false }
            router.presentsNativeGroupActions = true
            let window = try await groupWindow(view: view, presenter: presenter, category: .large)
            defer { window.isHidden = true; window.rootViewController = nil }
            let row = try XCTUnwrap(view.models.last?.tokenRows.first)
            presenter.didTapTokenAction(actionType: .receive, groupId: row.model.id, walletId: wallet.metaId)
            let navigation = try XCTUnwrap(view.controller.presentedViewController as? UINavigationController)
            let picker = try XCTUnwrap(navigation.topViewController as? PortfolioFundingPickerViewController)
            await settleGroup { !navigation.isBeingPresented && navigation.transitionCoordinator == nil }
            if stale {
                presenter.handleWalletChanged(wallet: AccountGenerator.generateMetaAccount())
                presenter.handleWalletChanged(wallet: wallet)
                presenter.didReceiveChainAssets(result: .success(row.model.allChildren.map(\.chainAsset)))
                for child in row.model.children {
                    presenter.didReceiveAccountInfo(
                        result: .success(AccountInfo(ethBalance: 1_000_000)),
                        for: child.chainAsset
                    )
                }
                await settleGroup {
                    view.models.last?.walletId == wallet.metaId && view.models.last?.tokenRows.isEmpty == false
                }
                picker.tableView(picker.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
            } else {
                let close = try XCTUnwrap(picker.navigationItem.leftBarButtonItem)
                try UIApplication.shared.sendAction(XCTUnwrap(close.action), to: close.target, from: close, for: nil)
            }
            await settleGroup { view.controller.presentedViewController == nil }
            XCTAssertTrue(router.receivedAssets.isEmpty)
        }
    }

    @MainActor
    private func groupWindow(
        view: PortfolioViewSpy,
        presenter: ChainAssetListPresenter,
        category: UIContentSizeCategory
    ) async throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = category
        }
        let controller = ChainAssetListViewController(
            bannersViewController: nil, output: presenter, keyboardAdoptable: false,
            localizationManager: LocalizationManager.shared
        )
        view.controller = controller
        window.rootViewController = controller
        window.makeKeyAndVisible()
        if let model = view.models.last { controller.didReceive(viewModel: model) }
        controller.view.layoutIfNeeded()
        await settleGroup { window.isKeyWindow && controller.view.window === window }
        await Task.yield()
        window.layoutIfNeeded()
        return window
    }

    @MainActor
    private func settleGroup(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0 ..< 300 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), "Expected native group action transition to finish", file: file, line: line)
    }

    @MainActor
    private func captureGroup(window: UIWindow, name: String) {
        let capture = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        })
        capture.name = "token-group-320x568-" + name
        capture.lifetime = .keepAlways
        add(capture)
    }

    @MainActor
    func testPresenterLensChangeRequiresSelectedWallet() throws {
        let (presenter, view, _, _, wallet) = try tokenPresenter(fundedCount: 1)
        defer { UserDefaults.standard.removeObject(forKey: "portfolio.lens:\(wallet.metaId)") }
        presenter.didSelectLens(.network, walletId: "another-wallet")
        drainPortfolioDeliveries()
        XCTAssertEqual(view.models.last?.lens, .token)
        presenter.didSelectLens(.network, walletId: wallet.metaId)
        drainPortfolioDeliveries()
        XCTAssertEqual(view.models.last?.lens, .network)
        XCTAssertEqual(PortfolioCollapseStore().lens(walletId: wallet.metaId), .network)
    }

    @MainActor
    private func tokenPresenter(fundedCount: Int, localeId: String = "en", drainDeliveries: Bool = true) throws -> (ChainAssetListPresenter, PortfolioViewSpy, ChainAssetListRouterSpy, ChainAssetListInteractorInputSpy, MetaAccountModel) {
        let assets = try SendNetworkFixture.assets().filter { CanonicalTokenGroupCatalog.bundled.group(for: $0)?.id == "usdt" }.sorted { $0.chain.name < $1.chain.name }
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = ChainAssetListInteractorInputSpy(), router = ChainAssetListRouterSpy(), view = PortfolioViewSpy()
        let presenter = ChainAssetListPresenter(interactor: interactor, router: router, localizationManager: try XCTUnwrap(LocalizationManager(localization: localeId)), wallet: wallet, viewModelFactory: makeFactory())
        presenter.didLoad(view: view)
        presenter.didReceiveChainAssets(result: .success(assets))
        assets.prefix(fundedCount).forEach { presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 1_000_000)), for: $0) }
        if drainDeliveries { drainPortfolioDeliveries() }
        return (presenter, view, router, interactor, wallet)
    }

    private func drainPortfolioDeliveries() {
        let drained = expectation(description: "portfolio deliveries")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
    }

    func testQueuedPortfolioViewCannotReturnAfterSwitchAwayAndBack() {
        let wallet = AccountGenerator.generateMetaAccount()
        let other = AccountGenerator.generateMetaAccount()
        let presenter = ChainAssetListPresenter(interactor: ChainAssetListInteractorInputSpy(), router: ChainAssetListRouterSpy(), localizationManager: LocalizationManager.shared, wallet: wallet, viewModelFactory: makeFactory())
        let view = PortfolioViewSpy()
        presenter.didLoad(view: view)
        let asset = makeChainAsset(chain: makeChain(name: "Old wallet network"), id: "old", symbol: "OLD")
        presenter.didReceiveChainAssets(result: .success([asset]))
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 100)), for: asset)
        presenter.handleWalletChanged(wallet: other)
        presenter.handleWalletChanged(wallet: wallet)
        let flushed = expectation(description: "main deliveries drained")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 2)
        XCTAssertEqual(view.models.count, 1)
        XCTAssertEqual(view.models.first?.walletId, wallet.metaId)
        XCTAssertTrue(view.models.first?.displayState.rows.isEmpty == true)
    }

    func testUnrelatedWalletMetadataEventDoesNotSelectAnotherWallet() {
        let wallet = AccountGenerator.generateMetaAccount()
        let presenter = ChainAssetListPresenter(interactor: ChainAssetListInteractorInputSpy(), router: ChainAssetListRouterSpy(), localizationManager: LocalizationManager.shared, wallet: wallet, viewModelFactory: makeFactory())
        let view = PortfolioViewSpy()
        presenter.didLoad(view: view)
        presenter.didReceiveWallet(wallet: AccountGenerator.generateMetaAccount())
        presenter.didReceiveChainAssets(result: .success([]))
        let flushed = expectation(description: "main deliveries drained")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 2)
        XCTAssertEqual(view.models.last?.walletId, wallet.metaId)
    }

    func testPortfolioCallbackScopeDropsQueuedAndLatePreviousRequests() {
        let scope = PortfolioCallbackScope()
        let old = scope.snapshot()
        var delivered: [String] = []
        scope.deliver(old) { delivered.append("queued old") }
        scope.invalidate()
        let current = scope.invalidate()
        scope.deliver(old) { delivered.append("late old") }
        let done = expectation(description: "current delivered")
        scope.deliver(current) {
            XCTAssertTrue(Thread.isMainThread)
            delivered.append("current")
            done.fulfill()
        }
        wait(for: [done], timeout: 2)
        XCTAssertEqual(delivered, ["current"])
        XCTAssertFalse(scope.isCurrent(old))
    }

    func testSubscriptionRetainsOriginalWalletAndRejectsCallbacksAfterSwitch() throws {
        let firstWallet = AccountGenerator.generateMetaAccount()
        let secondWallet = AccountGenerator.generateMetaAccount()
        let asset = makeChainAsset(chain: makeChain(name: "Shared network"), id: "native", symbol: "NAT")
        let firstAccount = try XCTUnwrap(firstWallet.fetch(for: asset.chain.accountRequest()))
        let secondAccount = try XCTUnwrap(secondWallet.fetch(for: asset.chain.accountRequest()))
        let scope = PortfolioCallbackScope()
        var received: [String] = []
        let firstListener = PortfolioAccountInfoListener(wallet: firstWallet, scope: scope) { _, _ in received.append("old") }
        firstListener.handleAccountInfo(result: .success(AccountInfo(ethBalance: 100)), accountId: firstAccount.accountId, chainAsset: asset)
        scope.invalidate()
        let done = expectation(description: "current account delivered")
        let secondListener = PortfolioAccountInfoListener(wallet: secondWallet, scope: scope) { result, returnedAsset in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(returnedAsset.assetKey, asset.assetKey)
            XCTAssertEqual(try? result.get(), AccountInfo(ethBalance: 5))
            received.append("new")
            done.fulfill()
        }
        firstListener.handleAccountInfo(result: .success(AccountInfo(ethBalance: 999)), accountId: firstAccount.accountId, chainAsset: asset)
        secondListener.handleAccountInfo(result: .success(AccountInfo(ethBalance: 999)), accountId: firstAccount.accountId, chainAsset: asset)
        secondListener.handleAccountInfo(result: .success(AccountInfo(ethBalance: 5)), accountId: secondAccount.accountId, chainAsset: asset)
        wait(for: [done], timeout: 2)
        XCTAssertEqual(received, ["new"])
    }

    override func setUp() {
        super.setUp()
        ExactAssetPriceCache.shared.clear()
        MultiChainFeaturePolicy.update(
            FeatureToggleConfig(
                pendulumCaseEnabled: false,
                nftEnabled: true,
                assetDiscoveryShadowMode: false
            )
        )
    }

    override func tearDown() {
        ExactAssetPriceCache.shared.clear()
        MultiChainFeaturePolicy.update(.defaultConfig)
        super.tearDown()
    }

    func testUseWalletSeedActionRunsExactlyOnceAfterDismissal() throws {
        var adoptionCalls = 0
        let viewModel = ChainAssetListPresenter.makeUniversalWalletSetupViewModel(
            locale: Locale(identifier: "en_US"),
            useStoredSeed: { adoptionCalls += 1 }
        )
        let action = try XCTUnwrap(
            viewModel.actions.first(where: { $0.title == "Add from wallet phrase" })
        )

        action.handler?()
        XCTAssertEqual(adoptionCalls, 0, "Adoption must wait until the sheet is gone")

        viewModel.dismissCompletion?()
        viewModel.dismissCompletion?()

        XCTAssertEqual(
            adoptionCalls,
            1,
            "The confirmed action must survive dismissal and remain one-shot"
        )
    }

    func testUseWalletSeedActionSurvivesDismissCompletionBeforeHandler() throws {
        var adoptionCalls = 0
        let viewModel = ChainAssetListPresenter.makeUniversalWalletSetupViewModel(
            locale: Locale(identifier: "en_US"),
            useStoredSeed: { adoptionCalls += 1 }
        )
        let action = try XCTUnwrap(
            viewModel.actions.first(where: { $0.title == "Add from wallet phrase" })
        )

        // SheetAlertViewLayout begins dismissal before invoking the selected
        // action handler. Exercise the worst-case ordering directly so the
        // tap cannot be lost when dismissal completes immediately.
        viewModel.dismissCompletion?()
        action.handler?()
        action.handler?()

        XCTAssertEqual(adoptionCalls, 1)
    }

    func testUniversalWalletSetupCancelDoesNotStartAnyAction() {
        var adoptionCalls = 0
        let viewModel = ChainAssetListPresenter.makeUniversalWalletSetupViewModel(
            locale: Locale(identifier: "en_US"),
            useStoredSeed: { adoptionCalls += 1 }
        )

        viewModel.dismissCompletion?()

        XCTAssertEqual(adoptionCalls, 0)
    }

    func testUniversalWalletSetupOffersOnlyTheWalletRootPhrase() throws {
        var adoptionCalls = 0
        let viewModel = ChainAssetListPresenter.makeUniversalWalletSetupViewModel(
            locale: Locale(identifier: "en_US"),
            useStoredSeed: { adoptionCalls += 1 }
        )

        XCTAssertEqual(viewModel.actions.map(\.title), ["Add from wallet phrase"])
        XCTAssertTrue(viewModel.message?.contains("no new phrase") == true)
    }

    func testUniversalWalletRecoveryOffersOnlyTheOriginalWalletPhrase() throws {
        var importCalls = 0
        var walletListOpens = 0
        let viewModel = ChainAssetListPresenter.makeUniversalWalletRecoveryViewModel(
            locale: Locale(identifier: "en_US"),
            importWalletPhrase: { importCalls += 1 },
            openWalletList: { walletListOpens += 1 }
        )
        let importAction = try XCTUnwrap(
            viewModel.actions.first(where: { $0.title == "Enter wallet recovery phrase" })
        )

        importAction.handler?()
        XCTAssertEqual(importCalls, 0)
        viewModel.dismissCompletion?()

        XCTAssertEqual(importCalls, 1)
        XCTAssertEqual(walletListOpens, 0)
        // The wallet's own phrase, or a phrase wallet from the wallet list for a wallet that
        // never had one; never a new phrase for this wallet.
        XCTAssertEqual(viewModel.actions.map(\.title), ["Enter wallet recovery phrase", "Open wallet list"])
        XCTAssertTrue(viewModel.message?.contains("second phrase is never created") == true)
    }

    func testUniversalWalletRecoveryWithoutAPhraseLeadsToTheWalletList() throws {
        var importCalls = 0
        var walletListOpens = 0
        let viewModel = ChainAssetListPresenter.makeUniversalWalletRecoveryViewModel(
            locale: Locale(identifier: "en_US"),
            importWalletPhrase: { importCalls += 1 },
            openWalletList: { walletListOpens += 1 }
        )

        try XCTUnwrap(viewModel.actions.first(where: { $0.title == "Open wallet list" })).handler?()
        viewModel.dismissCompletion?()

        XCTAssertEqual(importCalls, 0)
        XCTAssertEqual(walletListOpens, 1)
        XCTAssertTrue(viewModel.message?.contains("raw seed or JSON file") == true)
    }

    func testEveryStoredSeedAdoptionErrorHasVisibleContent() {
        let errors: [UniversalWalletStoredSeedAdopter.AdoptionError] = [
            .storedWalletSeedUnavailable,
            .unsupportedSecretSource,
            .conflictingUniversalWalletAccount
        ]

        errors.forEach { error in
            guard let convertible = error as? ErrorContentConvertible else {
                return XCTFail("\(error) would be silently discarded by ErrorPresentable")
            }

            let content = convertible.toErrorContent(for: Locale(identifier: "en_US"))
            XCTAssertFalse(content.title.isEmpty)
            XCTAssertFalse(content.message.isEmpty)
        }
    }

    func testUnexpectedStoredSeedFailureGetsVisibleRecoveryInstructions() throws {
        let presentable = ChainAssetListPresenter.presentableStoredSeedAdoptionError(
            KeystoreError.unexpectedFail,
            locale: Locale(identifier: "en_US")
        )
        let convertible = try XCTUnwrap(presentable as? ErrorContentConvertible)
        let content = convertible.toErrorContent(for: Locale(identifier: "en_US"))

        XCTAssertFalse(content.title.isEmpty)
        XCTAssertTrue(content.message.contains("wallet seed"))
        XCTAssertTrue(content.message.contains("recovery phrase"))
    }

    func testMissingStoredSeedRoutesToUniversalWalletRecoveryImport() {
        XCTAssertTrue(
            ChainAssetListPresenter.requiresUniversalWalletRecoveryImport(
                for: UniversalWalletStoredSeedAdopter.AdoptionError.storedWalletSeedUnavailable
            )
        )
        XCTAssertFalse(
            ChainAssetListPresenter.requiresUniversalWalletRecoveryImport(
                for: UniversalWalletStoredSeedAdopter.AdoptionError.unsupportedSecretSource
            )
        )
        XCTAssertFalse(
            ChainAssetListPresenter.requiresUniversalWalletRecoveryImport(
                for: KeystoreError.unexpectedFail
            )
        )
    }

    func testMissingStoredSeedCallbackRoutesOnlyOriginalPhraseForSelectedBitcoinChain() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = ChainAssetListInteractorInputSpy()
        let router = ChainAssetListRouterSpy()
        let languages = LocalizationManager.shared.selectedLocale.rLanguages
        let presenter = ChainAssetListPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            wallet: wallet,
            viewModelFactory: makeFactory()
        )

        presenter.didTapResolveAccountIssue(
            for: UniversalWalletRegistry.bitcoinMainnetChainModel
        )
        let setup = try XCTUnwrap(router.presentedSetupViewModels.last)
        let useStoredSeed = try XCTUnwrap(
            setup.actions.first(where: {
                $0.title == R.string.localizable.universalSetupAction(preferredLanguages: languages)
            })
        )
        useStoredSeed.handler?()
        setup.dismissCompletion?()

        XCTAssertEqual(interactor.storedSeedAdoptionCalls, 1)

        presenter.didTapResolveAccountIssue(for: UniversalWalletRegistry.tairaChainModel)
        XCTAssertEqual(
            router.presentedSetupViewModels.count,
            1,
            "A second recovery sheet must not replace an in-flight adoption target"
        )

        presenter.didAdoptStoredWalletSeed(
            result: .failure(
                UniversalWalletStoredSeedAdopter.AdoptionError.storedWalletSeedUnavailable
            )
        )

        XCTAssertTrue(router.importedChainModels.isEmpty)
        XCTAssertTrue(router.createdChainModels.isEmpty)
        XCTAssertEqual(router.presentedSetupViewModels.count, 2)
        let recovery = try XCTUnwrap(router.presentedSetupViewModels.last)
        XCTAssertEqual(recovery.actions.map(\.title), [
            R.string.localizable.universalRecoveryAction(preferredLanguages: languages),
            R.string.localizable.universalOpenWalletsAction(preferredLanguages: languages)
        ])

        let importAction = try XCTUnwrap(
            recovery.actions.first(where: {
                $0.title == R.string.localizable.universalRecoveryAction(preferredLanguages: languages)
            })
        )
        importAction.handler?()
        recovery.dismissCompletion?()

        let routedModel = try XCTUnwrap(router.importedChainModels.last)
        XCTAssertEqual(routedModel.meta.metaId, wallet.metaId)
        XCTAssertEqual(
            routedModel.chain.chainId,
            UniversalWalletRegistry.bitcoinMainnet.chainId
        )
        XCTAssertTrue(router.createdChainModels.isEmpty)
        XCTAssertEqual(router.presentedErrors.count, 0)
    }

    /// IOSUX-7: the captions under the list and the hidden-funds notice lead to Manage assets on
    /// every network, whatever the portfolio filter shows, because the header they explain is
    /// wallet-wide. "Keep hidden" only retires the notice: nothing is unhidden or written.
    func testExclusionCaptionsAndHiddenFundsNoticeOpenManageOnEveryNetwork() {
        let wallet = AccountGenerator.generateMetaAccount()
            .replacingNetworkManagmentFilter(NetworkManagmentFilter.popular.identifier)
        let router = ChainAssetListRouterSpy()
        let presenter = ChainAssetListPresenter(
            interactor: ChainAssetListInteractorInputSpy(),
            router: router,
            localizationManager: LocalizationManager.shared,
            wallet: wallet,
            viewModelFactory: makeFactory()
        )
        let chainAsset = makeChainAsset(chain: makeChain(name: "Kept"), id: "kept", symbol: "KPT")
        let walletId = wallet.metaId
        defer {
            UserDefaults.standard.removeObject(forKey: "asset.presentation.hidden_funds_reviewed:\(walletId)")
        }

        presenter.didTapHiddenAssetsNotIncluded()
        presenter.didTapTestnetAssetsNotIncluded()
        presenter.didTapReviewHiddenFunds()
        presenter.didTapKeepHiddenFunds(assetKeys: [chainAsset.assetKey])

        XCTAssertEqual(router.manageAssetFilters, ["all", "all", "all"])
        XCTAssertEqual(router.manageVisibilityFilters, [.hidden, .all, .hidden])
        XCTAssertTrue(
            AssetVisibilityPreferenceStore.reviewedHiddenFunds(walletId: walletId).contains(chainAsset.assetKey)
        )
        XCTAssertEqual(
            AssetVisibilityPreferenceStore.preference(walletId: walletId, assetKey: chainAsset.assetKey),
            .auto,
            "Keep hidden writes no preference"
        )
    }

    func testCancelledRecoverySheetDoesNotLeaveAStaleImportTarget() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = ChainAssetListInteractorInputSpy()
        let router = ChainAssetListRouterSpy()
        let presenter = ChainAssetListPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            wallet: wallet,
            viewModelFactory: makeFactory()
        )

        presenter.didTapResolveAccountIssue(
            for: UniversalWalletRegistry.bitcoinMainnetChainModel
        )
        let setup = try XCTUnwrap(router.presentedSetupViewModels.last)
        setup.dismissCompletion?()

        XCTAssertEqual(interactor.storedSeedAdoptionCalls, 0)

        presenter.didAdoptStoredWalletSeed(
            result: .failure(
                UniversalWalletStoredSeedAdopter.AdoptionError.storedWalletSeedUnavailable
            )
        )

        XCTAssertTrue(router.importedChainModels.isEmpty)
        XCTAssertEqual(router.presentedErrors.count, 1)
    }

    func testStoredSeedAdoptionOperationCreatesBothAccounts() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let keychain = InMemoryKeychain()
        try keychain.saveKey(
            Data(repeating: 0x2A, count: UniversalWalletSeedBridge.walletSeedLength),
            with: fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        )
        try keychain.saveKey(
            Data(UniversalWalletSeedBridge.contract.utf8),
            with: fearless.KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
        )
        let completion = expectation(description: "stored seed adoption completed")
        var adoptionResult: MetaAccountModel?

        ChainAssetListInteractor.performStoredSeedAdoption(
            walletSnapshot: wallet,
            adopter: UniversalWalletStoredSeedAdopter(keystore: keychain),
            operationQueue: OperationQueue(),
            deliveryQueue: .main
        ) { result in
            adoptionResult = try? result.get()
            completion.fulfill()
        }

        wait(for: [completion], timeout: Constants.defaultExpectationDuration)
        let adoptedWallet = try XCTUnwrap(adoptionResult)
        XCTAssertTrue(
            UniversalWalletChainAccountSupport.hasValidDedicatedAccount(
                in: adoptedWallet,
                for: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        )
        XCTAssertTrue(
            UniversalWalletChainAccountSupport.hasValidDedicatedAccount(
                in: adoptedWallet,
                for: UniversalWalletRegistry.taira.chainId
            )
        )
    }

    func testStoredSeedAdoptedAccountsPersistAcrossSettingsReload() throws {
        let operationQueue = OperationQueue()
        let storageFacade = UserDataStorageTestFacade()
        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )
        let wallet = AccountGenerator.generateMetaAccount()
        let keychain = InMemoryKeychain()
        try keychain.saveKey(
            Data(repeating: 0x19, count: UniversalWalletSeedBridge.walletSeedLength),
            with: fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        )
        try keychain.saveKey(
            Data(UniversalWalletSeedBridge.contract.utf8),
            with: fearless.KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
        )

        let initialSave = expectation(description: "initial wallet saved")
        settings.save(value: wallet, runningCompletionIn: .main) { result in
            XCTAssertEqual(try? result.get(), wallet)
            initialSave.fulfill()
        }
        wait(for: [initialSave], timeout: Constants.defaultExpectationDuration)

        let adoption = expectation(description: "production adoption path persisted wallet")
        var adoptedWallet: MetaAccountModel?
        ChainAssetListInteractor.performAndPersistStoredSeedAdoption(
            walletSnapshot: wallet,
            adopter: UniversalWalletStoredSeedAdopter(keystore: keychain),
            operationQueue: operationQueue,
            walletSettings: settings,
            currentWallet: { wallet }
        ) { result in
            adoptedWallet = try? result.get()
            adoption.fulfill()
        }
        wait(for: [adoption], timeout: Constants.defaultExpectationDuration)

        let reloadedSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )
        let reload = expectation(description: "settings reloaded")
        var reloadedWallet: MetaAccountModel?
        reloadedSettings.setup(runningCompletionIn: .main) { result in
            reloadedWallet = try? result.get()
            reload.fulfill()
        }
        wait(for: [reload], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(reloadedWallet, adoptedWallet)
        // Bitcoin mainnet/testnet, Taira, Solana and TON, each derived from the bridged phrase, survive the reload.
        XCTAssertEqual(reloadedWallet?.chainAccounts.count, 5)
        XCTAssertEqual(
            reloadedWallet?.chainAccounts.filter { UniversalWalletChainAccountSupport.isValidSolanaAccount($0) }.count,
            1
        )
    }

    func testMissingStoredSeedFailsVisiblyWithoutMutatingPersistedWallet() throws {
        let operationQueue = OperationQueue()
        let storageFacade = UserDataStorageTestFacade()
        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )
        let wallet = AccountGenerator.generateMetaAccount()
        let initialSave = expectation(description: "initial wallet saved")
        settings.save(value: wallet, runningCompletionIn: .main) { result in
            XCTAssertEqual(try? result.get(), wallet)
            initialSave.fulfill()
        }
        wait(for: [initialSave], timeout: Constants.defaultExpectationDuration)

        let adoption = expectation(description: "missing stored seed reported")
        var adoptionError: Error?
        ChainAssetListInteractor.performAndPersistStoredSeedAdoption(
            walletSnapshot: wallet,
            adopter: UniversalWalletStoredSeedAdopter(keystore: InMemoryKeychain()),
            operationQueue: operationQueue,
            walletSettings: settings,
            currentWallet: { wallet }
        ) { result in
            if case let .failure(error) = result {
                adoptionError = error
            }
            adoption.fulfill()
        }
        wait(for: [adoption], timeout: Constants.defaultExpectationDuration)

        let error = try XCTUnwrap(adoptionError)
        XCTAssertEqual(
            error as? UniversalWalletStoredSeedAdopter.AdoptionError,
            .storedWalletSeedUnavailable
        )
        let presentable = ChainAssetListPresenter.presentableStoredSeedAdoptionError(
            error,
            locale: Locale(identifier: "en_US")
        )
        let content = try XCTUnwrap(presentable as? ErrorContentConvertible)
            .toErrorContent(for: Locale(identifier: "en_US"))
        XCTAssertFalse(content.message.isEmpty)
        XCTAssertEqual(settings.value, wallet)

        let reloadedSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )
        let reload = expectation(description: "unchanged wallet reloaded")
        var reloadedWallet: MetaAccountModel?
        reloadedSettings.setup(runningCompletionIn: .main) { result in
            reloadedWallet = try? result.get()
            reload.fulfill()
        }
        wait(for: [reload], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(reloadedWallet, wallet)
        XCTAssertTrue(reloadedWallet?.chainAccounts.isEmpty == true)
    }

    func testStoredSeedAdoptionPreservesNewerSelectedWalletPayload() throws {
        let operationQueue = OperationQueue()
        let storageFacade = UserDataStorageTestFacade()
        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )
        let walletSnapshot = AccountGenerator.generateMetaAccount()
        let newerWallet = walletSnapshot
            .replacingName("renamed while adoption was running")
            .replacingUnusedChainIds(["newer-unused-chain"])
        let keychain = InMemoryKeychain()
        try keychain.saveKey(
            Data(repeating: 0x37, count: UniversalWalletSeedBridge.walletSeedLength),
            with: fearless.KeystoreTagV2.substrateSeedTagForMetaId(walletSnapshot.metaId)
        )
        try keychain.saveKey(
            Data(UniversalWalletSeedBridge.contract.utf8),
            with: fearless.KeystoreTagV2.universalWalletSecretSourceTagForMetaId(walletSnapshot.metaId)
        )

        let initialSave = expectation(description: "newer wallet saved")
        settings.save(value: newerWallet, runningCompletionIn: .main) { result in
            XCTAssertEqual(try? result.get(), newerWallet)
            initialSave.fulfill()
        }
        wait(for: [initialSave], timeout: Constants.defaultExpectationDuration)

        let adoption = expectation(description: "adoption merged into newer wallet")
        var savedWallet: MetaAccountModel?
        ChainAssetListInteractor.performAndPersistStoredSeedAdoption(
            walletSnapshot: walletSnapshot,
            adopter: UniversalWalletStoredSeedAdopter(keystore: keychain),
            operationQueue: operationQueue,
            walletSettings: settings,
            currentWallet: { walletSnapshot }
        ) { result in
            savedWallet = try? result.get()
            adoption.fulfill()
        }
        wait(for: [adoption], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(savedWallet?.name, newerWallet.name)
        XCTAssertEqual(savedWallet?.unusedChainIds, newerWallet.unusedChainIds)
        XCTAssertEqual(savedWallet?.chainAccounts.count, 5, "Bitcoin mainnet/testnet, Taira, Solana and TON")

        let reloadedSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )
        let reload = expectation(description: "merged wallet reloaded")
        var reloadedWallet: MetaAccountModel?
        reloadedSettings.setup(runningCompletionIn: .main) { result in
            reloadedWallet = try? result.get()
            reload.fulfill()
        }
        wait(for: [reload], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(reloadedWallet, savedWallet)
    }

    func testStoredSeedAdoptionDeliversSuccessAfterFinishedOperationIsReleased() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let updatedWallet = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: wallet,
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let completionDelivered = expectation(description: "completion delivered")
        let deliveryQueue = DispatchQueue(label: "test.stored-seed-adoption.delivery")
        deliveryQueue.suspend()
        var operation: ClosureOperation<MetaAccountModel>? = ClosureOperation {
            updatedWallet
        }
        operation?.start()
        weak var weakOperation = operation

        ChainAssetListInteractor.deliverStoredSeedAdoptionResult(
            from: operation,
            deliveryQueue: deliveryQueue
        ) { result in
            XCTAssertEqual(try? result.get(), updatedWallet)
            completionDelivered.fulfill()
        }

        operation = nil
        XCTAssertNil(
            weakOperation,
            "The queued result must not rely on retaining the finished operation"
        )

        deliveryQueue.resume()
        wait(for: [completionDelivered], timeout: 1)
    }

    func testStoredSeedAdoptionDeliversFailureAfterFinishedOperationIsReleased() {
        let completionDelivered = expectation(description: "failure delivered")
        let deliveryQueue = DispatchQueue(label: "test.stored-seed-adoption.failure-delivery")
        deliveryQueue.suspend()
        var operation: ClosureOperation<MetaAccountModel>? = ClosureOperation {
            throw StoredSeedAdoptionTestError.expected
        }
        operation?.start()
        weak var weakOperation = operation

        ChainAssetListInteractor.deliverStoredSeedAdoptionResult(
            from: operation,
            deliveryQueue: deliveryQueue
        ) { result in
            switch result {
            case .success:
                XCTFail("The adopter failure must survive operation deallocation")
            case let .failure(error):
                XCTAssertEqual(error as? StoredSeedAdoptionTestError, .expected)
            }
            completionDelivered.fulfill()
        }

        operation = nil
        XCTAssertNil(weakOperation)

        deliveryQueue.resume()
        wait(for: [completionDelivered], timeout: 1)
    }

    func testStoredSeedAdoptionMergesAccountsIntoNewerWalletPayload() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let adoptedWallet = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: wallet,
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let currentWallet = wallet
            .replacingName("renamed while adoption was running")
            .replacingUnusedChainIds(["a-new-unused-chain"])

        let mergedWallet = try ChainAssetListInteractor.mergeStoredSeedAdoption(
            adoptedWallet,
            into: currentWallet
        )

        XCTAssertEqual(mergedWallet.name, currentWallet.name)
        XCTAssertEqual(mergedWallet.unusedChainIds, currentWallet.unusedChainIds)
        XCTAssertEqual(
            mergedWallet.chainAccounts,
            adoptedWallet.chainAccounts
        )
    }

    func testStoredSeedAdoptionPreservesConcurrentNativeTonIdentity() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let adopted = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: wallet, mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        var current = wallet
        current.legacyTonAccount = try LegacyNativeTonFixture.account()
        let merged = try ChainAssetListInteractor.mergeStoredSeedAdoption(adopted, into: current)
        XCTAssertEqual(merged.legacyTonAccount, current.legacyTonAccount)
        XCTAssertFalse(merged.chainAccounts.contains {
            UniversalWalletChainAccountSupport.chainId($0.chainId, matches: TonChainSelection.mainnetChainId)
        })
        XCTAssertEqual(merged.chainAccounts.count, 4)
    }

    func testStoredSeedAdoptionPreservesConcurrentDedicatedKeysForNewNetworks() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let adopted = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: wallet, mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let independent = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: wallet, mnemonic: "letter advice cage absurd amount doctor acoustic avoid letter advice cage above"
        )
        let dedicated = Set(independent.chainAccounts.filter {
            $0.chainId != UniversalWalletRegistry.bitcoinMainnet.chainId &&
                $0.chainId != UniversalWalletRegistry.taira.chainId
        })
        let current = wallet.replacingChainAccounts(dedicated)
        let merged = try ChainAssetListInteractor.mergeStoredSeedAdoption(adopted, into: current)
        XCTAssertTrue(dedicated.isSubset(of: merged.chainAccounts))
        XCTAssertEqual(merged.chainAccounts.count, 5)
        XCTAssertEqual(try ChainAssetListInteractor.mergeStoredSeedAdoption(adopted, into: merged), merged)
    }

    func testStoredSeedAdoptionRejectsConcurrentDifferentBitcoinAccount() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let adoptedWallet = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: wallet,
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let conflictingWallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: wallet,
            mnemonic: "letter advice cage absurd amount doctor acoustic avoid letter advice cage above"
        )

        XCTAssertThrowsError(
            try ChainAssetListInteractor.mergeStoredSeedAdoption(
                adoptedWallet,
                into: conflictingWallet
            )
        ) { error in
            XCTAssertEqual(
                error as? UniversalWalletStoredSeedAdopter.AdoptionError,
                .conflictingUniversalWalletAccount
            )
        }
    }

    func testStoredSeedAdoptionRejectsTwoIndependentlyChangedWalletPayloads() {
        let walletSnapshot = AccountGenerator.generateMetaAccount()
        let interactorWallet = walletSnapshot.replacingName("interactor rename")
        let selectedWallet = walletSnapshot.replacingUnusedChainIds(["settings change"])

        XCTAssertThrowsError(
            try ChainAssetListInteractor.storedSeedAdoptionMergeBase(
                walletSnapshot: walletSnapshot,
                interactorWallet: interactorWallet,
                selectedWallet: selectedWallet
            )
        ) { error in
            XCTAssertTrue(error is BaseOperationError)
        }
    }

    func testPersistedStoredSeedAdoptionRejectsDifferentValidAccounts() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let adoptedWallet = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: wallet,
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let conflictingWallet = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: wallet,
            mnemonic: "letter advice cage absurd amount doctor acoustic avoid letter advice cage above"
        )

        XCTAssertThrowsError(
            try ChainAssetListInteractor.validatePersistedStoredSeedAdoption(
                adoptedWallet,
                activeWallet: conflictingWallet
            )
        ) { error in
            XCTAssertEqual(
                error as? UniversalWalletStoredSeedAdopter.AdoptionError,
                .conflictingUniversalWalletAccount
            )
        }
    }

    func testProvisionedBitcoinAppearsInPortfolioAtZeroBalance() throws {
        let wallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let bitcoin = try XCTUnwrap(
            UniversalWalletRegistry.bitcoinMainnetChainModel.chainAssets.first
        )

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [bitcoin],
            locale: Locale(identifier: "en_US"),
            accountInfos: [:],
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )

        XCTAssertEqual(viewModel.displayState.rows.map(\.chainAsset.assetKey), [bitcoin.assetKey])
        XCTAssertEqual(viewModel.displayState.rows.first?.chainAsset.asset.symbol, "BTC")
    }

    /// Contract §4: a zero row needs an account on the network (`walletHoldsAccountFor`), so an
    /// accountless Bitcoin row is not a zero default (critique C2). The startup provisioning adds
    /// the account for every wallet with a stored phrase; for the rest, Bitcoin is one Show or
    /// one network filter away and the row then routes to the account setup.
    func testAccountlessBitcoinHasNoZeroRowUntilShownAndThenIsActionableSetup() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let bitcoin = try XCTUnwrap(
            UniversalWalletRegistry.bitcoinMainnetChainModel.chainAssets.first
        )
        let build = {
            self.makeFactory().buildViewModel(
                wallet: wallet,
                chainAssets: [bitcoin],
                locale: Locale(identifier: "en_US"),
                accountInfos: [:],
                chainsWithIssue: [],
                shouldRunManageAssetAnimate: false,
                displayType: .assetChains,
                chainSettings: [],
                networkFilter: nil,
                search: nil
            )
        }
        XCTAssertTrue(build().displayState.rows.isEmpty)

        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: wallet.metaId, assetKey: bitcoin.assetKey)
        defer {
            AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: bitcoin.assetKey)
        }
        let viewModel = build()

        let row = try XCTUnwrap(viewModel.displayState.rows.first)
        XCTAssertEqual(row.chainAsset.assetKey, bitcoin.assetKey)
        XCTAssertEqual(row.chainAsset.asset.symbol, "BTC")
        XCTAssertFalse(row.isColdBoot, "Bitcoin setup must not be presented as an endless balance load")
        XCTAssertFalse(row.swipeActionsEnabled, "Send and receive require the BIP-84 account first")
    }

    func testBitcoinNetworkRemainsVisibleWhileWalletNeedsAccountSetup() {
        let wallet = AccountGenerator.generateMetaAccount()
        let bitcoin = UniversalWalletRegistry.bitcoinMainnetChainModel

        let viewModel = NetworkManagmentViewModelFactoryImpl().createViewModel(
            wallet: wallet,
            chains: [bitcoin],
            selectedFilter: nil,
            initialFilter: .all,
            searchText: nil,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertTrue(viewModel.cells.contains(where: {
            $0.networkSelectType.identifier == bitcoin.chainId && $0.name == "Bitcoin"
        }))
    }

    func testBitcoinOnlyFilterShowsAccountSetupInsteadOfEmptyPortfolio() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let bitcoin = try XCTUnwrap(
            UniversalWalletRegistry.bitcoinMainnetChainModel.chainAssets.first
        )

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [bitcoin],
            locale: Locale(identifier: "en_US"),
            accountInfos: [:],
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .chain,
            chainSettings: [],
            networkFilter: .chain(bitcoin.chain.chainId),
            search: nil
        )

        guard case let .chainHasAccountIssue(chain) = viewModel.displayState else {
            return XCTFail("Bitcoin without a BIP-84 account must offer account setup")
        }
        XCTAssertEqual(chain.chainId, UniversalWalletRegistry.bitcoinMainnet.chainId)
    }

    /// A 4.0.4 native TON wallet and an EVM-only wallet cannot hold Bitcoin or Solana accounts:
    /// no setup is offered, and a Bitcoin or Solana network they open explains why and leads to
    /// the wallet list instead of claiming the wallet's phrase covers them.
    func testWalletsThatCannotHoldBitcoinOrSolanaAreLedToTheWalletList() throws {
        let tonWallet = try LegacyNativeTonFixture.wallet()
        for wallet in [tonWallet, ethereumOnlyWallet()] {
            for chain in [UniversalWalletRegistry.bitcoinMainnetChainModel, UniversalWalletRegistry.solanaMainnetChainModel] {
                let chainAsset = try XCTUnwrap(chain.chainAssets.first { $0.asset.isUtility })
                XCTAssertFalse(PortfolioVisibilityContext.offersAccountSetup(chainAsset, wallet: wallet))
                XCTAssertTrue(makeFactory().buildViewModel(
                    wallet: wallet, chainAssets: [chainAsset], locale: Locale(identifier: "en_US"),
                    accountInfos: [:], chainsWithIssue: [], shouldRunManageAssetAnimate: false,
                    displayType: .assetChains, chainSettings: [], networkFilter: nil, search: nil
                ).displayState.rows.isEmpty, "\(chain.name)")
                guard case .chainHasAccountIssue = makeFactory().buildViewModel(
                    wallet: wallet, chainAssets: [chainAsset], locale: Locale(identifier: "en_US"),
                    accountInfos: [:], chainsWithIssue: [], shouldRunManageAssetAnimate: false,
                    displayType: .chain, chainSettings: [], networkFilter: .chain(chain.chainId), search: nil
                ).displayState else {
                    return XCTFail("\(chain.name) opened alone must explain the missing account")
                }

                let interactor = ChainAssetListInteractorInputSpy()
                let router = ChainAssetListRouterSpy()
                let presenter = ChainAssetListPresenter(
                    interactor: interactor,
                    router: router,
                    localizationManager: LocalizationManager.shared,
                    wallet: wallet,
                    viewModelFactory: makeFactory()
                )

                presenter.didTapResolveAccountIssue(for: chain)

                let sheet = try XCTUnwrap(router.presentedSetupViewModels.last)
                let languages = LocalizationManager.shared.selectedLocale.rLanguages
                XCTAssertEqual(sheet.title, R.string.localizable.universalUnsupportedTitle(preferredLanguages: languages))
                XCTAssertEqual(
                    sheet.message,
                    R.string.localizable.universalUnsupportedMessage(preferredLanguages: languages),
                    "says the wallet came from a TON phrase or an Ethereum key, not that its phrase covers Bitcoin"
                )
                XCTAssertEqual(
                    sheet.actions.map(\.title),
                    [R.string.localizable.universalOpenWalletsAction(preferredLanguages: languages)]
                )
                sheet.actions.first?.handler?()
                sheet.dismissCompletion?()
                XCTAssertEqual(router.walletListOpens, 1)
                XCTAssertEqual(interactor.storedSeedAdoptionCalls, 0, "nothing is attempted on this wallet")
                XCTAssertTrue(router.importedChainModels.isEmpty)
                XCTAssertTrue(router.presentedErrors.isEmpty)
            }
        }
    }

    /// The setup and recovery copy is in every shipped locale, not English literals.
    func testUniversalSetupCopyIsTranslatedInEveryShippedLocale() {
        ShippedLocaleParity.assertTranslated(keys: [
            "universal.setup.title", "universal.setup.message", "universal.setup.action",
            "universal.recovery.title", "universal.recovery.message", "universal.recovery.action",
            "universal.open.wallets.action", "universal.unsupported.title", "universal.unsupported.message",
            "universal.unsupported.source.message", "universal.adoption.seed.unavailable",
            "universal.adoption.conflict", "universal.seed.unreadable", "universal.recovery.mismatch.title",
            "universal.recovery.mismatch.message", "universal.recovery.different.phrase.title",
            "universal.recovery.different.phrase.message"
        ])
        let russian = Locale(identifier: "ru")
        XCTAssertEqual(
            UniversalWalletStoredSeedAdopter.AdoptionError.unsupportedSecretSource.toErrorContent(for: russian).message,
            R.string.localizable.universalUnsupportedSourceMessage(preferredLanguages: russian.rLanguages)
        )
        XCTAssertNotEqual(
            ChainAssetListPresenter.makeUniversalWalletSetupViewModel(locale: russian, useStoredSeed: {}).title,
            "One recovery phrase"
        )
    }

    func testStoredSeedOfUnknownOriginLeadsToTheWalletListNotAFalseError() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = ChainAssetListInteractorInputSpy()
        let router = ChainAssetListRouterSpy()
        let presenter = ChainAssetListPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            wallet: wallet,
            viewModelFactory: makeFactory()
        )
        presenter.didTapResolveAccountIssue(for: UniversalWalletRegistry.solanaMainnetChainModel)
        let setup = try XCTUnwrap(router.presentedSetupViewModels.last)
        setup.actions.first?.handler?()
        setup.dismissCompletion?()
        XCTAssertEqual(interactor.storedSeedAdoptionCalls, 1)

        presenter.didAdoptStoredWalletSeed(
            result: .failure(UniversalWalletStoredSeedAdopter.AdoptionError.unsupportedSecretSource)
        )

        let sheet = try XCTUnwrap(router.presentedSetupViewModels.last)
        let languages = LocalizationManager.shared.selectedLocale.rLanguages
        XCTAssertEqual(router.presentedSetupViewModels.count, 2)
        XCTAssertEqual(
            sheet.actions.map(\.title),
            [R.string.localizable.universalOpenWalletsAction(preferredLanguages: languages)]
        )
        XCTAssertEqual(sheet.message, R.string.localizable.universalUnsupportedSourceMessage(preferredLanguages: languages))
        sheet.actions.first?.handler?()
        sheet.dismissCompletion?()
        XCTAssertEqual(router.walletListOpens, 1)
        XCTAssertTrue(router.presentedErrors.isEmpty)
    }

    func testProvisionedTairaIsHiddenByDefaultAndKeepsReceiveOnlyActionsWhenShown() throws {
        let wallet = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let taira = try XCTUnwrap(UniversalWalletRegistry.tairaChainModel.chainAssets.first)
        let build = {
            self.makeFactory().buildViewModel(
                wallet: wallet,
                chainAssets: [taira],
                locale: Locale(identifier: "en_US"),
                accountInfos: self.balances(wallet: wallet, values: [taira: 0]),
                chainsWithIssue: [],
                shouldRunManageAssetAnimate: false,
                displayType: .assetChains,
                chainSettings: [],
                networkFilter: nil,
                search: nil
            )
        }

        // Testnets stay out of the portfolio, header included, until the user shows them.
        XCTAssertTrue(build().networkSections.isEmpty)

        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: wallet.metaId, assetKey: taira.assetKey)
        defer {
            AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: taira.assetKey)
        }
        let viewModel = build()

        let row = try XCTUnwrap(viewModel.displayState.rows.first)
        XCTAssertEqual(row.chainAsset.assetKey, taira.assetKey)
        XCTAssertEqual(row.chainAsset.asset.symbol, "XOR")
        XCTAssertFalse(row.isColdBoot)
        XCTAssertFalse(row.swipeActionsEnabled, "Taira Send must stay closed while receive remains in details")
    }

    func testAccountlessTairaIsHiddenButOffersAccountSetupWhenSelected() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let taira = try XCTUnwrap(UniversalWalletRegistry.tairaChainModel.chainAssets.first)

        let portfolio = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [taira],
            locale: Locale(identifier: "en_US"),
            accountInfos: [:],
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        let filtered = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [taira],
            locale: Locale(identifier: "en_US"),
            accountInfos: [:],
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .chain,
            chainSettings: [],
            networkFilter: .chain(taira.chain.chainId),
            search: nil
        )
        let networkPicker = NetworkManagmentViewModelFactoryImpl().createViewModel(
            wallet: wallet,
            chains: [taira.chain],
            selectedFilter: nil,
            initialFilter: .all,
            searchText: nil,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertTrue(portfolio.displayState.rows.isEmpty, "testnets are hidden by default")
        XCTAssertTrue(portfolio.networkSections.isEmpty)
        guard case let .chainHasAccountIssue(chain) = filtered.displayState else {
            return XCTFail("Taira without an I105 account must offer account setup")
        }
        XCTAssertEqual(chain.chainId, UniversalWalletRegistry.taira.chainId)
        XCTAssertTrue(networkPicker.cells.contains(where: {
            $0.networkSelectType.identifier == UniversalWalletRegistry.taira.chainId
        }))

        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: wallet.metaId, assetKey: taira.assetKey)
        defer {
            AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: taira.assetKey)
        }
        let shown = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [taira],
            locale: Locale(identifier: "en_US"),
            accountInfos: [:],
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertEqual(shown.displayState.rows.map(\.chainAsset.assetKey), [taira.assetKey])
        XCTAssertFalse(try XCTUnwrap(shown.displayState.rows.first).swipeActionsEnabled)
    }

    func testFundedTestnetStaysOutOfPortfolioUntilSelectedOrShown() throws {
        let wallet = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let taira = try XCTUnwrap(UniversalWalletRegistry.tairaChainModel.chainAssets.first)
        let build = { (filter: NetworkManagmentFilter?) in
            self.makeFactory().buildViewModel(
                wallet: wallet,
                chainAssets: [taira],
                locale: Locale(identifier: "en_US"),
                accountInfos: self.balances(wallet: wallet, values: [taira: 10]),
                chainsWithIssue: [],
                shouldRunManageAssetAnimate: false,
                displayType: filter == nil ? .assetChains : .chain,
                chainSettings: [],
                networkFilter: filter,
                search: nil
            )
        }

        // Neither the row nor an empty network header: test tokens have no value.
        XCTAssertTrue(build(nil).networkSections.isEmpty)
        XCTAssertEqual(
            build(.chain(taira.chain.chainId)).displayState.rows.map(\.chainAsset.assetKey),
            [taira.assetKey]
        )
    }

    func testLegacyZeroHiddenUtilityLeavesNoEmptyNetworkHeader() throws {
        let chain = makeChain(name: "Ranked legacy", rank: 3)
        let native = makeChainAsset(chain: chain, id: "native", symbol: "NAT", isUtility: true, isNative: true)
        let wallet = AccountGenerator.generateMetaAccount().replacingAssetsVisibility([
            AssetVisibility(assetId: native.identifier, hidden: true)
        ])
        let factory = ChainAssetListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            zeroDefaults: PortfolioZeroDefaultList(entries: [])
        )
        let build = { (value: UInt64) in
            factory.buildViewModel(
                wallet: wallet,
                chainAssets: [native],
                locale: Locale(identifier: "en_US"),
                accountInfos: self.balances(wallet: wallet, values: [native: value]),
                chainsWithIssue: [],
                shouldRunManageAssetAnimate: false,
                displayType: .assetChains,
                chainSettings: [],
                networkFilter: nil,
                search: nil
            )
        }
        XCTAssertEqual(build(0).networkSections.flatMap(\.rows).map(\.chainAsset.assetKey), [native.assetKey])

        AssetVisibilityPreferenceStore.migrateLegacyHides(wallet: wallet, chainAssets: [native], catalogIsComplete: true)
        defer {
            AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: native.assetKey)
            UserDefaults.standard.removeObject(forKey: "asset.presentation.asset_key.migrated.v2:\(wallet.metaId)")
        }

        XCTAssertTrue(build(0).networkSections.isEmpty, "4.0.4 had hidden it while it held nothing")
        XCTAssertEqual(build(4).networkSections.flatMap(\.rows).map(\.chainAsset.assetKey), [native.assetKey])
    }

    func testMalformedDedicatedUniversalAccountsRemainActionableSetupRows() throws {
        let malformedBitcoin = ChainAccountModel(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            accountId: Data(repeating: 0x01, count: 32),
            publicKey: Data(repeating: 0x01, count: 32),
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )
        let malformedTaira = ChainAccountModel(
            chainId: UniversalWalletRegistry.taira.chainId,
            accountId: Data(repeating: 0x02, count: 32),
            publicKey: Data(repeating: 0x02, count: 32),
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )
        let wallet = AccountGenerator.generateMetaAccount(
            with: [malformedBitcoin, malformedTaira]
        )
        let bitcoin = try XCTUnwrap(
            UniversalWalletRegistry.bitcoinMainnetChainModel.chainAssets.first
        )
        let taira = try XCTUnwrap(UniversalWalletRegistry.tairaChainModel.chainAssets.first)

        let build = {
            self.makeFactory().buildViewModel(
                wallet: wallet,
                chainAssets: [bitcoin, taira],
                locale: Locale(identifier: "en_US"),
                accountInfos: [:],
                chainsWithIssue: [],
                shouldRunManageAssetAnimate: false,
                displayType: .assetChains,
                chainSettings: [],
                networkFilter: nil,
                search: nil
            )
        }
        XCTAssertTrue(build().displayState.rows.isEmpty, "no account, no zero row")

        // Shown, both rows appear and route to the account setup.
        for chainAsset in [bitcoin, taira] {
            AssetVisibilityPreferenceStore.setPreference(.shown, walletId: wallet.metaId, assetKey: chainAsset.assetKey)
        }
        defer {
            for chainAsset in [bitcoin, taira] {
                AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: chainAsset.assetKey)
            }
        }
        let viewModel = build()

        XCTAssertEqual(
            Set(viewModel.displayState.rows.map(\.chainAsset.assetKey)),
            Set([bitcoin.assetKey, taira.assetKey])
        )
        XCTAssertTrue(viewModel.displayState.rows.allSatisfy { !$0.isColdBoot })
        XCTAssertTrue(viewModel.displayState.rows.allSatisfy { !$0.swipeActionsEnabled })
    }

    func testSameSymbolAssetsRemainSeparateByCanonicalIdentity() {
        let firstChain = makeChain(name: "Alpha")
        let secondChain = makeChain(name: "Beta")
        let first = makeChainAsset(chain: firstChain, id: "contract-a", symbol: "SAME")
        let second = makeChainAsset(chain: firstChain, id: "contract-b", symbol: "SAME")
        let third = makeChainAsset(chain: secondChain, id: "mint-c", symbol: "SAME")
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [first: 10, second: 20, third: 30])

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [first, second, third],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )

        XCTAssertEqual(viewModel.networkSections.filter { $0.kind == .assets }.count, 2)
        XCTAssertEqual(Set(viewModel.displayState.rows.map(\.chainAsset.assetKey)), Set([
            first.assetKey,
            second.assetKey,
            third.assetKey
        ]))
    }

    func testManageAssetsKeepsSameSymbolBalancesAndPricesIsolatedByAssetKey() {
        let firstChain = makeChain(name: "Alpha")
        let secondChain = makeChain(name: "Beta")
        let first = makeChainAsset(
            chain: firstChain,
            id: "contract-a",
            symbol: "SAME",
            price: 2
        )
        let second = makeChainAsset(
            chain: firstChain,
            id: "contract-b",
            symbol: "SAME",
            price: 5
        )
        let third = makeChainAsset(
            chain: secondChain,
            id: "mint-c",
            symbol: "SAME"
        )
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [first: 10, second: 20, third: 30])

        let viewModel = AssetManagementViewModelFactoryDefault(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        ).buildViewModel(
            chainAssets: [first, second, third],
            accountInfos: accountInfos,
            wallet: wallet,
            locale: Locale(identifier: "en_US"),
            filter: nil,
            search: nil,
            pendingAccountInfoChainAssets: []
        )

        XCTAssertEqual(viewModel.list.count, 3)
        XCTAssertTrue(viewModel.list.allSatisfy { !$0.hasView && $0.cells.count == 1 })
        let totals = Dictionary(uniqueKeysWithValues: viewModel.list.compactMap { section in
            section.cells.first.map { ($0.chainAsset.assetKey, section.totalFiatBalance) }
        })
        XCTAssertEqual(totals[first.assetKey], 20)
        XCTAssertEqual(totals[second.assetKey], 100)
        XCTAssertEqual(totals[third.assetKey], 0)
    }

    func testRelatedAssetResolverRequiresExplicitCuratedAssetId() {
        let destinationId = "destination-chain"
        let originId = "curated-registry-asset-id"
        let originChain = makeChain(
            name: "Origin",
            xcm: XcmChain(
                xcmVersion: .V3,
                destWeightIsPrimitive: false,
                availableAssets: [XcmAvailableAsset(id: originId, symbol: "SAME")],
                availableDestinations: [
                    XcmAvailableDestination(
                        chainId: destinationId,
                        bridgeParachainId: nil,
                        assets: [XcmAvailableAsset(id: originId, symbol: "SAME")]
                    )
                ]
            )
        )
        let destinationChain = makeChain(name: "Destination", chainId: destinationId)
        let unlistedChain = makeChain(name: "Unlisted")
        let origin = makeChainAsset(chain: originChain, id: originId, symbol: "SAME")
        let curatedDestination = makeChainAsset(
            chain: destinationChain,
            id: originId,
            symbol: "DIFFERENT DISPLAY NAME"
        )
        let sameSymbolContract = makeChainAsset(
            chain: destinationChain,
            id: "other-contract",
            symbol: "SAME"
        )
        let prefixedImposter = makeChainAsset(
            chain: destinationChain,
            id: "xc-imposter",
            symbol: "xcSAME"
        )
        let unlistedSameId = makeChainAsset(
            chain: unlistedChain,
            id: originId,
            symbol: "SAME"
        )

        let related = CuratedAssetRelationshipResolver.relatedChainAssets(
            to: origin,
            among: [
                origin,
                curatedDestination,
                sameSymbolContract,
                prefixedImposter,
                unlistedSameId
            ]
        )

        XCTAssertEqual(Set(related.map(\.assetKey)), Set([origin.assetKey, curatedDestination.assetKey]))
        XCTAssertTrue(CuratedAssetRelationshipResolver.hasCuratedXcmDestination(for: origin))
    }

    func testUnverifiedPositiveAssetMovesDetectedToShownAndHiddenPreferencesSurviveRescan() {
        let chain = makeChain(name: "Detected")
        let asset = makeChainAsset(chain: chain, id: "unknown-master", symbol: "SAME")
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [asset: 25])
        let factory = makeFactory()
        AssetTrustResolver.markUnverified(asset)

        var viewModel = factory.buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertEqual(viewModel.networkSections.first { $0.kind == .detected }?.rows.map(\.chainAsset.assetKey), [asset.assetKey])

        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: wallet.metaId, assetKey: asset.assetKey)
        viewModel = factory.buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertNil(viewModel.networkSections.first { $0.kind == .detected })
        XCTAssertEqual(viewModel.networkSections.first { $0.kind == .assets }?.rows.map(\.chainAsset.assetKey), [asset.assetKey])

        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: asset.assetKey)
        viewModel = factory.buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertTrue(viewModel.networkSections.flatMap(\.rows).isEmpty)
        XCTAssertEqual(
            AssetVisibilityPreferenceStore.preference(walletId: wallet.metaId, assetKey: asset.assetKey),
            .hidden
        )

        // A later scan supplies the same positive balance but does not mutate
        // the explicit presentation preference.
        let rescanned = factory.buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertTrue(rescanned.networkSections.flatMap(\.rows).isEmpty)

        AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: asset.assetKey)
    }

    /// IOSUX-7 (audit IOS-G-07): a hidden asset leaves the network subtotal and the portfolio
    /// header, is labelled under the list, and still counts in the wallet-management total.
    func testHiddenVerifiedAssetLeavesSubtotalAndHeaderButStaysInWalletManagement() throws {
        let pricedChain = makeChain(name: "Priced")
        let unpricedChain = makeChain(name: "Unpriced")
        let priced = makeChainAsset(chain: pricedChain, id: "priced", symbol: "USD", price: 2)
        let unpriced = makeChainAsset(chain: unpricedChain, id: "unpriced", symbol: "RAW")
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [priced: 10, unpriced: 100])
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: priced.assetKey)
        defer {
            AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: priced.assetKey)
        }

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [unpriced, priced],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )

        let assetSections = viewModel.networkSections.filter { $0.kind == .assets }
        XCTAssertEqual(assetSections.map(\.chainId), [unpricedChain.chainId], "no bare header for the hidden holding")
        XCTAssertTrue(assetSections.allSatisfy { $0.fiatSubtotal == nil })
        XCTAssertEqual(viewModel.exclusions, [
            PortfolioExclusionCaption(kind: .hiddenAssets, text: PortfolioTestCopy.text("portfolio.exclusions.hidden.one", 1)),
            PortfolioExclusionCaption(kind: .unpricedAssets, text: PortfolioTestCopy.text("portfolio.exclusions.unpriced.one", 1))
        ])

        let walletBalance = try XCTUnwrap(
            WalletBalanceBuilder().buildBalance(for: accountInfos, [wallet], [priced, unpriced])?[wallet.metaId]
        )
        XCTAssertEqual(walletBalance.enabledAssetFiatBalance, 0)
        XCTAssertEqual(walletBalance.totalFiatValue, 20)
        XCTAssertEqual(walletBalance.exclusions.hiddenCount, 1)
        XCTAssertEqual(walletBalance.exclusions.hiddenFiat, 20)
        XCTAssertEqual(walletBalance.allHoldingsCaption, PortfolioTestCopy.text("portfolio.balance.incl_hidden"))
    }

    func testExactLivePriceUpdatePreservesCurrencyAndIgnoresLegacyScalar() throws {
        let chain = makeChain(name: "Exact price")
        let assetModel = AssetModel(
            id: "registry-row",
            name: "Exact token",
            symbol: "EXACT",
            precision: 0,
            price: 999,
            currencyId: "runtime-asset-id",
            isUtility: false,
            isNative: false,
            coingeckoPriceId: "exact-provider-id"
        )
        chain.assets.insert(assetModel)
        let chainAsset = ChainAsset(chain: chain, asset: assetModel)
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [chainAsset: 10])
        let usd = Currency.defaultCurrency()
        let eur = Currency.euro()

        // A naked legacy scalar has no fiat provenance and must not be exposed.
        XCTAssertNil(chainAsset.asset.getPrice(for: usd))
        XCTAssertNil(chainAsset.asset.getPrice(for: eur))
        XCTAssertEqual(
            try XCTUnwrap(
                WalletBalanceBuilder().buildBalance(
                    for: accountInfos,
                    [wallet],
                    [chainAsset]
                )?[wallet.metaId]
            ).totalFiatValue,
            .zero
        )

        let usdPrice = PriceData(
            currencyId: usd.id,
            priceId: "exact-provider-id",
            price: "2",
            fiatDayChange: 1,
            coingeckoPriceId: "exact-provider-id"
        )
        ExactAssetPriceCache.shared.upsert([usdPrice])

        XCTAssertEqual(chainAsset.asset.getPrice(for: usd), usdPrice)
        XCTAssertNil(chainAsset.asset.getPrice(for: eur))
        XCTAssertEqual(
            try XCTUnwrap(
                WalletBalanceBuilder().buildBalance(
                    for: accountInfos,
                    [wallet],
                    [chainAsset]
                )?[wallet.metaId]
            ).totalFiatValue,
            20
        )

        let eurPrice = PriceData(
            currencyId: eur.id,
            priceId: "exact-provider-id",
            price: "3",
            fiatDayChange: 2,
            coingeckoPriceId: "exact-provider-id"
        )
        let refreshedUSD = PriceData(
            currencyId: usd.id,
            priceId: "exact-provider-id",
            price: "4",
            fiatDayChange: 3,
            coingeckoPriceId: "exact-provider-id"
        )
        ExactAssetPriceCache.shared.upsert([eurPrice, refreshedUSD])

        XCTAssertEqual(chainAsset.asset.getPrice(for: usd), refreshedUSD)
        XCTAssertEqual(chainAsset.asset.getPrice(for: eur), eurPrice)

        ExactAssetPriceCache.shared.replaceAll(with: [eurPrice])
        XCTAssertNil(chainAsset.asset.getPrice(for: usd))
        XCTAssertEqual(chainAsset.asset.getPrice(for: eur), eurPrice)
        ExactAssetPriceCache.shared.clear()
        XCTAssertNil(chainAsset.asset.getPrice(for: eur))
    }

    func testCanonicalVisibilityEventInvalidatesOnlyMatchingWalletPortfolio() {
        let wallet = AccountGenerator.generateMetaAccount()
        let otherWallet = AccountGenerator.generateMetaAccount()
        let chainAsset = makeChainAsset(
            chain: makeChain(name: "Visibility"),
            id: "canonical-asset",
            symbol: "CAN"
        )
        let output = ChainAssetListInteractorOutputSpy()
        let event = AssetVisibilityPreferenceChangedEvent(
            walletId: wallet.metaId,
            assetKey: chainAsset.assetKey,
            preference: .hidden
        )

        AssetVisibilityPreferenceStore.setPreference(
            .hidden,
            walletId: wallet.metaId,
            assetKey: chainAsset.assetKey
        )
        defer {
            AssetVisibilityPreferenceStore.setPreference(
                .auto,
                walletId: wallet.metaId,
                assetKey: chainAsset.assetKey
            )
        }

        ChainAssetListInteractor.invalidateViewModel(
            for: event,
            walletId: otherWallet.metaId,
            output: output
        )
        XCTAssertEqual(output.updateViewModelCalls, 0)

        ChainAssetListInteractor.invalidateViewModel(
            for: event,
            walletId: wallet.metaId,
            output: output
        )
        XCTAssertEqual(output.updateViewModelCalls, 1)
        XCTAssertEqual(output.lastIsInitSearchState, false)

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [chainAsset],
            locale: Locale(identifier: "en_US"),
            accountInfos: balances(wallet: wallet, values: [chainAsset: 10]),
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertTrue(viewModel.networkSections.flatMap(\.rows).isEmpty)
    }

    /// IOSUX-7: the header total leaves hidden assets out, so a swipe Hide or Show in the list
    /// goes out as an event the wallet balance rebuilds on, not only as a list refresh.
    func testSwipeHideAndShowNotifyTheWalletBalance() throws {
        let suiteName = "ChainAssetListTests.swipe.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let chainAsset = makeChainAsset(chain: makeChain(name: "Swipe"), id: "swipe", symbol: "SWP")
        let walletId = AccountGenerator.generateMetaAccount().metaId
        let output = ChainAssetListInteractorOutputSpy()
        let events = VisibilityEventCenterRecorder()

        ChainAssetListInteractor.setExplicitlyHidden(
            true,
            chainAsset: chainAsset,
            walletId: walletId,
            eventCenter: events,
            output: output,
            userDefaults: defaults
        )
        ChainAssetListInteractor.setExplicitlyHidden(
            false,
            chainAsset: chainAsset,
            walletId: walletId,
            eventCenter: events,
            output: output,
            userDefaults: defaults
        )

        XCTAssertEqual(output.updateViewModelCalls, 2)
        XCTAssertEqual(events.events.map(\.preference), [.hidden, .shown])
        XCTAssertTrue(events.events.allSatisfy { $0.walletId == walletId && $0.assetKey == chainAsset.assetKey })
        let stored = AssetVisibilityPreferenceStore.preference(
            walletId: walletId,
            assetKey: chainAsset.assetKey,
            userDefaults: defaults
        )
        XCTAssertEqual(stored, .shown)
    }

    func testZeroBalancePricedNativeDoesNotPromoteUnpricedFundedNetwork() {
        let pricedChain = makeChain(name: "Zulu", rank: 1)
        let unpricedChain = makeChain(name: "Alpha")
        let pricedZero = makeChainAsset(
            chain: pricedChain,
            id: "native",
            symbol: "NATIVE",
            price: 1,
            isUtility: true,
            isNative: true
        )
        let unpricedOnPricedChain = makeChainAsset(
            chain: pricedChain,
            id: "raw-zulu",
            symbol: "RAWZ"
        )
        let unpricedPositive = makeChainAsset(chain: unpricedChain, id: "raw", symbol: "RAW")
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(
            wallet: wallet,
            values: [pricedZero: 0, unpricedOnPricedChain: 7, unpricedPositive: 5]
        )

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [unpricedPositive, pricedZero, unpricedOnPricedChain],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )

        let assetSections = viewModel.networkSections.filter { $0.kind == .assets }
        XCTAssertEqual(assetSections.map(\.chainId), [unpricedChain.chainId, pricedChain.chainId])
        XCTAssertTrue(assetSections.allSatisfy { $0.fiatSubtotal == nil })
    }

    func testLegacyGroupHideOnlyHintsAssetsKnownAtMigration() throws {
        let suiteName = "ChainAssetListTests.legacy.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = makeChainAsset(chain: makeChain(name: "First"), id: "one", symbol: "SAME")
        let second = makeChainAsset(chain: makeChain(name: "Second"), id: "two", symbol: "SAME")
        let later = makeChainAsset(chain: makeChain(name: "Later"), id: "three", symbol: "SAME")
        let wallet = AccountGenerator.generateMetaAccount().replacingAssetsVisibility([
            AssetVisibility(assetId: "SAME", hidden: true)
        ])

        AssetVisibilityPreferenceStore.migrateLegacyHides(
            wallet: wallet,
            chainAssets: [first, second],
            catalogIsComplete: true,
            userDefaults: defaults
        )

        // A 4.0.4 hide only meant "held nothing then": no explicit preference,
        // a hide-while-zero hint on the assets the catalog had at migration.
        let hints = AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: wallet.metaId, userDefaults: defaults)
        for chainAsset in [first, second, later] {
            XCTAssertEqual(preference(chainAsset, wallet: wallet, defaults: defaults), .auto)
        }
        XCTAssertTrue(hints.contains(first.assetKey))
        XCTAssertTrue(hints.contains(second.assetKey))
        XCTAssertFalse(hints.contains(later.assetKey))
    }

    func testIncompleteLegacyMigrationDoesNotCommitAndRetriesWithDisabledNetworkAssets() throws {
        let suiteName = "ChainAssetListTests.legacy-retry.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let enabled = makeChainAsset(chain: makeChain(name: "Enabled"), id: "one", symbol: "SAME")
        let disabled = makeChainAsset(
            chain: makeChain(name: "Disabled", disabled: true),
            id: "two",
            symbol: "SAME"
        )
        let wallet = AccountGenerator.generateMetaAccount().replacingAssetsVisibility([
            AssetVisibility(assetId: "SAME", hidden: true)
        ])

        AssetVisibilityPreferenceStore.migrateLegacyHides(
            wallet: wallet,
            chainAssets: [enabled],
            catalogIsComplete: false,
            userDefaults: defaults
        )
        XCTAssertEqual(preference(enabled, wallet: wallet, defaults: defaults), .auto)
        XCTAssertTrue(AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: wallet.metaId, userDefaults: defaults).isEmpty)

        AssetVisibilityPreferenceStore.migrateLegacyHides(
            wallet: wallet,
            chainAssets: [enabled, disabled],
            catalogIsComplete: true,
            userDefaults: defaults
        )
        let hints = AssetVisibilityPreferenceStore.legacyZeroHidden(walletId: wallet.metaId, userDefaults: defaults)
        XCTAssertEqual(preference(enabled, wallet: wallet, defaults: defaults), .auto)
        XCTAssertEqual(preference(disabled, wallet: wallet, defaults: defaults), .auto)
        XCTAssertTrue(hints.contains(enabled.assetKey))
        XCTAssertTrue(hints.contains(disabled.assetKey))
    }

    func testEvmAssetKeyNormalizesCaseButOtherEcosystemsPreserveAssetIdCase() {
        XCTAssertEqual(
            AssetKey(ecosystem: "EVM", chainId: "0xABC", assetId: "0xAbCd"),
            AssetKey(ecosystem: "evm", chainId: "0xabc", assetId: "0xabcd")
        )
        XCTAssertNotEqual(
            AssetKey(ecosystem: "solana", chainId: "SOLANA:MAINNET", assetId: "MintABC"),
            AssetKey(ecosystem: "solana", chainId: "solana:mainnet", assetId: "mintabc")
        )
    }

    func testChainAssetKeyUsesRuntimeCurrencyIdentityBeforeRegistryRowId() {
        let chain = makeChain(name: "Runtime asset network")
        let runtimeAsset = AssetModel(
            id: "registry-row-17",
            name: "Runtime asset",
            symbol: "RTA",
            precision: 12,
            currencyId: "runtime-currency-id-42",
            isUtility: false,
            isNative: false,
            type: .assets
        )
        let registryOnlyAsset = AssetModel(
            id: "canonical-mint-or-master",
            name: "Dynamic asset",
            symbol: "DYN",
            precision: 9,
            isUtility: false,
            isNative: false
        )

        XCTAssertEqual(runtimeAsset.canonicalAssetId, "runtime-currency-id-42")
        XCTAssertEqual(
            ChainAsset(chain: chain, asset: runtimeAsset).assetKey.assetId,
            "runtime-currency-id-42"
        )
        XCTAssertEqual(registryOnlyAsset.canonicalAssetId, "canonical-mint-or-master")
        XCTAssertEqual(
            ChainAsset(chain: chain, asset: registryOnlyAsset).assetKey.assetId,
            "canonical-mint-or-master"
        )
    }

    func testIrohaFallbackPrecisionDoesNotShrinkAcrossRescans() throws {
        let suiteName = "ChainAssetListTests.iroha.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = AssetKey(ecosystem: "iroha", chainId: "iroha:test", assetId: "xor#wonderland")

        DynamicAssetPrecisionStore.remember(18, for: key, userDefaults: defaults)

        XCTAssertEqual(DynamicAssetPrecisionStore.precision(for: key, userDefaults: defaults), 18)
        XCTAssertGreaterThanOrEqual(
            DynamicAssetPrecisionStore.precision(for: key, userDefaults: defaults) ?? 0,
            2
        )
    }

    func testFailureScanStateKeepsLastSuccessAndMarksError() throws {
        let suiteName = "ChainAssetListTests.scan.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let chain = makeChain(name: "Network")
        let walletId = UUID().uuidString

        NetworkScanStateStore.markSuccess(for: chain, walletId: walletId, userDefaults: defaults)
        let successful = NetworkScanStateStore.state(for: chain, walletId: walletId, userDefaults: defaults)
        NetworkScanStateStore.markFailure(for: chain, walletId: walletId, userDefaults: defaults)
        let failed = NetworkScanStateStore.state(for: chain, walletId: walletId, userDefaults: defaults)

        XCTAssertNotNil(successful.lastSuccess)
        XCTAssertEqual(failed.lastSuccess, successful.lastSuccess)
        XCTAssertTrue(failed.hasError)
    }

    func testAttemptAndFailurePreserveLastSuccessfulDynamicCoverage() throws {
        let suiteName = "ChainAssetListTests.scan.coverage.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let chain = makeChain(name: "Bitcoin", chainId: "bitcoin:mainnet")
        let walletId = UUID().uuidString

        NetworkScanStateStore.markSuccess(
            for: chain,
            coverage: .complete,
            walletId: walletId,
            userDefaults: defaults
        )
        NetworkScanStateStore.markAttempt(for: chain, walletId: walletId, userDefaults: defaults)
        let attempted = NetworkScanStateStore.state(
            for: chain,
            walletId: walletId,
            userDefaults: defaults
        )
        NetworkScanStateStore.markFailure(for: chain, walletId: walletId, userDefaults: defaults)
        let failed = NetworkScanStateStore.state(
            for: chain,
            walletId: walletId,
            userDefaults: defaults
        )

        XCTAssertEqual(attempted.coverage, .complete)
        XCTAssertEqual(failed.coverage, .complete)
        XCTAssertTrue(failed.hasError)

        NetworkScanStateStore.markSuccess(
            for: chain,
            coverage: .limited,
            walletId: walletId,
            userDefaults: defaults
        )
        XCTAssertEqual(
            NetworkScanStateStore.state(
                for: chain,
                walletId: walletId,
                userDefaults: defaults
            ).coverage,
            .limited
        )
    }

    func testHealthyNetworkScansDoNotAddHeaderStatusForAnyCoverage() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        for coverage in [AssetDiscoveryCoverage.complete, .catalogOnly, .limited] {
            let state = NetworkScanState(
                lastAttempt: now,
                lastSuccess: now.addingTimeInterval(-30),
                hasError: false,
                coverage: coverage
            )
            XCTAssertNil(state.attentionText(now: now))
        }
    }

    func testNetworkHeaderStatusDistinguishesFailedUnloadedAndOutdatedBalances() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let fresh = now.addingTimeInterval(-30)
        for lastSuccess in [fresh, nil] {
            XCTAssertEqual(
                NetworkScanState(lastAttempt: now, lastSuccess: lastSuccess, hasError: true, coverage: .catalogOnly)
                    .attentionText(now: now),
                NSLocalizedString("portfolio.balance.update_failed", value: "Balance update failed", comment: "")
            )
        }
        XCTAssertEqual(
            NetworkScanState(lastAttempt: nil, lastSuccess: nil, hasError: false, coverage: .catalogOnly)
                .attentionText(now: now),
            NSLocalizedString("portfolio.balance.not_loaded", value: "Balances not loaded", comment: "")
        )
        let expiry = fresh.addingTimeInterval(36 * 60 * 60)
        let state = NetworkScanState(lastAttempt: now, lastSuccess: fresh, hasError: false, coverage: .limited)
        XCTAssertNil(state.attentionText(now: expiry))
        XCTAssertEqual(state.attentionText(now: expiry.addingTimeInterval(1)), NSLocalizedString("portfolio.balance.outdated", value: "Balances may be outdated", comment: ""))
    }

    func testNetworkScanStatusIncludesDeterministicFreshnessAndRetainsItOnFailure() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let recent = NetworkScanState(
            lastAttempt: now,
            lastSuccess: now.addingTimeInterval(-30),
            hasError: false,
            coverage: .complete
        )
        XCTAssertEqual(recent.displayText(now: now), "Full discovery · Synced just now")

        let twelveMinutesAgo = now.addingTimeInterval(-12 * 60)
        let failed = NetworkScanState(
            lastAttempt: now,
            lastSuccess: twelveMinutesAgo,
            hasError: true,
            coverage: .catalogOnly
        )
        XCTAssertEqual(
            failed.displayText(now: now),
            "Sync error · \(AssetDiscoveryCoverage.catalogOnly.title) · Synced 12m ago"
        )

        let stale = NetworkScanState(
            lastAttempt: now,
            lastSuccess: now.addingTimeInterval(-2 * 24 * 60 * 60),
            hasError: false,
            coverage: .limited
        )
        XCTAssertEqual(
            stale.displayText(now: now),
            "Stale · Limited discovery · Synced 2d ago"
        )
    }

    func testDiscoveryShadowModeKeepsAutoDetectedReachableForReviewAndHonorsExplicitShow() {
        let chain = makeChain(name: "Shadow")
        let asset = makeChainAsset(chain: chain, id: "unverified", symbol: "NEW")
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [asset: 10])
        AssetTrustResolver.markUnverified(asset)
        MultiChainFeaturePolicy.update(
            FeatureToggleConfig(
                pendulumCaseEnabled: false,
                nftEnabled: true,
                assetDiscoveryShadowMode: true
            )
        )

        var viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertEqual(viewModel.networkSections.map(\.kind), [.detected])
        XCTAssertEqual(viewModel.networkSections.flatMap(\.rows).map(\.chainAsset.assetKey), [asset.assetKey])

        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: wallet.metaId, assetKey: asset.assetKey)
        viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertEqual(viewModel.networkSections.flatMap(\.rows).map(\.chainAsset.assetKey), [asset.assetKey])
        AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: asset.assetKey)
    }

    func testExplicitlyShownNonNativeAssetAtZeroStaysInPortfolio() {
        let chain = makeChain(name: "Zero balance")
        let asset = makeChainAsset(chain: chain, id: "zero-token", symbol: "ZERO")
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [asset: 0])
        AssetVisibilityPreferenceStore.setPreference(
            .shown,
            walletId: wallet.metaId,
            assetKey: asset.assetKey
        )

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )

        XCTAssertEqual(viewModel.networkSections.flatMap(\.rows).map(\.chainAsset.assetKey), [asset.assetKey])
        XCTAssertEqual(
            AssetVisibilityPreferenceStore.preference(
                walletId: wallet.metaId,
                assetKey: asset.assetKey
            ),
            .shown
        )
        AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: asset.assetKey)
    }

    func testZeroNativeAssetOnFavoritedUnrankedNetworkRemainsVisibleUnlessHidden() {
        let chain = makeChain(name: "Pinned unranked", rank: nil)
        let asset = makeChainAsset(
            chain: chain,
            id: "native",
            symbol: "PIN",
            isUtility: true,
            isNative: true
        )
        let wallet = AccountGenerator.generateMetaAccount().replacingFavoutites([chain.chainId])
        let accountInfos = balances(wallet: wallet, values: [asset: 0])

        var viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertEqual(viewModel.networkSections.flatMap(\.rows).map(\.chainAsset.assetKey), [asset.assetKey])

        AssetVisibilityPreferenceStore.setPreference(
            .hidden,
            walletId: wallet.metaId,
            assetKey: asset.assetKey
        )
        viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertTrue(viewModel.networkSections.flatMap(\.rows).isEmpty)
        AssetVisibilityPreferenceStore.setPreference(
            .auto,
            walletId: wallet.metaId,
            assetKey: asset.assetKey
        )
    }

    func testDailyDiscoveryIsDueBoundedProductionOnlyAndRotatesCursor() throws {
        let suiteName = "ChainAssetListTests.daily.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scheduler = DailyAssetDiscoveryScheduler(
            userDefaults: defaults,
            interval: 3600,
            maximumNetworks: 2
        )
        let wallet = AccountGenerator.generateMetaAccount()
        let production = [
            makeChain(name: "One", chainId: "01"),
            makeChain(name: "Two", chainId: "02"),
            makeChain(name: "Three", chainId: "03")
        ]
        let testnet = makeChain(name: "Test", chainId: "00", options: [.testnet])
        let now = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertTrue(scheduler.isDue(walletId: wallet.metaId, now: now))
        XCTAssertEqual(
            scheduler.eligibleChains(from: production + [testnet], wallet: wallet).map(\.chainId),
            ["01", "02"]
        )
        XCTAssertEqual(
            scheduler.eligibleChains(from: production + [testnet], wallet: wallet).map(\.chainId),
            ["03", "01"]
        )

        scheduler.markAttempt(walletId: wallet.metaId, now: now)
        XCTAssertFalse(scheduler.isDue(walletId: wallet.metaId, now: now.addingTimeInterval(3599)))
        XCTAssertTrue(scheduler.isDue(walletId: wallet.metaId, now: now.addingTimeInterval(3600)))
        XCTAssertFalse(
            scheduler.eligibleChains(from: [testnet], wallet: wallet).contains(where: \.isTestnet)
        )
        XCTAssertTrue(
            scheduler.eligibleChains(
                from: [testnet],
                wallet: wallet,
                includeTestnets: true
            ).contains(where: \.isTestnet)
        )
    }

    func testCompleteDiscoveryCatalogIncludesDisabledProductionNetworksWithoutActivatingThem() {
        let wallet = AccountGenerator.generateMetaAccount()
        let enabled = makeChain(name: "Enabled", chainId: "enabled")
        let disabled = makeChain(name: "Disabled", disabled: true, chainId: "disabled")
        let testnet = makeChain(
            name: "Testnet",
            chainId: "testnet",
            options: [.testnet]
        )
        let catalog = AssetDiscoveryChainCatalog(
            chains: [enabled, disabled, testnet],
            isComplete: true
        )

        XCTAssertEqual(
            Set(catalog.productionChains(wallet: wallet).map(\.chainId)),
            Set([enabled.chainId, disabled.chainId])
        )
        XCTAssertTrue(disabled.disabled)
        XCTAssertEqual(
            Set(
                catalog.productionChains(
                    wallet: wallet,
                    optedInTestnetIds: [testnet.chainId]
                ).map(\.chainId)
            ),
            Set([enabled.chainId, disabled.chainId, testnet.chainId])
        )
    }

    func testAssetDiscoveryScansRequestedNetworksIndependentlyOfPresentationPreferences() async throws {
        let suiteName = "ChainAssetListTests.discovery.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let wallet = AccountGenerator.generateMetaAccount()
        let firstChain = makeChain(name: "Alpha", chainId: "discovery-alpha")
        let secondChain = makeChain(name: "Beta", chainId: "discovery-beta")
        let firstAsset = makeChainAsset(chain: firstChain, id: "hidden-a", symbol: "A")
        _ = makeChainAsset(chain: secondChain, id: "visible-b", symbol: "B")
        AssetVisibilityPreferenceStore.setPreference(
            .hidden,
            walletId: wallet.metaId,
            assetKey: firstAsset.assetKey,
            userDefaults: defaults
        )

        let remote = DiscoveryAccountInfoRemoteStub()
        let service: AssetDiscoveryService = AssetDiscoveryServiceAdapter(
            accountInfoRemote: remote,
            userDefaults: defaults
        )
        let result = await service.scan(
            wallet: wallet,
            chains: [firstChain, secondChain],
            includeTestnets: false,
            trigger: .pullToRefresh
        )

        XCTAssertEqual(result.trigger, .pullToRefresh)
        XCTAssertEqual(remote.recordedChainIds(), Set([firstChain.chainId, secondChain.chainId]))
        XCTAssertEqual(
            Set(result.accountInfosByChain.keys.map(\.chainId)),
            Set([firstChain.chainId, secondChain.chainId])
        )
        XCTAssertTrue(result.failedChainIds.isEmpty)
        XCTAssertEqual(
            AssetVisibilityPreferenceStore.preference(
                walletId: wallet.metaId,
                assetKey: firstAsset.assetKey,
                userDefaults: defaults
            ),
            .hidden
        )
    }

    func testRemoteLastKnownBalancesPersistByAssetKeyAndAuthoritativeZeroOverwritesValue() throws {
        let suiteName = "ChainAssetListTests.last-known.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let chain = makeChain(name: "Remote", chainId: "solana:mainnet")
        let first = makeChainAsset(chain: chain, id: "mint-a", symbol: "SAME")
        let second = makeChainAsset(chain: chain, id: "mint-b", symbol: "SAME")
        let wallet = AccountGenerator.generateMetaAccount()

        RemoteLastKnownBalanceStore.save(
            [first.chainAssetId: Optional(AccountInfo(ethBalance: BigUInt(99)))],
            chain: chain,
            walletId: wallet.metaId,
            userDefaults: defaults
        )
        var loaded = RemoteLastKnownBalanceStore.load(
            chain: chain,
            walletId: wallet.metaId,
            userDefaults: defaults
        )
        XCTAssertEqual((loaded[first.chainAssetId] ?? nil)?.data.sendAvailable, BigUInt(99))
        XCTAssertNil(loaded[second.chainAssetId] ?? nil)

        RemoteLastKnownBalanceStore.save(
            [first.chainAssetId: Optional(AccountInfo(ethBalance: .zero))],
            chain: chain,
            walletId: wallet.metaId,
            userDefaults: defaults
        )
        loaded = RemoteLastKnownBalanceStore.load(
            chain: chain,
            walletId: wallet.metaId,
            userDefaults: defaults
        )
        XCTAssertEqual((loaded[first.chainAssetId] ?? nil)?.data.sendAvailable, .zero)
    }

    func testFailedDiscoveryReturnsPersistedBalanceAndMarksNetworkStale() async {
        let wallet = AccountGenerator.generateMetaAccount()
        // Use a network for which the generated test wallet has an account.
        // Ecosystem-specific wallets are intentionally filtered before a
        // remote request when the required account is absent.
        let chain = makeChain(
            name: "Remote",
            chainId: "failed-substrate-\(UUID().uuidString.lowercased())"
        )
        let asset = makeChainAsset(chain: chain, id: "mint-a", symbol: "TOKEN")
        let retained: [ChainAssetId: AccountInfo?] = [
            asset.chainAssetId: Optional(AccountInfo(ethBalance: BigUInt(77)))
        ]
        let remote = FailingLastKnownRemoteStub(retained: retained)
        let result = await AssetDiscoveryServiceAdapter(accountInfoRemote: remote).scan(
            wallet: wallet,
            chains: [chain],
            includeTestnets: false,
            trigger: .pullToRefresh
        )

        XCTAssertEqual(result.failedChainIds, Set([chain.chainId]))
        XCTAssertEqual(
            (result.accountInfosByChain[chain]?[asset.chainAssetId] ?? nil)?.data.sendAvailable,
            BigUInt(77)
        )
        XCTAssertTrue(NetworkScanStateStore.state(for: chain, walletId: wallet.metaId).hasError)
    }

    func testDiscoveryOfAPartlyReadNetworkKeepsWhatItReadAndMarksTheNetworkFailed() async {
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = makeChain(name: "Partly read", chainId: "partly-read-\(UUID().uuidString.lowercased())")
        let read = makeChainAsset(chain: chain, id: "read", symbol: "READ")
        let unread = makeChainAsset(chain: chain, id: "unread", symbol: "UNREAD")
        let remote = IncompleteRemoteStub(
            read: [read.chainAssetId: AccountInfo(ethBalance: BigUInt(5))],
            unread: [unread.chainAssetId]
        )

        let result = await AssetDiscoveryServiceAdapter(accountInfoRemote: remote).scan(
            wallet: wallet,
            chains: [chain],
            includeTestnets: false,
            trigger: .pullToRefresh
        )

        XCTAssertEqual(result.failedChainIds, Set([chain.chainId]))
        XCTAssertEqual(result.accountInfosByChain[chain].map { Set($0.keys) }, Set([read.chainAssetId]))
        XCTAssertEqual((result.accountInfosByChain[chain]?[read.chainAssetId] ?? nil)?.data.free, BigUInt(5))
        XCTAssertTrue(NetworkScanStateStore.state(for: chain, walletId: wallet.metaId).hasError)
    }

    func testListRefreshGivesWhatAPartlyReadNetworkReadAndNothingForTheAssetItCouldNotRead() async {
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = makeChain(name: "Partly read", chainId: "partly-read-\(UUID().uuidString.lowercased())")
        let read = makeChainAsset(chain: chain, id: "read", symbol: "READ")
        let empty = makeChainAsset(chain: chain, id: "empty", symbol: "EMPTY")
        let unread = makeChainAsset(chain: chain, id: "unread", symbol: "UNREAD")
        let remote = IncompleteRemoteStub(
            read: [read.chainAssetId: AccountInfo(ethBalance: BigUInt(5)), empty.chainAssetId: nil],
            unread: [unread.chainAssetId]
        )

        let delivered = await ChainAssetListInteractor.remoteAccountInfos(for: chain, wallet: wallet, service: remote)

        // The asset that could not be read gets nothing, so the list keeps the balance it shows instead of a zero.
        XCTAssertEqual(Set(delivered.map { $0.0.chainAssetId }), Set([read.chainAssetId, empty.chainAssetId]))
        XCTAssertEqual(delivered.first { $0.0 == read }?.1?.data.free, BigUInt(5))
        XCTAssertNil(delivered.first { $0.0 == empty }?.1)
        XCTAssertTrue(NetworkScanStateStore.state(for: chain, walletId: wallet.metaId).hasError)

        // Other scans give every asset of the network, as before: what was read, or what was last known.
        let retained = await ChainAssetListInteractor.remoteAccountInfos(
            for: chain,
            wallet: wallet,
            service: FailingLastKnownRemoteStub(retained: [read.chainAssetId: AccountInfo(ethBalance: BigUInt(7))])
        )
        XCTAssertEqual(Set(retained.map { $0.0.chainAssetId }), Set(chain.chainAssets.map(\.chainAssetId)))
        XCTAssertEqual(retained.first { $0.0 == read }?.1?.data.free, BigUInt(7))
        XCTAssertNil(retained.first { $0.0 == unread }?.1)
    }

    @MainActor
    func testEmptyFundingCardWaitsForBalancesAndNeverCallsHiddenFundsEmpty() throws {
        let asset = makeChainAsset(
            chain: makeChain(name: "Funding network", rank: 1),
            id: "native",
            symbol: "TOKEN",
            isUtility: true,
            isNative: true
        )
        let wallet = AccountGenerator.generateMetaAccount()
        let presenter = ChainAssetListPresenter(
            interactor: ChainAssetListInteractorInputSpy(),
            router: ChainAssetListRouterSpy(),
            localizationManager: LocalizationManager.shared,
            wallet: wallet,
            viewModelFactory: makeFactory()
        )
        let view = PortfolioViewSpy()
        presenter.didLoad(view: view)
        presenter.didReceiveChainAssets(result: .success([asset]))
        drainPortfolioDeliveries()
        XCTAssertEqual(view.models.last?.showsFundingCard, false)
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: .zero)), for: asset)
        drainPortfolioDeliveries()
        XCTAssertEqual(view.models.last?.showsFundingCard, true)
        XCTAssertEqual(view.models.last?.canReceive, true)
        XCTAssertEqual(view.models.last?.canBuy, false)
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: asset.assetKey)
        defer { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: asset.assetKey) }
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 1)), for: asset)
        drainPortfolioDeliveries()
        XCTAssertEqual(view.models.last?.showsFundingCard, false)
        XCTAssertEqual(view.models.last?.isWalletEmpty, false)
    }

    @MainActor
    func testEmptyFundingUsesExactNetworkAndRejectsWalletReturnAndNewDeposit() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let first = makeChainAsset(
            chain: makeChain(name: "Same network", rank: 1),
            id: "token-a",
            symbol: "TOKEN",
            isUtility: true
        )
        let second = makeChainAsset(
            chain: makeChain(name: "Same network", rank: 1),
            id: "token-b",
            symbol: "TOKEN",
            isUtility: true
        )
        let assets = [first, second]
        let router = ChainAssetListRouterSpy(), view = PortfolioViewSpy()
        let presenter = ChainAssetListPresenter(
            interactor: ChainAssetListInteractorInputSpy(),
            router: router,
            localizationManager: LocalizationManager.shared,
            wallet: wallet,
            viewModelFactory: makeFactory()
        )
        presenter.didLoad(view: view)
        func load() {
            presenter.didReceiveChainAssets(result: .success(assets))
            assets
                .forEach { presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: .zero)), for: $0) }
            drainPortfolioDeliveries()
        }
        load()
        presenter.didTapFunding(.receive, walletId: wallet.metaId)
        let options = try XCTUnwrap(router.fundingOptions.last)
        let sorted = PortfolioFundingPolicy.candidates(assets, wallet: wallet, action: .receive)
        options[1].select()
        XCTAssertEqual(router.receivedAssets, [sorted[1].assetKey])
        presenter.handleWalletChanged(wallet: AccountGenerator.generateMetaAccount())
        presenter.handleWalletChanged(wallet: wallet)
        load()
        options[0].select()
        XCTAssertEqual(router.receivedAssets.count, 1, "A→B→A cannot revive a pending funding selection")
        presenter.didTapFunding(.receive, walletId: wallet.metaId)
        let depositStale = try XCTUnwrap(router.fundingOptions.last?.first)
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 100)), for: first)
        drainPortfolioDeliveries()
        depositStale.select()
        XCTAssertEqual(router.receivedAssets.count, 1)
    }

    @MainActor
    func testEmptyBuyProviderSelectionRejectsWalletChangesBeforeOpeningPurchase() throws {
        let original = try XCTUnwrap(SendNetworkFixture.assets()
            .first(where: { PortfolioFundingPolicy.supportsPurchase($0) }))
        let asset = makeChainAsset(
            chain: original.chain,
            id: original.asset.id,
            symbol: "DOT",
            isUtility: true,
            isNative: true,
            buyEnabled: true
        )
        let wallet = AccountGenerator.generateMetaAccount()
        let router = ChainAssetListRouterSpy(), view = PortfolioViewSpy()
        let presenter = ChainAssetListPresenter(
            interactor: ChainAssetListInteractorInputSpy(),
            router: router,
            localizationManager: LocalizationManager.shared,
            wallet: wallet,
            viewModelFactory: makeFactory()
        )
        presenter.didLoad(view: view)
        func load() {
            presenter.didReceiveChainAssets(result: .success([asset]))
            presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: .zero)), for: asset)
            drainPortfolioDeliveries()
        }
        load()
        XCTAssertEqual(view.models.last?.canBuy, true)
        presenter.didTapFunding(.buy, walletId: wallet.metaId)
        let network = try XCTUnwrap(router.fundingOptions.last?.first)
        XCTAssertEqual(network.title, "DOT · " + asset.chain.name)
        network.select()
        let providers = try XCTUnwrap(router.fundingOptions.last)
        XCTAssertEqual(Set(providers.map(\.title)), ["Moonpay", "Ramp"])
        presenter.handleWalletChanged(wallet: AccountGenerator.generateMetaAccount())
        presenter.handleWalletChanged(wallet: wallet)
        load()
        providers[0].select()
        XCTAssertTrue(router.purchases.isEmpty)
        presenter.didTapFunding(.buy, walletId: wallet.metaId)
        try XCTUnwrap(router.fundingOptions.last?.first).select()
        try XCTUnwrap(router.fundingOptions.last?.first).select()
        XCTAssertEqual(router.purchases.count, 1)
    }

    func testPurchasePolicyRequiresExactPolkadotAssetAndExplicitProviders() throws {
        let assets = try SendNetworkFixture.assets()
        let dot = try XCTUnwrap(assets.first(where: { PortfolioFundingPolicy.supportsPurchase($0) }))
        let wallet = AccountGenerator.generateMetaAccount()
        XCTAssertTrue(PortfolioFundingPolicy.supportsPurchase(dot))
        for other in assets where other.assetKey != dot.assetKey {
            XCTAssertFalse(PortfolioFundingPolicy.supportsPurchase(other))
            XCTAssertTrue(PortfolioFundingPolicy.purchaseActions(for: other, wallet: wallet).isEmpty)
        }
        let counterfeit = makeChainAsset(
            chain: makeChain(name: dot.chain.name),
            id: dot.asset.id,
            symbol: "DOT",
            isUtility: true
        )
        XCTAssertFalse(PortfolioFundingPolicy.supportsPurchase(counterfeit))
        let supported = makeChainAsset(
            chain: dot.chain,
            id: dot.asset.id,
            symbol: "DOT",
            isUtility: true,
            isNative: true,
            buyEnabled: true
        )
        let actions = PortfolioFundingPolicy.purchaseActions(for: supported, wallet: wallet)
        do {
            XCTAssertFalse(actions.isEmpty)
            XCTAssertTrue(actions.allSatisfy { ["Moonpay", "Ramp"].contains($0.title) })
            for action in actions {
                let query = try XCTUnwrap(URLComponents(url: action.url, resolvingAgainstBaseURL: false)?.queryItems)
                XCTAssertTrue(query
                    .contains {
                        ["walletAddress", "userAddress"].contains($0.name) && $0.value == PortfolioFundingPolicy
                            .address(
                                for: dot,
                                wallet: wallet
                            )
                    })
            }
        }
        XCTAssertEqual(Set(actions.map(\.title)), ["Moonpay", "Ramp"])
        let accountlessBitcoin = assets.first { $0.chain.chainId == "bitcoin:mainnet" }
        if let accountlessBitcoin {
            XCTAssertNil(PortfolioFundingPolicy.address(for: accountlessBitcoin, wallet: wallet))
            XCTAssertTrue(PortfolioFundingPolicy.candidates([accountlessBitcoin], wallet: wallet, action: .receive)
                .isEmpty)
        }
    }

    @MainActor
    func testSharedAssetPickerKeepsExactIdentityWhenSymbolsAndNetworkNamesCollide() async throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let firstChain = makeChain(name: "Same network", chainId: "picker-first")
        let secondChain = makeChain(name: "Same network", chainId: "picker-second")
        let first = makeChainAsset(chain: firstChain, id: "token-a", symbol: "TOKEN")
        let second = makeChainAsset(chain: firstChain, id: "token-b", symbol: "TOKEN")
        let third = makeChainAsset(chain: secondChain, id: "token-b", symbol: "TOKEN")
        let assets = [first, second, third]
        let output = ExactAssetSelectionOutputSpy()
        let presenter = SelectAssetPresenter(
            viewModelFactory: SelectAssetViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory()),
            wallet: wallet, selectedAssetId: nil, searchTextsViewModel: nil,
            interactor: ExactAssetSelectionInteractorStub(), router: SelectAssetRouter(), output: output,
            localizationManager: LocalizationManager.shared, contextTag: 41
        )
        let view = SelectAssetViewController(
            isFullSize: true,
            output: presenter,
            localizationManager: LocalizationManager.shared,
            embed: false
        )
        view.loadViewIfNeeded()
        presenter.didReceiveChainAssets(result: .success(assets))
        presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: .zero)), for: first)
        for _ in 0 ..< 200 where presenter.numberOfItems != 3 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(presenter.numberOfItems, 3)
        presenter.searchItem(with: "token")
        for asset in assets {
            let index = try XCTUnwrap((0 ..< presenter.numberOfItems)
                .first { (presenter.item(at: $0) as? SelectAssetCellViewModel)?.assetKey == asset.assetKey })
            presenter.selectItem(at: index)
            presenter.willDisappear()
            XCTAssertEqual(output.assets.last, asset.assetKey)
            XCTAssertEqual(output.contexts.last, 41)
        }
    }

    private func makeFactory() -> ChainAssetListViewModelFactory {
        ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
    }

    private func makeChain(
        name: String,
        rank: UInt16? = nil,
        disabled: Bool = false,
        chainId: String = UUID().uuidString.lowercased(),
        xcm: XcmChain? = nil,
        options: [ChainOptions]? = nil
    ) -> ChainModel {
        ChainModel(
            rank: rank,
            disabled: disabled,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: name,
            xcm: xcm,
            nodes: [],
            addressPrefix: 42,
            types: nil,
            icon: nil,
            options: options,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeChainAsset(
        chain: ChainModel,
        id: String,
        symbol: String,
        price: Decimal? = nil,
        isUtility: Bool = false,
        isNative: Bool = false,
        buyEnabled: Bool = false
    ) -> ChainAsset {
        let asset = AssetModel(
            id: id,
            name: symbol,
            symbol: symbol,
            precision: 0,
            icon: nil,
            price: price,
            fiatDayChange: nil,
            currencyId: id,
            existentialDeposit: nil,
            color: nil,
            isUtility: isUtility,
            isNative: isNative,
            staking: nil,
            purchaseProviders: buyEnabled ? [.moonpay, .ramp] : nil,
            type: nil,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: price == nil ? nil : id
        )
        chain.assets.insert(asset)

        if let price,
           let priceId = asset.priceId {
            ExactAssetPriceCache.shared.upsert([
                PriceData(
                    currencyId: Currency.defaultCurrency().id,
                    priceId: priceId,
                    price: NSDecimalNumber(decimal: price).stringValue,
                    fiatDayChange: nil,
                    coingeckoPriceId: asset.coingeckoPriceId
                )
            ])
        }

        return ChainAsset(chain: chain, asset: asset)
    }

    private func balances(
        wallet: MetaAccountModel,
        values: [ChainAsset: UInt64]
    ) -> [ChainAssetKey: AccountInfo?] {
        Dictionary(uniqueKeysWithValues: values.compactMap { chainAsset, value in
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return nil
            }
            return (
                chainAsset.uniqueKey(accountId: accountId),
                AccountInfo(
                    nonce: 0,
                    consumers: 0,
                    providers: 0,
                    data: AccountData(free: BigUInt(value), reserved: 0, frozen: 0, flags: 0)
                )
            )
        })
    }

    private func preference(
        _ chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        defaults: UserDefaults
    ) -> AssetPreference {
        AssetVisibilityPreferenceStore.preference(
            walletId: wallet.metaId,
            assetKey: chainAsset.assetKey,
            userDefaults: defaults
        )
    }
}

private final class FailingLastKnownRemoteStub: AccountInfoRemoteService,
    AccountInfoLastKnownBalanceProviding,
    @unchecked Sendable {
    let retained: [ChainAssetId: AccountInfo?]

    init(retained: [ChainAssetId: AccountInfo?]) {
        self.retained = retained
    }

    func fetchAccountInfos(
        for _: ChainModel,
        wallet _: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        throw ConvenienceError(error: "offline")
    }

    func fetchAccountInfo(
        for _: ChainAsset,
        wallet _: MetaAccountModel
    ) async throws -> AccountInfo? {
        throw ConvenienceError(error: "offline")
    }

    func lastKnownAccountInfos(
        for _: ChainModel,
        wallet _: MetaAccountModel
    ) -> [ChainAssetId: AccountInfo?] {
        retained
    }
}

/// A network scan that read some balances and could not read the others.
private final class IncompleteRemoteStub: AccountInfoRemoteService, @unchecked Sendable {
    let read: [ChainAssetId: AccountInfo?]
    let unread: Set<ChainAssetId>

    init(read: [ChainAssetId: AccountInfo?], unread: Set<ChainAssetId>) {
        self.read = read
        self.unread = unread
    }

    func fetchAccountInfos(
        for _: ChainModel,
        wallet _: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        throw IncompleteAccountInfosError(accountInfos: read, unreadChainAssetIds: unread)
    }

    func fetchAccountInfo(
        for _: ChainAsset,
        wallet _: MetaAccountModel
    ) async throws -> AccountInfo? {
        throw ConvenienceError(error: "not read")
    }
}

private final class DiscoveryAccountInfoRemoteStub: AccountInfoRemoteService, @unchecked Sendable {
    private let lock = NSLock()
    private var chainIds = Set<ChainModel.Id>()

    func fetchAccountInfos(
        for chain: ChainModel,
        wallet _: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        lock.withLock {
            _ = chainIds.insert(chain.chainId)
        }
        return [:]
    }

    func fetchAccountInfo(
        for _: ChainAsset,
        wallet _: MetaAccountModel
    ) async throws -> AccountInfo? {
        nil
    }

    func recordedChainIds() -> Set<ChainModel.Id> {
        lock.withLock { chainIds }
    }
}

private final class PortfolioViewSpy: ChainAssetListViewInput {
    let isSetup = true
    var controller: UIViewController = UIViewController()
    var models: [ChainAssetListViewModel] = []
    func didReceive(viewModel: ChainAssetListViewModel) { models.append(viewModel) }
    func reloadBanners() {}
}

private final class ChainAssetListInteractorOutputSpy: ChainAssetListInteractorOutput {
    private(set) var updateViewModelCalls = 0
    private(set) var lastIsInitSearchState: Bool?

    func updateViewModel(isInitSearchState: Bool) {
        updateViewModelCalls += 1
        lastIsInitSearchState = isInitSearchState
    }

    func didReceiveChainAssets(result _: Result<[ChainAsset], Error>) {}
    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, for _: ChainAsset) {}
    func didReceiveWallet(wallet _: MetaAccountModel) {}
    func didReceiveChainsWithIssues(_: [ChainIssue]) {}
    func didReceive(accountInfosByChainAssets _: [ChainAsset: AccountInfo?]) {}
    func handleWalletChanged(wallet _: MetaAccountModel) {}
    func didReceive(chainSettings _: [ChainSettings]) {}
    func didAdoptStoredWalletSeed(result _: Result<MetaAccountModel, Error>) {}
}

private enum StoredSeedAdoptionTestError: Error, Equatable {
    case expected
}

private final class ChainAssetListInteractorInputSpy: ChainAssetListInteractorInput {
    var shouldRunManageAssetAnimate = false
    private(set) var storedSeedAdoptionCalls = 0
    private(set) var hiddenAssets: [AssetKey] = []

    func setup(with _: ChainAssetListInteractorOutput) {}

    func updateChainAssets(
        using _: [ChainAssetsFetching.Filter],
        sorts _: [ChainAssetsFetching.SortDescriptor],
        useCashe _: Bool
    ) {}

    func markUnused(chain _: ChainModel) {}
    func reload() {}

    func getAvailableChainAssets(
        chainAsset _: ChainAsset,
        completion: @escaping (([ChainAsset]) -> Void)
    ) {
        completion([])
    }

    func hideChainAsset(_ asset: ChainAsset) { hiddenAssets.append(asset.assetKey) }
    func showChainAsset(_: ChainAsset) {}
    func retryConnection(for _: ChainModel.Id) {}

    func adoptStoredWalletSeed() {
        storedSeedAdoptionCalls += 1
    }
}

private final class ChainAssetListRouterSpy: ChainAssetListRouterInput {
    var fundingOptions: [[PortfolioFundingOption]] = []
    var purchases: [PurchaseAction] = []
    var groupHideViewModels: [SheetAlertPresentableViewModel] = []
    var presentsNativeGroupActions = false
    func showGroupHideConfirmation(from view: ControllerBackedProtocol?, viewModel: SheetAlertPresentableViewModel) {
        groupHideViewModels.append(viewModel)
        if presentsNativeGroupActions {
            ChainAssetListRouter().showGroupHideConfirmation(
                from: view,
                viewModel: viewModel
            )
        }
    }

    func showFundingOptions(
        from view: ControllerBackedProtocol?,
        title: String,
        options: [PortfolioFundingOption],
        locale: Locale
    ) {
        fundingOptions.append(options)
        if presentsNativeGroupActions {
            ChainAssetListRouter().showFundingOptions(from: view, title: title, options: options, locale: locale)
        }
    }

    func showPurchase(from _: ControllerBackedProtocol?, action: PurchaseAction) {
        purchases.append(action)
    }

    private(set) var sentAssets: [AssetKey] = []
    private(set) var receivedAssets: [AssetKey] = []
    private(set) var presentedSetupViewModels: [SheetAlertPresentableViewModel] = []
    private(set) var createdChainModels: [UniqueChainModel] = []
    private(set) var importedChainModels: [UniqueChainModel] = []
    private(set) var presentedErrors: [Error] = []

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {
        presentedSetupViewModels.append(viewModel)
    }

    func present(
        error: Error,
        from _: ControllerBackedProtocol?,
        locale _: Locale?
    ) -> Bool {
        presentedErrors.append(error)
        return true
    }

    func showImport(
        uniqueChainModel: UniqueChainModel,
        from _: ControllerBackedProtocol?
    ) {
        importedChainModels.append(uniqueChainModel)
    }

    func showAssetNetworks(from _: ControllerBackedProtocol?, chainAsset _: ChainAsset) {}
    func showChainAccount(from _: ControllerBackedProtocol?, chainAsset _: ChainAsset) {}

    func showSendFlow(
        from _: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) { sentAssets.append(chainAsset.assetKey) }

    func showReceiveFlow(
        from _: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) { receivedAssets.append(chainAsset.assetKey) }

    func presentAccountOptions(
        from _: ControllerBackedProtocol?,
        locale _: Locale?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func showCreate(
        uniqueChainModel: UniqueChainModel,
        from _: ControllerBackedProtocol?
    ) {
        createdChainModels.append(uniqueChainModel)
    }

    private(set) var manageAssetFilters: [String?] = []
    private(set) var manageVisibilityFilters: [ManageAssetsFilter] = []

    func showManageAsset(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        filter: NetworkManagmentFilter?,
        visibilityFilter: ManageAssetsFilter
    ) {
        manageAssetFilters.append(filter?.identifier)
        manageVisibilityFilters.append(visibilityFilter)
    }

    func showIssueNotification(
        from _: ControllerBackedProtocol?,
        issues _: [ChainIssue],
        wallet _: MetaAccountModel
    ) {}

    private(set) var walletListOpens = 0

    func showWalletManagment(from _: ControllerBackedProtocol?) {
        walletListOpens += 1
    }
}

/// A wallet with an Ethereum key and no Substrate key (an EVM-only import).
private func ethereumOnlyWallet() -> MetaAccountModel {
    let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
    return MetaAccountModel(
        metaId: wallet.metaId, name: wallet.name, substrateAccountId: nil, substrateCryptoType: 0,
        substratePublicKey: nil, ethereumAddress: wallet.ethereumAddress, ethereumPublicKey: wallet.ethereumPublicKey,
        chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: true, unusedChainIds: nil,
        selectedCurrency: wallet.selectedCurrency, networkManagmentFilter: nil, assetsVisibility: [],
        hasBackup: false, favouriteChainIds: []
    )
}

private final class VisibilityEventCenterRecorder: EventCenterProtocol {
    private(set) var events: [AssetVisibilityPreferenceChangedEvent] = []

    func notify(with event: EventProtocol) {
        if let event = event as? AssetVisibilityPreferenceChangedEvent {
            events.append(event)
        }
    }

    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}
    func remove(observer _: EventVisitorProtocol) {}
}

/// Every shipped locale has its own text for `keys` (decisions.md: no English fallbacks in a
/// shipped locale).
enum ShippedLocaleParity {
    /// The locales the app target ships (`pt.lproj` is in the repository but not in the target).
    static let locales = ["ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"]

    static func assertTranslated(keys: [String], file: StaticString = #filePath, line: UInt = #line) {
        let appBundle = Bundle(for: ChainAssetListPresenter.self)
        let english = appBundle.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
        for key in keys {
            let englishValue = english?.localizedString(forKey: key, value: nil, table: "Localizable")
            XCTAssertNotEqual(englishValue, key, "\(key) missing in en", file: file, line: line)
            for locale in locales {
                let bundle = appBundle.path(forResource: locale, ofType: "lproj").flatMap(Bundle.init(path:))
                let value = bundle?.localizedString(forKey: key, value: "", table: "Localizable") ?? ""
                XCTAssertFalse(value.isEmpty || value == key, "\(key) missing in \(locale)", file: file, line: line)
                XCTAssertNotEqual(value, englishValue, "\(key) left in English in \(locale)", file: file, line: line)
            }
        }
    }
}

private final class ExactAssetSelectionInteractorStub: SelectAssetInteractorInput {
    func setup(with _: SelectAssetInteractorOutput) {}
    func update(with _: [ChainAsset]) {}
}

private final class ExactAssetSelectionOutputSpy: SelectAssetModuleOutput {
    var assets: [AssetKey] = []
    var contexts: [Int?] = []
    func assetSelection(didCompleteWith chainAsset: ChainAsset?, contextTag: Int?) {
        if let chainAsset { assets.append(chainAsset.assetKey) }
        contexts.append(contextTag)
    }
}
