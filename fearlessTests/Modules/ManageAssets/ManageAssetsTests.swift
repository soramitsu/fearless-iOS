import XCTest
import UIKit
import SoraFoundation
import SoraUI
import SSFModels
import RobinHood
import BigInt
@testable import fearless

final class ManageAssetsTests: XCTestCase {
    @MainActor func testOldBalanceCompletionCannotUnlockANewerPreferenceSave() async throws {
        let f = try await fixture()
        var pendingBalance: CheckedContinuation<AccountInfo?, Error>?
        f.interactor.balanceFetch = { try await withCheckedThrowingContinuation { pendingBalance = $0 } }
        let first = try XCTUnwrap(f.view.models.last)
        f.presenter.didSelectRow(at: IndexPath(row: 0, section: 0), viewModel: first)
        await settle { pendingBalance != nil }
        let current = try XCTUnwrap(f.view.models.last)
        var pendingWrite: CheckedContinuation<Void, Never>?
        var suspendNext = true
        f.interactor.preferenceWrite = {
            guard suspendNext else { return }
            suspendNext = false
            await withCheckedContinuation { pendingWrite = $0 }
        }
        f.presenter.didSelectRow(at: IndexPath(row: 1, section: 0), viewModel: current)
        await settle { pendingWrite != nil }
        pendingBalance?.resume(returning: nil)
        pendingBalance = nil
        f.interactor.balanceFetch = nil
        await drain()
        f.presenter.didSelectRow(at: IndexPath(row: 2, section: 0), viewModel: current)
        await drain()
        XCTAssertEqual(f.interactor.changes.count, 2, "Finishing an old balance request must not release a different preference write")
        pendingWrite?.resume()
        await settle { f.view.models.last?.revision != current.revision }
        for asset in f.interactor.assets { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: f.wallet.metaId, assetKey: asset.assetKey) }
    }

    @MainActor func testResetOrderActionFitsShippedLocalesAndDispatchesOnlyWhenAvailable() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let wallet = AccountGenerator.generateMetaAccount().replacingAssetKeysOrder(["custom"])
        let assets = try SendNetworkFixture.assets()
        let factory = AssetManagementViewModelFactoryDefault(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
        for localeId in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let locale = Locale(identifier: localeId)
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: 320, height: 720)
                window.overrideUserInterfaceStyle = .dark
                if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
                let output = ManageOutputSpy()
                var taps = 0
                output.resetOrder = { taps += 1 }
                let controller = AssetManagementViewController(output: output, localizationManager: LocalizationManager.shared)
                window.rootViewController = controller
                window.makeKeyAndVisible()
                defer { window.isHidden = true; window.rootViewController = nil }
                controller.rootView.locale = locale
                var model = factory.buildViewModel(chainAssets: assets, accountInfos: [:], wallet: wallet, locale: locale, filter: nil, search: nil, pendingAccountInfoChainAssets: [])
                controller.didReceive(viewModel: model)
                controller.view.layoutIfNeeded()
                let header = try XCTUnwrap(controller.rootView.tableView.tableHeaderView)
                XCTAssertEqual(header.bounds.width, controller.rootView.tableView.bounds.width, accuracy: 0.5)
                XCTAssertGreaterThan(header.bounds.height, 0)
                for arranged in controller.rootView.headerStack.arrangedSubviews where !arranged.isHidden {
                    XCTAssertGreaterThan(arranged.bounds.height, 0)
                    XCTAssertTrue(header.bounds.insetBy(dx: -0.5, dy: -0.5).contains(arranged.convert(arranged.bounds, to: header)))
                }
                let measuredHeight = header.bounds.height
                controller.rootView.tableView.reloadData()
                controller.rootView.setNeedsLayout()
                controller.rootView.layoutIfNeeded()
                XCTAssertEqual(header.bounds.height, measuredHeight, accuracy: 0.5, "A subsequent table layout must preserve the measured header frame")
                let button = controller.rootView.resetOrderButton
                if localeId == "en" {
                    let root = controller.rootView
                    let arranged = root.headerStack.arrangedSubviews.map { "\(type(of: $0)) hidden=\($0.isHidden) frame=\($0.frame)" }.joined(separator: "\n")
                    let attachment = XCTAttachment(string: "root=\(root.bounds); table=\(root.tableView.bounds); header=\(root.headerStack.frame); fit=\(root.headerStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize));\n\(arranged)")
                    attachment.name = "manage-header-geometry-" + category.rawValue
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                let scroll = controller.rootView.tableView
                scroll.scrollRectToVisible(button.convert(button.bounds, to: scroll), animated: false)
                controller.view.layoutIfNeeded()
                XCTAssertFalse(button.isHidden)
                XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
                XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                XCTAssertLessThanOrEqual(button.bounds.width, scroll.bounds.width + 1)
                XCTAssertTrue(scroll.bounds.insetBy(dx: -1, dy: -1).contains(button.convert(button.bounds, to: scroll)))
                for control in [controller.rootView.doneButton, controller.rootView.filterNetworksButton, button] {
                    let title = try XCTUnwrap(control.titleLabel)
                    let expectedFont = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: control.traitCollection)
                    XCTAssertEqual(title.font.pointSize, expectedFont.pointSize, accuracy: 0.5, "The action font must follow this window's text-size traits on both runtimes")
                    XCTAssertGreaterThanOrEqual(title.bounds.height + 1, title.sizeThatFits(CGSize(width: title.bounds.width, height: .greatestFiniteMagnitude)).height)
                    XCTAssertTrue(control.bounds.contains(title.convert(title.bounds, to: control)))
                }
                let label = try XCTUnwrap(button.titleLabel)
                XCTAssertGreaterThanOrEqual(label.bounds.height + 1, label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
                XCTAssertTrue(button.bounds.contains(label.convert(label.bounds, to: button)))
                XCTAssertNotNil(button.hitTest(CGPoint(x: button.bounds.midX, y: button.bounds.midY), with: nil))
                button.sendActions(for: .touchUpInside)
                XCTAssertEqual(taps, 1)
                if category.isAccessibilityCategory, ["en", "ru", "ja"].contains(localeId) {
                    let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true) })
                    attachment.name = "manage-reset-order-320pt-maximum-text-" + localeId
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                model.canResetOrder = false
                controller.didReceive(viewModel: model)
                XCTAssertTrue(button.isHidden)
                model.list = []
                controller.didReceive(viewModel: model)
                controller.view.layoutIfNeeded()
                XCTAssertFalse(controller.rootView.emptyResultsLabel.isHidden)
                XCTAssertTrue(controller.rootView.tableView.isUserInteractionEnabled)
                XCTAssertTrue(controller.rootView.headerStack.isDescendant(of: controller.rootView.tableView))
                if #available(iOS 17.0, *), category == .large {
                    let originalHeight = controller.rootView.headerStack.bounds.height
                    controller.rootView.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
                    controller.rootView.updateTraitsIfNeeded()
                    controller.rootView.setNeedsLayout()
                    controller.rootView.layoutIfNeeded()
                    XCTAssertGreaterThan(controller.rootView.headerStack.bounds.height, originalHeight)
                    XCTAssertTrue(controller.rootView.headerStack.bounds.contains(controller.rootView.emptyResultsLabel.convert(controller.rootView.emptyResultsLabel.bounds, to: controller.rootView.headerStack)))
                    for control in [controller.rootView.doneButton, controller.rootView.filterNetworksButton] {
                        let title = try XCTUnwrap(control.titleLabel)
                        let expectedFont = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: control.traitCollection)
                        XCTAssertEqual(title.font.pointSize, expectedFont.pointSize, accuracy: 0.5, "An already visible action must update after a text-size trait change")
                        XCTAssertTrue(control.bounds.contains(title.convert(title.bounds, to: control)))
                    }
                }
            }
        }
    }

    @MainActor func testRealResetOrderSheetFitsAndCancelsInCompactLocalizedWindows() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for localeId in ["en", "ru", "ja"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let f = try await nativeResetSheet(scene: scene, localeId: localeId, category: category)
                let (host, window, sheet) = (f.host, f.window, f.sheet)
                defer { window.isHidden = true; window.rootViewController = nil }
                let locale = Locale(identifier: localeId)
                let title = PortfolioStrings.text("manage_assets.reset_order", locale: locale)
                let message = PortfolioStrings.text("manage_assets.reset_order_message", locale: locale)
                let cancel = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
                sheet.view.layoutIfNeeded()
                let views = descendants(sheet.view)
                let labels = views.compactMap { $0 as? UILabel }
                let description = try XCTUnwrap(labels.first { $0.text == message })
                let capture = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) })
                capture.name = "manage-reset-sheet-320x568-" + localeId + "-" + category.rawValue
                capture.lifetime = .keepAlways
                add(capture)
                let geometry = XCTAttachment(string: "window=\(window.bounds); sheet=\(sheet.view.convert(sheet.view.bounds, to: window)); labels=" + labels.map { "\($0.text ?? ""): frame=\($0.frame), font=\($0.font.pointSize)" }.joined(separator: "\n"))
                geometry.name = (capture.name ?? "reset-sheet") + "-geometry"
                geometry.lifetime = .keepAlways
                add(geometry)
                XCTAssertTrue(window.bounds.insetBy(dx: -1, dy: -1).contains(sheet.view.convert(sheet.view.bounds, to: window)))
                XCTAssertEqual(description.font.pointSize, UIFont.preferredFont(forTextStyle: .body, compatibleWith: description.traitCollection).pointSize, accuracy: 0.5)
                XCTAssertEqual(sheet.confirmButton.configuration?.background.backgroundColor, UIColor(named: "fwFillTop"))
                XCTAssertTrue(sheet.view.accessibilityViewIsModal)
                XCTAssertTrue(sheet.titleLabel.accessibilityTraits.contains(.header))
                for label in labels where label.text == title || label.text == message || label.text == cancel {
                    XCTAssertGreaterThanOrEqual(label.bounds.height + 1, label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
                    XCTAssertLessThanOrEqual(label.bounds.width, 280)
                }
                XCTAssertEqual(f.interactor.orderResets, 0)
                for button in [sheet.confirmButton, sheet.cancelButton] {
                    let label = try XCTUnwrap(button.titleLabel)
                    XCTAssertEqual(label.font.pointSize, UIFont.preferredFont(forTextStyle: .headline, compatibleWith: button.traitCollection).pointSize, accuracy: 0.5)
                    XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                    XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
                    XCTAssertTrue(button.bounds.insetBy(dx: -1, dy: -1).contains(label.convert(label.bounds, to: button)), "The action must grow to contain its full accessibility-sized caption")
                    sheet.scrollView.scrollRectToVisible(button.convert(button.bounds, to: sheet.scrollView), animated: false)
                    sheet.view.layoutIfNeeded()
                    XCTAssertTrue(sheet.scrollView.bounds.insetBy(dx: -1, dy: -1).contains(button.convert(button.bounds, to: sheet.scrollView)))
                    let point = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: window)
                    let hit = try XCTUnwrap(window.hitTest(point, with: nil))
                    XCTAssertTrue(hit === button || hit.isDescendant(of: button), "The visible action must receive touches through the actual presentation; hit=\(type(of: hit)), presenting=\(sheet.isBeingPresented), transition=\(String(describing: sheet.transitionCoordinator))")
                }
                if category.isAccessibilityCategory {
                    XCTAssertGreaterThan(sheet.scrollView.contentSize.height, sheet.scrollView.bounds.height)
                    let bottom = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) })
                    bottom.name = "manage-reset-sheet-320x568-" + localeId + "-maximum-text-actions"
                    bottom.lifetime = .keepAlways
                    add(bottom)
                }
                let closePoint = sheet.closeButton.convert(CGPoint(x: 22, y: 22), to: window)
                let closeHit = try XCTUnwrap(window.hitTest(closePoint, with: nil))
                XCTAssertTrue(closeHit === sheet.closeButton || closeHit.isDescendant(of: sheet.closeButton))
                if #available(iOS 17.0, *), category == .large {
                    sheet.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
                    sheet.updateTraitsIfNeeded()
                    sheet.view.layoutIfNeeded()
                    XCTAssertEqual(sheet.messageLabel.font.pointSize, UIFont.preferredFont(forTextStyle: .body, compatibleWith: sheet.traitCollection).pointSize, accuracy: 0.5)
                }
                let cancelButton = sheet.cancelButton
                cancelButton.sendActions(for: .touchUpInside)
                await settleSheet { host.presentedViewController == nil }
                XCTAssertNil(host.presentedViewController)
                XCTAssertEqual(f.interactor.orderResets, 0)
            }
        }
    }

    @MainActor func testRealResetOrderSheetConfirmsOnceAndRejectsStaleWallet() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for action in ["confirm", "stale", "close", "escape"] {
            let f = try await nativeResetSheet(scene: scene, localeId: "en", category: .large)
            let (host, window, sheet) = (f.host, f.window, f.sheet)
            defer { window.isHidden = true; window.rootViewController = nil }
            f.presenter.didTapResetOrder()
            await drain()
            XCTAssertTrue(host.presentedViewController === sheet)
            XCTAssertNil(sheet.presentedViewController)
            if action == "stale" { f.presenter.didChangeSelectedWallet(); await drain() }
            switch action {
            case "close": sheet.closeButton.sendActions(for: .touchUpInside)
            case "escape": XCTAssertTrue(sheet.accessibilityPerformEscape())
            default:
                sheet.confirmButton.sendActions(for: .touchUpInside)
                sheet.confirmButton.sendActions(for: .touchUpInside)
            }
            await settleSheet { host.presentedViewController == nil }
            XCTAssertNil(host.presentedViewController)
            if action == "confirm" { await settle { f.interactor.orderResets == 1 } }
            else { await drain() }
            XCTAssertEqual(f.interactor.orderResets, action == "confirm" ? 1 : 0)
        }
    }

    @MainActor private func nativeResetSheet(scene: UIWindowScene, localeId: String, category: UIContentSizeCategory) async throws -> (host: AssetManagementViewController, window: UIWindow, sheet: AssetManagementResetOrderViewController, presenter: AssetManagementPresenter, interactor: ManageInteractorStub) {
        let localization = try XCTUnwrap(LocalizationManager(localization: localeId))
        let wallet = AccountGenerator.generateMetaAccount().replacingAssetKeysOrder(["custom"])
        let interactor = ManageInteractorStub()
        interactor.assets = try SendNetworkFixture.assets().filter { CanonicalTokenGroupCatalog.bundled.group(for: $0)?.id == "usdt" }
        let presenter = AssetManagementPresenter(wallet: wallet, networkFilter: nil, logger: Logger.shared, viewModelFactory: AssetManagementViewModelFactoryDefault(assetBalanceFormatterFactory: AssetBalanceFormatterFactory()), interactor: interactor, router: AssetManagementRouter(), localizationManager: localization)
        let host = AssetManagementViewController(output: presenter, localizationManager: localization)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.rootView.locale = localization.selectedLocale
        await settle { !host.rootView.resetOrderButton.isHidden }
        host.view.layoutIfNeeded()
        host.rootView.resetOrderButton.sendActions(for: .touchUpInside)
        await settle { host.presentedViewController != nil }
        let sheet = try XCTUnwrap(host.presentedViewController as? AssetManagementResetOrderViewController)
        await settleSheet { !sheet.isBeingPresented && sheet.transitionCoordinator == nil }
        sheet.view.layoutIfNeeded()
        return (host, window, sheet, presenter, interactor)
    }

    @MainActor private func settleSheet(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0 ..< 300 where !condition() { try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(condition(), "Expected the real UIKit sheet transition to finish", file: file, line: line)
    }

    @MainActor private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }

    @MainActor func testResetOrderRequiresConfirmationAndHidesActionAfterSuccess() async throws {
        let f = try await fixture(wallet: AccountGenerator.generateMetaAccount().replacingAssetKeysOrder(["custom"]))
        XCTAssertEqual(f.view.models.last?.canResetOrder, true)
        f.presenter.didTapResetOrder()
        await settle { f.router.sheet != nil }
        XCTAssertEqual(f.interactor.orderResets, 0)
        let sheet = try XCTUnwrap(f.router.sheet)
        XCTAssertEqual(sheet.actions.count, 1)
        XCTAssertNotNil(sheet.closeAction)
        sheet.actions.first?.handler?()
        sheet.actions.first?.handler?()
        await settle { f.view.models.last?.canResetOrder == false }
        XCTAssertEqual(f.interactor.orderResets, 1)
        f.router.sheet = nil
        f.presenter.didTapResetOrder()
        await drain()
        XCTAssertNil(f.router.sheet)
    }

    @MainActor func testResetOrderConfirmationRejectsNewMetadataAndWalletSession() async throws {
        for switchWallet in [false, true] {
            let f = try await fixture(wallet: AccountGenerator.generateMetaAccount().replacingAssetKeysOrder(["custom"]))
            f.presenter.didTapResetOrder()
            await settle { f.router.sheet != nil }
            if switchWallet { f.presenter.didChangeSelectedWallet() }
            else { f.presenter.didReceiveUpdated(wallet: f.wallet.replacingName("Changed after confirmation opened")) }
            await drain()
            f.router.sheet?.actions.first?.handler?()
            await drain()
            XCTAssertEqual(f.interactor.orderResets, 0)
        }
    }

    @MainActor func testResetOrderFailureKeepsCustomOrderAndReportsError() async throws {
        let f = try await fixture(wallet: AccountGenerator.generateMetaAccount().replacingAssetKeysOrder(["custom"]))
        f.interactor.orderResetError = ManageTestFailure.unavailable
        f.presenter.didTapResetOrder()
        await settle { f.router.sheet != nil }
        f.router.sheet?.actions.first?.handler?()
        await settle { f.router.errors == 1 }
        XCTAssertEqual(f.view.models.last?.canResetOrder, true)
    }

    func testResetOrderPersistsOnlyOrderAndPreservesVisibilityAcrossReopen() async throws {
        let facade = UserDataStorageTestFacade(), queue = OperationQueue()
        let settings = SelectedWalletSettings(storageFacade: facade, operationQueue: queue)
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 2).replacingAssetKeysOrder(["second", "first"])
        let _: MetaAccountModel = try await withCheckedThrowingContinuation { continuation in
            settings.save(value: wallet, runningCompletionIn: nil) { continuation.resume(with: $0) }
        }
        let asset = try XCTUnwrap(try SendNetworkFixture.assets().first)
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: asset.assetKey)
        defer { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: asset.assetKey) }
        let events = ManageEventStub()
        let interactor = AssetManagementInteractor(chainAssetFetching: ManageAssetsFetcherStub(), accountInfoFetchingProvider: ManageCacheStub(), eventCenter: events, accountInfoRemoteService: ManageRemoteStub(), selectedWalletSettings: settings)
        let updated = try await interactor.resetOrder(wallet: wallet)
        XCTAssertNil(updated.assetKeysOrder)
        var before = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(wallet)) as? [String: Any])
        var after = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(updated)) as? [String: Any])
        before.removeValue(forKey: "assetKeysOrder")
        after.removeValue(forKey: "assetKeysOrder")
        XCTAssertTrue(NSDictionary(dictionary: before).isEqual(to: after))
        XCTAssertEqual(events.notifications, 1)
        XCTAssertEqual(AssetVisibilityPreferenceStore.preference(walletId: wallet.metaId, assetKey: asset.assetKey), .hidden)
        let reopened = SelectedWalletSettings(storageFacade: facade, operationQueue: queue)
        let persisted: MetaAccountModel? = try await withCheckedThrowingContinuation { continuation in
            reopened.setup(runningCompletionIn: nil) { continuation.resume(with: $0) }
        }
        XCTAssertEqual(persisted, updated)
    }

    func testResetOrderConditionalSaveRejectsChangedSnapshotAndOldSession() async throws {
        let settings = ManageWalletSettingsStub(storageFacade: UserDataStorageTestFacade())
        let wallet = AccountGenerator.generateMetaAccount().replacingAssetKeysOrder(["custom"])
        let changed = wallet.replacingName("New metadata")
        settings.applySetupResult(.success(changed))
        let events = ManageEventStub()
        let interactor = AssetManagementInteractor(chainAssetFetching: ManageAssetsFetcherStub(), accountInfoFetchingProvider: ManageCacheStub(), eventCenter: events, accountInfoRemoteService: ManageRemoteStub(), selectedWalletSettings: settings)
        do { _ = try await interactor.resetOrder(wallet: wallet); XCTFail("Stale metadata must not overwrite the wallet") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(settings.value, changed)
        settings.applySetupResult(.success(wallet))
        interactor.processSelectedAccountChanged(event: SelectedAccountChanged(account: wallet))
        do { _ = try await interactor.resetOrder(wallet: wallet); XCTFail("A → B → A must not revive a stale action") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(settings.value, wallet)
        XCTAssertEqual(settings.saveCount, 0)
        XCTAssertEqual(events.notifications, 0)
    }

    func testResetOrderSaveFailureRollsBackAndCanRetry() async throws {
        let settings = ManageWalletSettingsStub(storageFacade: UserDataStorageTestFacade())
        let wallet = AccountGenerator.generateMetaAccount().replacingAssetKeysOrder(["custom"])
        settings.applySetupResult(.success(wallet))
        settings.fail = true
        let events = ManageEventStub()
        let interactor = AssetManagementInteractor(chainAssetFetching: ManageAssetsFetcherStub(), accountInfoFetchingProvider: ManageCacheStub(), eventCenter: events, accountInfoRemoteService: ManageRemoteStub(), selectedWalletSettings: settings)
        do { _ = try await interactor.resetOrder(wallet: wallet); XCTFail("Expected persistence failure") } catch { XCTAssertTrue(error is ManageTestFailure) }
        XCTAssertEqual(settings.value, wallet)
        XCTAssertEqual(events.notifications, 0)
        settings.fail = false
        let saved = try await interactor.resetOrder(wallet: wallet)
        XCTAssertNil(saved.assetKeysOrder)
        XCTAssertEqual(events.notifications, 1)
        XCTAssertEqual(settings.saveCount, 2)
    }

    @MainActor func testCurrentRowsWriteExplicitPreferencesAndRejectStaleRows() async throws {
        let f = try await fixture()
        let initial = try XCTUnwrap(f.view.models.last)
        f.presenter.didSelectRow(at: IndexPath(row: 0, section: 0), viewModel: initial)
        await settle { f.interactor.changes.count == 1 && (f.view.models.last?.revision != initial.revision) && f.view.models.last?.list.flatMap(\.cells).allSatisfy { !$0.isLoadingBalance } == true }
        XCTAssertEqual(f.interactor.changes.first?.0, false)
        let changedAsset = try XCTUnwrap(f.interactor.changes.first?.1)
        XCTAssertEqual(AssetVisibilityPreferenceStore.preference(walletId: f.wallet.metaId, assetKey: changedAsset.assetKey), .shown)
        let current = try XCTUnwrap(f.view.models.last)
        XCTAssertFalse(try XCTUnwrap(current.list.flatMap(\.cells).first { $0.chainAsset.assetKey == changedAsset.assetKey }).hidden)
        f.presenter.didSelectRow(at: IndexPath(row: 0, section: 0), viewModel: initial)
        await drain()
        XCTAssertEqual(f.interactor.changes.count, 1)
        f.presenter.didSelectRow(at: IndexPath(row: 0, section: 0), viewModel: current)
        await settle { f.interactor.changes.count == 2 }
        XCTAssertEqual(f.interactor.changes.last?.0, true)
        f.presenter.doneButtonDidTapped()
        AssetVisibilityPreferenceStore.setPreference(.auto, walletId: f.wallet.metaId, assetKey: changedAsset.assetKey)
    }

    @MainActor func testResetAutomaticWritesExactAssetRejectsStaleMenuAndHasAccessibleSwipeAction() async throws {
        let f = try await fixture()
        let row = try XCTUnwrap(f.interactor.assets.first)
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: f.wallet.metaId, assetKey: row.assetKey)
        defer { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: f.wallet.metaId, assetKey: row.assetKey) }
        f.presenter.didSelectVisibilityFilter(.hidden)
        await settle { f.view.models.last?.visibilityFilter == .hidden }
        let model = try XCTUnwrap(f.view.models.last)
        let output = ManageOutputSpy()
        output.reset = { f.presenter.didResetToAutomatic(at: $0, viewModel: $1) }
        let controller = AssetManagementViewController(output: output, localizationManager: LocalizationManager.shared)
        controller.loadViewIfNeeded()
        controller.didReceive(viewModel: model)
        let index = IndexPath(row: 0, section: 0)
        let configuration = try XCTUnwrap(controller.tableView(UITableView(), trailingSwipeActionsConfigurationForRowAt: index))
        XCTAssertFalse(configuration.performsFirstActionWithFullSwipe)
        XCTAssertEqual(configuration.actions.count, 1)
        XCTAssertFalse(configuration.actions[0].title?.isEmpty ?? true)
        XCTAssertNil(controller.tableView(UITableView(), trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 99, section: 99)))
        let cell = try XCTUnwrap(controller.tableView(controller.rootView.tableView, cellForRowAt: index) as? AssetManagementTableCell)
        let reset = try XCTUnwrap(cell.accessibilityCustomActions?.first)
        XCTAssertTrue(reset.actionHandler?(reset) == true)
        await settle { f.interactor.resets.count == 1 }
        XCTAssertEqual(f.interactor.resets, [row.assetKey])
        XCTAssertEqual(AssetVisibilityPreferenceStore.preference(walletId: f.wallet.metaId, assetKey: row.assetKey), .auto)
        f.presenter.didResetToAutomatic(at: index, viewModel: model)
        await drain()
        XCTAssertEqual(f.interactor.resets.count, 1)
        cell.prepareForReuse()
        XCTAssertNil(cell.accessibilityCustomActions)
        f.presenter.doneButtonDidTapped()
    }

    @MainActor func testGroupMixedActionChangesEveryExactMemberAndRejectsStaleHeader() async throws {
        let f = try await fixture()
        defer { for asset in f.interactor.assets { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: f.wallet.metaId, assetKey: asset.assetKey) } }
        let asset = try XCTUnwrap(f.interactor.assets.first)
        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: f.wallet.metaId, assetKey: asset.assetKey)
        f.presenter.didSelectVisibilityFilter(.shown)
        await settle { f.view.models.last?.visibilityFilter == .shown }
        let mixed = try XCTUnwrap(f.view.models.last)
        XCTAssertEqual(mixed.list[0].cells.count, 1)
        XCTAssertEqual(mixed.list[0].groupVisibility, .mixed)
        f.presenter.didToggleGroup(on: 0, viewModel: mixed)
        await settle { f.interactor.changes.count == f.interactor.assets.count && f.view.models.last?.list[0].groupVisibility == .on && f.view.models.last?.list[0].cells.allSatisfy { !$0.isLoadingBalance } == true }
        XCTAssertEqual(Set(f.interactor.changes.map { $0.1.assetKey }), Set(f.interactor.assets.map(\.assetKey)))
        XCTAssertTrue(f.interactor.changes.allSatisfy { !$0.0 })
        f.presenter.didToggleGroup(on: 0, viewModel: mixed)
        await drain()
        XCTAssertEqual(f.interactor.changes.count, f.interactor.assets.count)
        let shown = try XCTUnwrap(f.view.models.last)
        f.presenter.didToggleGroup(on: 0, viewModel: shown)
        await settle { f.view.models.last?.list.isEmpty == true }
        XCTAssertTrue(f.interactor.assets.allSatisfy { AssetVisibilityPreferenceStore.preference(walletId: f.wallet.metaId, assetKey: $0.assetKey) == .hidden })
        f.presenter.didChangeSelectedWallet()
        f.presenter.didToggleGroup(on: 0, viewModel: shown)
        await drain()
        XCTAssertEqual(f.interactor.changes.count, f.interactor.assets.count * 2)
    }

    @MainActor func testGroupHeaderMixedAccessibilityAndControlTapDoesNotExpand() throws {
        let f = AssetManagementViewModelFactoryDefault(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
        let model = f.buildViewModel(chainAssets: try SendNetworkFixture.assets(), accountInfos: [:], wallet: AccountGenerator.generateMetaAccount(), locale: Locale(identifier: "en"), filter: nil, search: nil, pendingAccountInfoChainAssets: [])
        var section = try XCTUnwrap(model.list.first { $0.id == "group:usdt" })
        let header = AssetManagementTableHeaderView(reuseIdentifier: nil)
        var visibilityActions = 0, expansionActions = 0
        header.onToggleVisibility = { visibilityActions += 1 }
        header.onToggleExpansion = { expansionActions += 1 }
        for (state, caption) in [(ManageGroupVisibility.on, "Shown"), (.off, "Hidden"), (.mixed, "Mixed")] {
            section.groupVisibility = state
            header.bind(viewModel: section, locale: Locale(identifier: "en"))
            XCTAssertFalse(header.visibilityButton.isHidden)
            XCTAssertNotNil(header.visibilityButton.currentImage)
            XCTAssertEqual(header.visibilityButton.accessibilityValue, caption)
            XCTAssertTrue(header.visibilityButton.accessibilityLabel?.contains("all networks") == true)
            header.visibilityButton.sendActions(for: .touchUpInside)
            XCTAssertTrue(header.textContainer.accessibilityActivate())
        }
        XCTAssertEqual(visibilityActions, 3)
        XCTAssertEqual(expansionActions, 3)
        let controller = AssetManagementViewController(output: ManageOutputSpy(), localizationManager: LocalizationManager.shared)
        XCTAssertFalse(controller.gestureRecognizer(UITapGestureRecognizer(), shouldReceive: ManageTouch(target: header.visibilityButton.imageView ?? header.visibilityButton)))
        XCTAssertTrue(controller.gestureRecognizer(UITapGestureRecognizer(), shouldReceive: ManageTouch(target: header.symbolLabel)))
        header.prepareForReuse()
        header.visibilityButton.sendActions(for: .touchUpInside)
        XCTAssertFalse(header.textContainer.accessibilityActivate())
        XCTAssertEqual(visibilityActions, 3)
    }

    @MainActor func testGroupHeaderControlsAndFullCaptionFitCompactMaximumText() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let factory = AssetManagementViewModelFactoryDefault(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
        let model = factory.buildViewModel(chainAssets: try SendNetworkFixture.assets(), accountInfos: [:], wallet: AccountGenerator.generateMetaAccount(), locale: Locale(identifier: "en"), filter: nil, search: nil, pendingAccountInfoChainAssets: [])
        var section = try XCTUnwrap(model.list.first { $0.id == "group:usdt" })
        section.groupVisibility = .mixed
        let category = UIContentSizeCategory.accessibilityExtraExtraExtraLarge
        UITraitCollection(preferredContentSizeCategory: category).performAsCurrent {
            let header = AssetManagementTableHeaderView(reuseIdentifier: nil)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
            window.overrideUserInterfaceStyle = .dark
            if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
            let host = UIViewController()
            host.view.addSubview(header)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true; window.rootViewController = nil }
            header.bind(viewModel: section, locale: Locale(identifier: "en"))
            header.frame = CGRect(x: 0, y: 80, width: 320, height: 55)
            header.layoutIfNeeded()
            header.frame.size.height = header.contentView.systemLayoutSizeFitting(CGSize(width: 320, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
            header.setNeedsLayout()
            header.layoutIfNeeded()
            for label in [header.symbolLabel, header.countLabel] {
                XCTAssertGreaterThanOrEqual(label.bounds.height + 1, label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
                XCTAssertTrue(header.bounds.contains(label.convert(label.bounds, to: header)))
            }
            XCTAssertEqual(header.visibilityButton.bounds.width, 44, accuracy: 1)
            XCTAssertGreaterThanOrEqual(header.visibilityButton.bounds.height, 44)
            XCTAssertTrue(header.bounds.contains(header.visibilityButton.convert(header.visibilityButton.bounds, to: header)))
            XCTAssertTrue(header.bounds.contains(header.imageView.convert(header.imageView.bounds, to: header)))
            XCTAssertGreaterThanOrEqual(header.countLabel.bounds.width, 240)
            XCTAssertLessThanOrEqual(header.textContainer.convert(header.textContainer.bounds, to: header).maxY + 8, header.visibilityButton.convert(header.visibilityButton.bounds, to: header).minY)
            XCTAssertEqual(header.textContainer.accessibilityValue, "Collapsed")
            let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: header.bounds).image { _ in header.drawHierarchy(in: header.bounds, afterScreenUpdates: true) })
            attachment.name = "manage-group-mixed-320pt-maximum-text"
            attachment.lifetime = .keepAlways
            add(attachment)
            if #available(iOS 17.0, *) {
                header.traitOverrides.preferredContentSizeCategory = .large
                header.updateTraitsIfNeeded()
                XCTAssertEqual(header.traitCollection.preferredContentSizeCategory, .large)
                header.layoutIfNeeded()
                header.frame.size.height = header.contentView.systemLayoutSizeFitting(CGSize(width: 320, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
                header.setNeedsLayout()
                header.layoutIfNeeded()
                XCTAssertLessThanOrEqual(header.textContainer.convert(header.textContainer.bounds, to: header).maxX + 12, header.visibilityButton.convert(header.visibilityButton.bounds, to: header).minX)
            }
        }
    }

    func testGroupInteractorDeduplicatesExactPreferencesAndRejectsOldWallet() async throws {
        let wallet = AccountGenerator.generateMetaAccount(), assets = try SendNetworkFixture.assets()
        let first = try XCTUnwrap(assets.first), second = try XCTUnwrap(assets.last)
        let events = ManageEventStub()
        let interactor = AssetManagementInteractor(chainAssetFetching: ManageAssetsFetcherStub(), accountInfoFetchingProvider: ManageCacheStub(), eventCenter: events, accountInfoRemoteService: ManageRemoteStub())
        defer { for asset in [first, second] { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: asset.assetKey) } }
        await interactor.changeGroup(hidden: true, chainAssets: [first, first, second], wallet: wallet)
        XCTAssertEqual(events.notifications, 2)
        for asset in [first, second] { XCTAssertEqual(AssetVisibilityPreferenceStore.preference(walletId: wallet.metaId, assetKey: asset.assetKey), .hidden) }
        interactor.processSelectedAccountChanged(event: SelectedAccountChanged(account: AccountGenerator.generateMetaAccount()))
        await interactor.changeGroup(hidden: false, chainAssets: [first, second], wallet: wallet)
        XCTAssertEqual(events.notifications, 2)
        for asset in [first, second] { XCTAssertEqual(AssetVisibilityPreferenceStore.preference(walletId: wallet.metaId, assetKey: asset.assetKey), .hidden) }
    }

    @MainActor func testNewestRefreshWinsAndSelectedWalletChangeDropsLateRefresh() async throws {
        let f = try await fixture()
        var pending: [CheckedContinuation<[ChainAssetKey: AccountInfo?], Error>] = []
        f.interactor.refresh = { try await withCheckedThrowingContinuation { pending.append($0) } }
        f.presenter.didPullToRefresh()
        await settle { pending.count == 1 }
        f.presenter.didPullToRefresh()
        await settle { pending.count == 2 }
        guard pending.count == 2 else { return }
        let asset = try XCTUnwrap(f.interactor.assets.first)
        let account = try XCTUnwrap(f.wallet.fetch(for: asset.chain.accountRequest()))
        let key = asset.uniqueKey(accountId: account.accountId)
        pending[1].resume(returning: [key: info(2_000_000)])
        await settle { f.view.models.last?.list.flatMap(\.cells).first { $0.chainAsset.assetKey == asset.assetKey }?.amount == 2 }
        let count = f.view.models.count
        pending[0].resume(returning: [key: info(99_000_000)])
        await drain()
        XCTAssertEqual(f.view.models.count, count)
        f.presenter.didPullToRefresh()
        await settle { pending.count == 3 }
        guard pending.count == 3 else { return }
        f.presenter.didChangeSelectedWallet()
        pending[2].resume(returning: [key: info(88_000_000)])
        await settle { f.router.dismissals == 1 }
        await drain()
        XCTAssertEqual(f.view.models.count, count)
    }

    @MainActor func testAnotherWalletEventCannotRebindActionsAndDismissInvalidatesThem() async throws {
        let f = try await fixture()
        f.presenter.didReceiveUpdated(wallet: AccountGenerator.generateMetaAccount())
        await drain()
        f.presenter.allNetworkButtonDidTapped()
        await settle { f.router.networkWalletIds.count == 1 }
        XCTAssertEqual(f.router.networkWalletIds, [f.wallet.metaId])
        let old = try XCTUnwrap(f.view.models.last)
        f.presenter.doneButtonDidTapped()
        f.presenter.didSelectRow(at: IndexPath(row: 0, section: 0), viewModel: old)
        f.presenter.allNetworkButtonDidTapped()
        await settle { f.router.dismissals == 1 }
        await drain()
        XCTAssertTrue(f.interactor.changes.isEmpty)
        XCTAssertEqual(f.router.networkWalletIds.count, 1)
    }

    @MainActor func testExpansionSearchNetworkAndLocaleRebuildCurrentModel() async throws {
        let f = try await fixture()
        let first = try XCTUnwrap(f.view.models.last)
        f.presenter.didTap(on: 0, viewModel: first)
        await settle { f.view.models.last?.list.first?.isExpanded == true }
        let expanded = try XCTUnwrap(f.view.models.last)
        f.presenter.didTap(on: 0, viewModel: first)
        await drain()
        XCTAssertEqual(f.view.models.last?.revision, expanded.revision)
        f.presenter.searchTextDidChanged("no such asset")
        await settle { f.view.models.last?.list.isEmpty == true }
        f.presenter.searchTextDidChanged(nil)
        await settle { f.view.models.last?.list.isEmpty == false }
        let asset = try XCTUnwrap(f.interactor.assets.first)
        f.presenter.did(select: .chain(asset.chain.chainId), contextTag: nil)
        await settle { f.view.models.last?.list.flatMap(\.cells).count == 1 }
        XCTAssertEqual(f.view.models.last?.list.flatMap(\.cells).first?.chainAsset.assetKey, asset.assetKey)
        let count = f.view.models.count
        f.presenter.applyLocalization()
        await settle { f.view.models.count > count }
        f.presenter.doneButtonDidTapped()
    }

    @MainActor func testHiddenFilterIgnoresNetworkScopeAndNewFilterInvalidatesOldRows() async throws {
        let f = try await fixture()
        let hidden = try XCTUnwrap(f.interactor.assets.last)
        let other = try XCTUnwrap(f.interactor.assets.first)
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: f.wallet.metaId, assetKey: hidden.assetKey)
        defer { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: f.wallet.metaId, assetKey: hidden.assetKey) }
        f.presenter.did(select: .chain(other.chain.chainId), contextTag: nil)
        await settle { f.view.models.last?.networkFilter?.identifier == other.chain.chainId }
        let previous = try XCTUnwrap(f.view.models.last)
        f.presenter.didSelectVisibilityFilter(.hidden)
        await settle { f.view.models.last?.visibilityFilter == .hidden }
        XCTAssertEqual(f.view.models.last?.dispayedChainAssets.map(\.assetKey), [hidden.assetKey])
        f.presenter.didSelectRow(at: IndexPath(row: 0, section: 0), viewModel: previous)
        await drain()
        XCTAssertTrue(f.interactor.changes.isEmpty)
        f.presenter.didSelectVisibilityFilter(.auto)
        await settle { f.view.models.last?.visibilityFilter == .auto }
        XCTAssertTrue(f.view.models.last?.list.flatMap(\.cells).allSatisfy { $0.preference == .auto } == true)
        XCTAssertEqual(f.view.models.last?.networkFilter?.identifier, other.chain.chainId)
        f.presenter.doneButtonDidTapped()
        let count = f.view.models.count
        f.presenter.didSelectVisibilityFilter(.all)
        await drain()
        XCTAssertEqual(f.view.models.count, count)
    }

    @MainActor func testDismissBeforeInitialDataPreventsLatePresentation() async throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = ManageInteractorStub()
        var pending: CheckedContinuation<[ChainAsset], Error>?
        interactor.load = { try await withCheckedThrowingContinuation { pending = $0 } }
        let view = ManageViewStub(), router = ManageRouterStub()
        let presenter = makePresenter(wallet, interactor, router)
        presenter.didLoad(view: view)
        await settle { pending != nil }
        presenter.doneButtonDidTapped()
        pending?.resume(returning: try SendNetworkFixture.assets())
        await settle { router.dismissals == 1 }
        await drain()
        XCTAssertTrue(view.models.isEmpty)
    }

    func testRefreshScansBalancesWithoutWritingPreferencesOrSavingWallet() async throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let asset = try XCTUnwrap(try SendNetworkFixture.assets().first)
        let remote = ManageRemoteStub(), events = ManageEventStub()
        let interactor = AssetManagementInteractor(chainAssetFetching: ManageAssetsFetcherStub(), accountInfoFetchingProvider: ManageCacheStub(), eventCenter: events, accountInfoRemoteService: remote)
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: asset.assetKey)
        defer { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: asset.assetKey) }
        let result = try await interactor.refreshAccountInfos(for: [asset, asset], wallet: wallet)
        XCTAssertEqual(Set(remote.requests), Set(asset.chain.chainAssets.map(\.assetKey)))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(AssetVisibilityPreferenceStore.preference(walletId: wallet.metaId, assetKey: asset.assetKey), .hidden)
        XCTAssertEqual(events.notifications, 0)
        await interactor.resetToAutomatic(chainAsset: asset, wallet: wallet)
        XCTAssertEqual(AssetVisibilityPreferenceStore.preference(walletId: wallet.metaId, assetKey: asset.assetKey), .auto)
        XCTAssertEqual(events.notifications, 1)
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: asset.assetKey)
        interactor.processSelectedAccountChanged(event: SelectedAccountChanged(account: AccountGenerator.generateMetaAccount()))
        _ = await interactor.change(hidden: false, chainAsset: asset, wallet: wallet)
        await interactor.resetToAutomatic(chainAsset: asset, wallet: wallet)
        XCTAssertEqual(events.notifications, 1)
        XCTAssertEqual(AssetVisibilityPreferenceStore.preference(walletId: wallet.metaId, assetKey: asset.assetKey), .hidden)
        do { _ = try await interactor.refreshAccountInfos(for: [asset], wallet: wallet); XCTFail("Changed wallet must invalidate the old Manage session") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(remote.requests.count, asset.chain.chainAssets.count)
    }

    @MainActor
    func testHiddenPreferenceCaptionAndBalanceFitCompactMaximumTextAndResetOnReuse() throws {
        let asset = try XCTUnwrap(try SendNetworkFixture.assets().first)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
        var model = AssetManagementTableCellViewModel(chainAsset: asset, assetImage: nil, assetName: "USDT", chainName: "Polkadot AssetHub", balance: BalanceViewModel(amount: "123456.123456", price: "$123,456.12"), decimalPrice: 123_456, hidden: true, hasGroup: true, isLoadingBalance: false, preference: .hidden, preferenceCaption: "Hidden · 非表示")
        let controller = ManageRowFixtureController(model: model)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.frame = window.bounds
        // Keep the first row below the scene's system scroll-edge region. The
        // production table sits below Manage's own header; this bare fixture does not.
        controller.tableView.contentInset.top = 80
        controller.tableView.setContentOffset(CGPoint(x: 0, y: -80), animated: false)
        controller.tableView.layoutIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        let cell = try XCTUnwrap(controller.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? AssetManagementTableCell)
        let geometry = XCTAttachment(string: "window=\(window.bounds); controller=\(controller.view.frame); table=\(controller.tableView.bounds); cell=\(cell.frame); content=\(cell.contentView.frame); switch=\(cell.switchView.convert(cell.switchView.bounds, to: cell)); text=\(cell.textContainer.frame)")
        geometry.name = "manage-compact-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
        XCTAssertEqual(controller.tableView.bounds.width, 320, accuracy: 1)
        XCTAssertEqual(cell.bounds.width, 320, accuracy: 1)
        XCTAssertGreaterThan(cell.bounds.height, 55)
        XCTAssertEqual(cell.contentView.bounds.width, cell.bounds.width, accuracy: 1)
        XCTAssertTrue(cell.bounds.contains(cell.switchView.convert(cell.switchView.bounds, to: cell)))
        XCTAssertGreaterThanOrEqual(cell.switchView.bounds.width, cell.switchView.intrinsicContentSize.width)
        XCTAssertFalse(cell.switchView.isOn)
        XCTAssertFalse(cell.balanceTextsContainer.isHidden)
        XCTAssertEqual(cell.preferenceLabel.text, "Hidden · 非表示")
        XCTAssertEqual(cell.accessibilityValue, model.preferenceCaption)
        for label in [cell.symbolLabel, cell.chainNameLabel, cell.preferenceLabel, cell.balanceLabel, cell.fiatBalanceLabel] {
            XCTAssertGreaterThan(label.bounds.width, 100)
            XCTAssertGreaterThanOrEqual(label.bounds.height + 1, label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
            XCTAssertTrue(cell.bounds.contains(label.convert(label.bounds, to: cell)))
        }
        let capture = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: capture)
        attachment.name = "manage-hidden-caption-320pt-maximum-text"
        attachment.lifetime = .keepAlways
        add(attachment)
        cell.prepareForReuse()
        XCTAssertNil(cell.preferenceLabel.text)
        XCTAssertEqual(cell.accessibilityValue ?? "", "")
        model.hidden = false
        model.preferenceCaption = "Shown"
        cell.bind(viewModel: model)
        XCTAssertTrue(cell.switchView.isOn)
        XCTAssertEqual(cell.accessibilityValue, "Shown")
        XCTAssertTrue(cell.accessibilityTraits.contains(.selected))

        let output = makePresenter(AccountGenerator.generateMetaAccount(), ManageInteractorStub(), ManageRouterStub())
        let manage = AssetManagementViewController(output: output, localizationManager: LocalizationManager.shared)
        let header = AssetManagementTableHeaderView(reuseIdentifier: nil)
        manage.tableView(UITableView(), willDisplayHeaderView: header, forSection: 0)
        manage.tableView(UITableView(), willDisplayHeaderView: header, forSection: 1)
        XCTAssertEqual(header.gestureRecognizers?.filter { $0 is UITapGestureRecognizer }.count, 1)
        XCTAssertEqual(header.tag, 1)
    }

    @MainActor
    func testAnotherPreferenceRemainsAvailableWhileBalanceLookupWaits() async throws {
        let f = try await fixture()
        var pending: [CheckedContinuation<AccountInfo?, Error>] = []
        f.interactor.balanceFetch = { try await withCheckedThrowingContinuation { pending.append($0) } }
        let first = try XCTUnwrap(f.view.models.last)
        f.presenter.didSelectRow(at: IndexPath(row: 0, section: 0), viewModel: first)
        await settle { pending.count == 1 }
        let second = try XCTUnwrap(f.view.models.last)
        f.presenter.didSelectRow(at: IndexPath(row: 1, section: 0), viewModel: second)
        await settle { pending.count == 2 }
        XCTAssertEqual(f.interactor.changes.count, 2)
        f.presenter.doneButtonDidTapped()
        pending.forEach { $0.resume(returning: nil) }
        await drain()
        for (_, asset) in f.interactor.changes { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: f.wallet.metaId, assetKey: asset.assetKey) }
    }

    func testRefreshContinuesAfterNetworkFailureButThrowsWhenEveryNetworkFails() async throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let assets = try SendNetworkFixture.assets().filter { CanonicalTokenGroupCatalog.bundled.group(for: $0)?.id == "usdt" }
        let first = try XCTUnwrap(assets.first)
        let remote = ManageRemoteStub()
        remote.failingChainIds = [first.chain.chainId]
        let interactor = AssetManagementInteractor(chainAssetFetching: ManageAssetsFetcherStub(), accountInfoFetchingProvider: ManageCacheStub(), eventCenter: ManageEventStub(), accountInfoRemoteService: remote)
        let result = try await interactor.refreshAccountInfos(for: assets, wallet: wallet)
        XCTAssertEqual(result.count, assets.count - 1)
        let account = try XCTUnwrap(wallet.fetch(for: first.chain.accountRequest()))
        XCTAssertNil(result[first.uniqueKey(accountId: account.accountId)])
        remote.failingChainIds = Set(assets.map { $0.chain.chainId })
        do { _ = try await interactor.refreshAccountInfos(for: assets, wallet: wallet); XCTFail("All failed scans must report their failure") } catch { XCTAssertTrue(error is ManageTestFailure) }
    }

    func testWalletChangeDuringRemoteScanRejectsItsResult() async throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let asset = try XCTUnwrap(try SendNetworkFixture.assets().first)
        let remote = ManageRemoteStub()
        let interactor = AssetManagementInteractor(chainAssetFetching: ManageAssetsFetcherStub(), accountInfoFetchingProvider: ManageCacheStub(), eventCenter: ManageEventStub(), accountInfoRemoteService: remote)
        remote.onScan = { _ in interactor.processSelectedAccountChanged(event: SelectedAccountChanged(account: wallet)) }
        do { _ = try await interactor.refreshAccountInfos(for: [asset], wallet: wallet); XCTFail("An old scan must not revive after selection changes") } catch { XCTAssertTrue(error is CancellationError) }
    }

    @MainActor private func fixture(wallet: MetaAccountModel = AccountGenerator.generateMetaAccount()) async throws -> (presenter: AssetManagementPresenter, interactor: ManageInteractorStub, view: ManageViewStub, router: ManageRouterStub, wallet: MetaAccountModel) {
        let interactor = ManageInteractorStub()
        interactor.assets = try SendNetworkFixture.assets().filter { CanonicalTokenGroupCatalog.bundled.group(for: $0)?.id == "usdt" }
        let view = ManageViewStub(), router = ManageRouterStub(), presenter = makePresenter(wallet, interactor, router)
        presenter.didLoad(view: view)
        await settle { !view.models.isEmpty }
        return (presenter, interactor, view, router, wallet)
    }

    private func makePresenter(_ wallet: MetaAccountModel, _ interactor: ManageInteractorStub, _ router: ManageRouterStub) -> AssetManagementPresenter {
        AssetManagementPresenter(wallet: wallet, networkFilter: nil, logger: Logger.shared, viewModelFactory: AssetManagementViewModelFactoryDefault(assetBalanceFormatterFactory: AssetBalanceFormatterFactory()), interactor: interactor, router: router, localizationManager: LocalizationManager.shared)
    }

    @MainActor private func settle(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0 ..< 200 where !condition() { try? await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertTrue(condition(), "Expected asynchronous operation to settle", file: file, line: line)
    }

    @MainActor private func drain() async { for _ in 0 ..< 8 { await Task.yield() } }
    private func info(_ value: UInt64) -> AccountInfo { AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: BigUInt(value), reserved: 0, frozen: 0, flags: 0)) }
}

private final class ManageInteractorStub: AssetManagementInteractorInput {
    var orderResets = 0
    var orderResetError: Error?
    func resetOrder(wallet: MetaAccountModel) async throws -> MetaAccountModel {
        orderResets += 1
        if let orderResetError { throw orderResetError }
        return wallet.replacingAssetKeysOrder(nil)
    }

    var assets: [ChainAsset] = []
    var changes: [(Bool, ChainAsset)] = []
    var load: (() async throws -> [ChainAsset])?
    var refresh: (() async throws -> [ChainAssetKey: AccountInfo?])?
    var balanceFetch: (() async throws -> AccountInfo?)?
    var preferenceWrite: (() async -> Void)?
    func setup(with _: AssetManagementInteractorOutput) async {}
    func getAvailableChainAssets() async throws -> [ChainAsset] { try await load?() ?? assets }
    func getAccountInfos(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAssetKey: AccountInfo?] { [:] }
    func change(hidden _: Bool, assetId _: String, wallet: MetaAccountModel) async -> MetaAccountModel { wallet }
    func change(hidden: Bool, chainAsset: ChainAsset, wallet: MetaAccountModel) async -> MetaAccountModel {
        changes.append((hidden, chainAsset))
        await preferenceWrite?()
        AssetVisibilityPreferenceStore.setExplicitlyHidden(hidden, walletId: wallet.metaId, chainAsset: chainAsset)
        return wallet
    }

    func changeGroup(hidden: Bool, chainAssets: [ChainAsset], wallet: MetaAccountModel) async {
        for asset in chainAssets { _ = await change(hidden: hidden, chainAsset: asset, wallet: wallet) }
    }

    var resets: [AssetKey] = []
    func resetToAutomatic(chainAsset: ChainAsset, wallet: MetaAccountModel) async {
        resets.append(chainAsset.assetKey)
        AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: chainAsset.assetKey)
    }

    func fetchAccountInfo(for _: ChainAsset, wallet _: MetaAccountModel) async throws -> AccountInfo? { try await balanceFetch?() }
    func refreshAccountInfos(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAssetKey: AccountInfo?] { try await refresh?() ?? [:] }
}

@MainActor private final class ManageViewStub: UIViewController, AssetManagementViewInput {
    var models: [AssetManagementViewModel] = []
    func didReceive(viewModel: AssetManagementViewModel) { models.append(viewModel) }
    func didReceive(viewModel: AssetManagementViewModel, on _: Int) { models.append(viewModel) }
}

private final class ManageRouterStub: AssetManagementRouterInput {
    var sheet: SheetAlertPresentableViewModel?
    var errors = 0
    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { sheet = viewModel }
    var dismissals = 0
    var networkWalletIds: [String] = []
    func showSelectNetwork(from _: ControllerBackedProtocol?, wallet: MetaAccountModel, delegate _: NetworkManagmentModuleOutput?) { networkWalletIds.append(wallet.metaId) }
    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { errors += 1; return true }
}

private enum ManageTestFailure: Error { case unavailable }

private final class ManageRemoteStub: AccountInfoRemoteService {
    var requests: [AssetKey] = []
    var failingChainIds = Set<String>()
    var onScan: ((ChainModel) -> Void)?
    func fetchAccountInfos(for chain: ChainModel, wallet: MetaAccountModel) async throws -> [ChainAssetId: AccountInfo?] {
        onScan?(chain)
        if failingChainIds.contains(chain.chainId) { throw ManageTestFailure.unavailable }
        var result: [ChainAssetId: AccountInfo?] = [:]
        for asset in chain.chainAssets { result[asset.chainAssetId] = .some(try await fetchAccountInfo(for: asset, wallet: wallet)) }
        return result
    }

    func fetchAccountInfo(for chainAsset: ChainAsset, wallet _: MetaAccountModel) async throws -> AccountInfo? {
        requests.append(chainAsset.assetKey)
        return AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: 1, reserved: 0, frozen: 0, flags: 0))
    }
}

private final class ManageEventStub: EventCenterProtocolStub, @unchecked Sendable {
    var notifications = 0
    override func notify(with _: EventProtocol) { notifications += 1 }
}

private final class ManageAssetsFetcherStub: ChainAssetFetchingProtocol {
    func fetch(shouldUseCache _: Bool, filters _: [ChainAssetsFetching.Filter], sortDescriptors _: [ChainAssetsFetching.SortDescriptor], completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void) { completionBlock(.success([])) }
    func fetchAwaitOperation(shouldUseCache _: Bool, filters _: [ChainAssetsFetching.Filter], sortDescriptors _: [ChainAssetsFetching.SortDescriptor]) -> BaseOperation<[ChainAsset]> { ClosureOperation { [] } }
    func fetchAwait(shouldUseCache _: Bool, filters _: [ChainAssetsFetching.Filter], sortDescriptors _: [ChainAssetsFetching.SortDescriptor]) async throws -> [ChainAsset] { [] }
}

private final class ManageCacheStub: AccountInfoFetchingProtocol {
    func fetch(for chainAsset: ChainAsset, accountId _: AccountId, completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void) { completionBlock(chainAsset, nil) }
    func fetch(for _: [ChainAsset], wallet _: MetaAccountModel, completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void) { completionBlock([:]) }
    func fetch(for chainAsset: ChainAsset, accountId _: AccountId) async throws -> (ChainAsset, AccountInfo?) { (chainAsset, nil) }
    func fetch(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAsset: AccountInfo?] { [:] }
    func fetchByUniqKey(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAssetKey: AccountInfo?] { [:] }
}

@MainActor
private final class ManageRowFixtureController: UITableViewController {
    private let model: AssetManagementTableCellViewModel
    init(model: AssetManagementTableCellViewModel) {
        self.model = model
        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(AssetManagementTableCell.self, forCellReuseIdentifier: "row")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 300
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.separatorStyle = .none
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { 1 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath) as? AssetManagementTableCell
        guard let cell else { return UITableViewCell() }
        cell.bind(viewModel: model)
        return cell
    }
}

private final class ManageOutputSpy: AssetManagementViewOutput {
    var resetOrder: (() -> Void)?
    func didTapResetOrder() { resetOrder?() }
    var reset: ((IndexPath, AssetManagementViewModel) -> Void)?
    func didLoad(view _: AssetManagementViewInput) {}
    func doneButtonDidTapped() {}
    func searchTextDidChanged(_: String?) {}
    func allNetworkButtonDidTapped() {}
    func didSelectRow(at _: IndexPath, viewModel _: AssetManagementViewModel) {}
    func didTap(on _: Int, viewModel _: AssetManagementViewModel) {}
    func didPullToRefresh() {}
    func didSelectVisibilityFilter(_: ManageAssetsFilter) {}
    func didToggleGroup(on _: Int, viewModel _: AssetManagementViewModel) {}
    func didResetToAutomatic(at indexPath: IndexPath, viewModel: AssetManagementViewModel) { reset?(indexPath, viewModel) }
}

private final class ManageTouch: UITouch {
    private let target: UIView
    init(target: UIView) { self.target = target; super.init() }
    override var view: UIView? { target }
}

private final class ManageWalletSettingsStub: PersistentValueSettings<MetaAccountModel> {
    var fail = false
    var saveCount = 0
    override func performSave(value: MetaAccountModel, completionClosure: @escaping (Result<MetaAccountModel, Error>) -> Void) {
        saveCount += 1
        completionClosure(fail ? .failure(ManageTestFailure.unavailable) : .success(value))
    }
}


@MainActor
final class ManageAssetsPresentationTests: XCTestCase {
    private let languages = ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"]

    func testActualManageRowsHeadersAndActionsAcrossLocalesAndTextSizes() async throws {
        try XCTSkipUnless(FWAppearance.assetManagementRestyled)
        for language in languages {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let f = try fixture(language: language, category: category)
                defer { close(f) }
                let root = f.controller.rootView, table = root.tableView
                await settle(f)
                let name = "manage-presentation-\(language)-\(category.rawValue)"
                capture(f, name: name + "-top")
                assertFont(root.manageAssetStubLabel, .titleS)
                assertFont(root.emptyResultsLabel, .bodyM)
                for (filter, button) in root.visibilityFilterButtons {
                    XCTAssertEqual(
                        button.currentTitle,
                        PortfolioStrings.text("manage_assets." + filter.rawValue, locale: Locale(identifier: language))
                    )
                    assertFont(try XCTUnwrap(button.titleLabel), .labelM)
                    root.setVisibilityFilter(filter)
                    await settle(f)
                    await reveal(root.visibilityFilterScrollView, f)
                    assertHit(button, f)
                    button.sendActions(for: .touchUpInside)
                    XCTAssertEqual(f.output.filters.last, filter)
                }
                root.setVisibilityFilter(.all)
                await settle(f)
                await reveal(root.resetOrderButton, f)
                assertHit(root.resetOrderButton, f)
                root.resetOrderButton.sendActions(for: .touchUpInside)
                XCTAssertEqual(f.output.resets, 1)
                capture(f, name: name + "-reset")
                await reveal(root.filterNetworksButton, f)
                assertHit(root.filterNetworksButton, f)
                root.filterNetworksButton.sendActions(for: .touchUpInside)
                XCTAssertEqual(f.output.networks, 1)
                root.searchTextField.textField.text = "USDT"
                root.searchTextField.textFieldDidChange()
                XCTAssertEqual(f.output.searches.last!, "USDT")
                table.scrollRectToVisible(table.rectForHeader(inSection: 0), animated: false)
                await settle(f)
                let header = try XCTUnwrap(table.headerView(forSection: 0) as? AssetManagementTableHeaderView)
                assertFont(header.symbolLabel, .titleS)
                assertFont(header.countLabel, .bodyM)
                assertLabelsFit(header)
                await reveal(header.visibilityButton, f)
                assertHit(header.visibilityButton, f)
                header.visibilityButton.sendActions(for: .touchUpInside)
                XCTAssertEqual(f.output.groups.last, "group:usdt")
                XCTAssertEqual(
                    header.visibilityButton.accessibilityValue,
                    PortfolioStrings.text("manage_assets.mixed", locale: Locale(identifier: language))
                )
                XCTAssertTrue(header.textContainer.accessibilityActivate())
                XCTAssertEqual(f.output.expansions.last, "group:usdt")
                capture(f, name: name + "-group")
                for row in 0 ..< 3 {
                    let index = IndexPath(row: row, section: 0)
                    for _ in 0 ..< 3 {
                        table.scrollToRow(at: index, at: .middle, animated: false)
                        await settle(f)
                    }
                    let cell = try XCTUnwrap(table.cellForRow(at: index) as? AssetManagementTableCell)
                    let model = f.model.list[0].cells[row]
                    XCTAssertEqual(cell.symbolLabel.text, model.assetName)
                    XCTAssertEqual(cell.chainNameLabel.text, model.chainName)
                    XCTAssertEqual(cell.preferenceLabel.text, model.preferenceCaption)
                    XCTAssertEqual(cell.switchView.isOn, !model.hidden)
                    assertCell(cell)
                    assertRowHit(cell, f)
                    let before = f.output.assets.count
                    f.controller.tableView(table, didSelectRowAt: index)
                    XCTAssertEqual(f.output.assets.count, before + 1)
                    XCTAssertEqual(f.output.assets.last, model.chainAsset.assetKey)
                    let action = try XCTUnwrap(cell.accessibilityCustomActions?.first)
                    XCTAssertTrue(action.actionHandler?(action) == true)
                    XCTAssertEqual(f.output.automatic.last, model.chainAsset.assetKey)
                    capture(f, name: name + "-row\(row)")
                }
                assertHit(root.doneButton, f)
                root.doneButton.sendActions(for: .touchUpInside)
                XCTAssertEqual(f.output.done, 1)
                table.refreshControl?.sendActions(for: .valueChanged)
                XCTAssertEqual(f.output.refreshes, 1)
            }
        }
    }

    func testLiveTypeWidthAndLocalePreserveNativeSearchEditorAndRowIdentity() async throws {
        try XCTSkipUnless(FWAppearance.assetManagementRestyled)
        let f = try fixture(language: "en", category: .large)
        defer { close(f) }
        let root = f.controller.rootView
        await settle(f)
        let input = root.searchTextField.textField
        await reveal(input, f)
        input.text = "USDT public search"
        XCTAssertTrue(input.becomeFirstResponder())
        if let start = input.position(from: input.beginningOfDocument, offset: 4) {
            input.selectedTextRange = input.textRange(from: start, to: start)
        }
        f.localization.selectedLocalization = "ru"
        // Production presenter independently republishes the localized model. Deliver the
        // same factory-built identities, retaining the active native editor.
        f.controller.didReceive(viewModel: try model(f, language: "ru"))
        await settle(f)
        XCTAssertTrue(input.isFirstResponder)
        XCTAssertEqual(input.text, "USDT public search")
        XCTAssertEqual(input.selectedTextRange.map { input.offset(from: input.beginningOfDocument, to: $0.start) }, 4)
        XCTAssertEqual(
            root.visibilityFilterButtons[0].1.currentTitle,
            PortfolioStrings.text("manage_assets.all", locale: Locale(identifier: "ru"))
        )
        capture(f, name: "manage-presentation-live-ru-search")
        input.resignFirstResponder()
        if #available(iOS 17.0, *) {
            f.window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        }
        f.window.frame.size.width = 640
        await settle(f)
        f.window.frame.size.width = 320
        await settle(f)
        assertFont(root.manageAssetStubLabel, .titleS)
        assertFont(root.emptyResultsLabel, .bodyM)
        for (_, button) in root.visibilityFilterButtons { assertFont(try XCTUnwrap(button.titleLabel), .labelM) }
        let index = IndexPath(row: 0, section: 0)
        root.tableView.scrollToRow(at: index, at: .middle, animated: false)
        await settle(f)
        let cell = try XCTUnwrap(root.tableView.cellForRow(at: index) as? AssetManagementTableCell)
        assertCell(cell)
        f.controller.tableView(root.tableView, didSelectRowAt: index)
        XCTAssertEqual(f.output.assets.last, f.model.list[0].cells[0].chainAsset.assetKey)
        capture(f, name: "manage-presentation-live-ru-AX5-row")
    }

    func testActualLoadingModelRendersContainedBarsAfterVisibleTextSizeChangeAndRestoresValues() async throws {
        try XCTSkipUnless(FWAppearance.assetManagementRestyled)
        let f = try fixture(language: "ja", category: .large)
        defer { close(f) }
        let table = f.controller.rootView.tableView
        var pending = f.model
        pending.list[0].cells[0].isLoadingBalance = true
        f.controller.didReceive(viewModel: pending)
        await settle(f)
        let index = IndexPath(row: 0, section: 0)
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            if #available(iOS 17.0, *) { f.window.traitOverrides.preferredContentSizeCategory = category }
            for _ in 0 ..< 3 {
                await settle(f)
                table.scrollToRow(at: index, at: .middle, animated: false)
            }
            await settle(f)
            let cell = try XCTUnwrap(table.cellForRow(at: index) as? AssetManagementTableCell)
            let skeleton = try XCTUnwrap(descendants(cell).first { $0 is SkrullableView })
            let bars = descendants(skeleton).flatMap { view in
                (view.layer.sublayers ?? []).compactMap { layer -> CGRect? in
                    guard layer is CAGradientLayer else { return nil }
                    return view.convert(layer.frame, to: cell.contentView)
                }
            }
            XCTAssertEqual(bars.count, 2)
            for bar in bars {
                XCTAssertTrue(
                    cell.contentView.bounds.insetBy(dx: -1, dy: -1).contains(bar),
                    "Rendered gradient outside content: \(bar) / \(cell.contentView.bounds)"
                )
            }
            if bars.count == 2 {
                XCTAssertFalse(bars[0].intersects(bars[1]))
                for (bar, label) in zip(bars, [cell.balanceLabel, cell.fiatBalanceLabel]) {
                    let target = label.convert(label.bounds, to: cell.contentView)
                    XCTAssertEqual(bar.midY, target.midY, accuracy: 1, "Rendered bar follows its exact amount label")
                    if category.isAccessibilityCategory {
                        XCTAssertEqual(bar.minX, target.minX, accuracy: 1, "AX values and loading bars share alignment")
                    }
                }
            }
            let metrics =
                XCTAttachment(string: "content=\(cell.contentView.bounds); skeleton=\(skeleton.frame); bars=\(bars)")
            metrics.name = "manage-loading-rendered-bars-" + category.rawValue
            metrics.lifetime = .keepAlways
            add(metrics)
            XCTAssertEqual(skeleton.bounds.size.width, cell.contentView.bounds.width, accuracy: 1)
            XCTAssertEqual(skeleton.bounds.size.height, cell.contentView.bounds.height, accuracy: 1)
            XCTAssertEqual(cell.balanceLabel.alpha, 0)
            capture(f, name: "manage-presentation-loading-ja-\(category.rawValue)")
        }
        let prior = try XCTUnwrap(table.cellForRow(at: index) as? AssetManagementTableCell)
        prior.prepareForReuse()
        prior.setNeedsLayout()
        prior.layoutIfNeeded()
        XCTAssertFalse(descendants(prior).contains { $0 is SkrullableView })
        XCTAssertEqual(prior.balanceLabel.alpha, 1)
        prior.bind(viewModel: pending.list[0].cells[0])
        prior.setNeedsLayout()
        prior.layoutIfNeeded()
        XCTAssertTrue(descendants(prior).contains { $0 is SkrullableView })
        XCTAssertEqual(prior.balanceLabel.alpha, 0)
        prior.bind(viewModel: f.model.list[0].cells[0])
        prior.layoutIfNeeded()
        XCTAssertFalse(descendants(prior).contains { $0 is SkrullableView })
        XCTAssertEqual(prior.balanceLabel.alpha, 1)
        f.controller.didReceive(viewModel: f.model)
        await settle(f)
        table.scrollToRow(at: index, at: .middle, animated: false)
        await settle(f)
        let loaded = try XCTUnwrap(table.cellForRow(at: index) as? AssetManagementTableCell)
        XCTAssertFalse(descendants(loaded).contains { $0 is SkrullableView })
        XCTAssertEqual(loaded.balanceLabel.alpha, 1)
        XCTAssertEqual(loaded.fiatBalanceLabel.alpha, 1)
        capture(f, name: "manage-presentation-loaded-ja-AX5")
    }

    func testLiveBoldTextAndWidthRestoreRolesAndKeepFullWidthAccessibilityRow() async throws {
        try XCTSkipUnless(FWAppearance.assetManagementRestyled)
        let f = try fixture(language: "ru", category: .accessibilityExtraExtraExtraLarge)
        defer { close(f) }
        let table = f.controller.rootView.tableView
        let index = IndexPath(row: 0, section: 0)
        await settle(f)
        table.scrollToRow(at: index, at: .top, animated: false)
        await settle(f)
        let regularCell = try XCTUnwrap(table.cellForRow(at: index) as? AssetManagementTableCell)
        let regularFonts = [regularCell.symbolLabel, regularCell.chainNameLabel, regularCell.preferenceLabel,
                            regularCell.balanceLabel, regularCell.fiatBalanceLabel].map { $0.font! }
        for width in [CGFloat(640), CGFloat(320)] {
            f.window.frame.size.width = width
            if #available(iOS 17.0, *) { f.window.traitOverrides.legibilityWeight = .bold }
            await settle(f)
            table.scrollToRow(at: index, at: .top, animated: false)
            await settle(f)
            let cell = try XCTUnwrap(table.cellForRow(at: index) as? AssetManagementTableCell)
            // On iOS18 a later fresh UIFont resolution can add another platform weight
            // step. Qualify the rendered Bold Text contract against the captured regular
            // fonts, not the name of a newly created font under already-bold traits.
            assertCell(cell, exactFontNames: false)
            XCTAssertEqual(cell.textContainer.frame.minX, UIConstants.bigOffset, accuracy: 1)
            XCTAssertEqual(
                cell.textContainer.frame.maxX,
                cell.contentView.bounds.width - UIConstants.bigOffset,
                accuracy: 1
            )
            XCTAssertGreaterThanOrEqual(cell.textContainer.frame.minY, cell.iconImageView.frame.maxY + 11)
            XCTAssertGreaterThanOrEqual(cell.textContainer.frame.minY, cell.switchView.frame.maxY + 10)
            let rendered = [cell.symbolLabel, cell.chainNameLabel, cell.preferenceLabel,
                            cell.balanceLabel, cell.fiatBalanceLabel]
            for (label, regular) in zip(rendered, regularFonts) {
                XCTAssertEqual(label.font.pointSize, regular.pointSize, accuracy: 0.1)
                let oldTraits = regular.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
                let newTraits = label.font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
                XCTAssertGreaterThan((newTraits?[.weight] as? NSNumber)?.doubleValue ?? 0,
                                     (oldTraits?[.weight] as? NSNumber)?.doubleValue ?? 0)
            }
            capture(f, name: "manage-presentation-live-bold-ru-AX5-\(Int(width))")
        }
        if #available(iOS 17.0, *) { f.window.traitOverrides.legibilityWeight = .regular }
        await settle(f)
        let restored = try XCTUnwrap(table.cellForRow(at: index) as? AssetManagementTableCell)
        let restoredLabels = [restored.symbolLabel, restored.chainNameLabel, restored.preferenceLabel,
                              restored.balanceLabel, restored.fiatBalanceLabel]
        for (label, regular) in zip(restoredLabels, regularFonts) {
            XCTAssertEqual(label.font.fontName, regular.fontName)
            XCTAssertEqual(label.font.pointSize, regular.pointSize, accuracy: 0.1)
        }
        assertCell(restored)
        f.controller.tableView(table, didSelectRowAt: index)
        XCTAssertEqual(f.output.assets.last, f.model.list[0].cells[0].chainAsset.assetKey)
    }

    func testCompiledRollbackKeepsLegacyPresentationAndExactActions() async throws {
        try XCTSkipIf(FWAppearance.assetManagementRestyled)
        for language in ["en", "ru", "ja"] {
            let f = try fixture(language: language, category: .large)
            defer { close(f) }
            let root = f.controller.rootView, table = root.tableView
            await settle(f)
            capture(f, name: "manage-presentation-rollback-\(language)-top")
            XCTAssertEqual(root.manageAssetStubLabel.font.fontName, UIFont.h5Title.fontName)
            await reveal(root.resetOrderButton, f)
            assertHit(root.resetOrderButton, f)
            root.resetOrderButton.sendActions(for: .touchUpInside)
            XCTAssertEqual(f.output.resets, 1)
            table.scrollToRow(at: IndexPath(row: 0, section: 0), at: .middle, animated: false)
            await settle(f)
            let cell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)) as? AssetManagementTableCell)
            XCTAssertEqual(cell.balanceLabel.font.fontName, UIFont.h5Title.fontName)
            f.controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
            XCTAssertEqual(f.output.assets.last, f.model.list[0].cells[0].chainAsset.assetKey)
            let action = try XCTUnwrap(cell.accessibilityCustomActions?.first)
            XCTAssertTrue(action.actionHandler?(action) == true)
            XCTAssertEqual(f.output.automatic.last, f.model.list[0].cells[0].chainAsset.assetKey)
            capture(f, name: "manage-presentation-rollback-\(language)-row")
        }
    }

    private struct Fixture {
        let controller: AssetManagementViewController
        let output: ManagePresentationOutput
        let window: UIWindow
        let localization: LocalizationManager
        let defaults: UserDefaults
        let suite: String
        let wallet: MetaAccountModel
        let assets: [ChainAsset]
        let model: AssetManagementViewModel
    }

    private func fixture(language: String, category: UIContentSizeCategory) throws -> Fixture {
        let localization = try XCTUnwrap(LocalizationManager(localization: language))
        let output = ManagePresentationOutput()
        let controller = AssetManagementViewController(output: output, localizationManager: localization)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        window.rootViewController = controller
        window.makeKeyAndVisible()
        let suite = "manage-presentation-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let assets = try SendNetworkFixture.assets()
            .filter { CanonicalTokenGroupCatalog.bundled.group(for: $0)?.id == "usdt" }
            .sorted { $0.chain.name < $1.chain.name }
        XCTAssertEqual(assets.count, 3)
        let wallet = AccountGenerator.generateMetaAccount().replacingAssetKeysOrder(["custom"])
        AssetVisibilityPreferenceStore.setPreference(
            .hidden,
            walletId: wallet.metaId,
            assetKey: assets[0].assetKey,
            userDefaults: defaults
        )
        AssetVisibilityPreferenceStore.setPreference(
            .shown,
            walletId: wallet.metaId,
            assetKey: assets[1].assetKey,
            userDefaults: defaults
        )
        let raw = try buildModel(assets: assets, wallet: wallet, defaults: defaults, language: language)
        controller.didReceive(viewModel: raw)
        return Fixture(
            controller: controller,
            output: output,
            window: window,
            localization: localization,
            defaults: defaults,
            suite: suite,
            wallet: wallet,
            assets: assets,
            model: raw
        )
    }

    private func model(_ f: Fixture, language: String) throws -> AssetManagementViewModel {
        try buildModel(assets: f.assets, wallet: f.wallet, defaults: f.defaults, language: language)
    }

    private func buildModel(
        assets: [ChainAsset],
        wallet: MetaAccountModel,
        defaults: UserDefaults,
        language: String
    ) throws -> AssetManagementViewModel {
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
        let factory = AssetManagementViewModelFactoryDefault(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            userDefaults: defaults
        )
        var result = factory.buildViewModel(
            chainAssets: assets,
            accountInfos: infos,
            wallet: wallet,
            locale: Locale(identifier: language),
            filter: nil,
            search: nil,
            pendingAccountInfoChainAssets: []
        )
        result.list = result.list.map { section in
            AssetManagementTableSection(
                hasView: section.hasView,
                assetImage: nil,
                assetName: section.assetName,
                assetCount: section.assetCount,
                isExpanded: true,
                cells: section.cells.map { row in
                    AssetManagementTableCellViewModel(
                        chainAsset: row.chainAsset,
                        assetImage: nil,
                        assetName: row.assetName,
                        chainName: row.chainName,
                        balance: BalanceViewModel(amount: "1,250.40", price: "$1,250.40"),
                        decimalPrice: row.decimalPrice,
                        hidden: row.hidden,
                        hasGroup: row.hasGroup,
                        isLoadingBalance: row.isLoadingBalance,
                        preference: row.preference,
                        preferenceCaption: row.preferenceCaption,
                        amount: row.amount,
                        valueRole: row.valueRole
                    )
                },
                isAllDisabled: section.isAllDisabled,
                totalBalance: section.totalBalance,
                totalFiatBalance: section.totalFiatBalance,
                rank: section.rank,
                id: section.id,
                visibilityMembers: section.visibilityMembers,
                groupVisibility: section.groupVisibility
            )
        }
        return result
    }

    private func assertCell(_ cell: AssetManagementTableCell, exactFontNames: Bool = true) {
        assertFont(cell.symbolLabel, .titleS, exactName: exactFontNames)
        assertFont(cell.chainNameLabel, .bodyS, exactName: exactFontNames)
        assertFont(cell.preferenceLabel, .bodyS, exactName: exactFontNames)
        assertFont(cell.balanceLabel, .numberL, exactName: exactFontNames)
        assertFont(cell.fiatBalanceLabel, .numberM, exactName: exactFontNames)
        assertLabelsFit(cell.contentView)
        for label in [cell.balanceLabel, cell.fiatBalanceLabel] {
            XCTAssertFalse(label.font.fontName.contains("Sora"), "Amounts must use system tabular figures")
        }
    }

    private func assertFont(_ label: UILabel, _ role: FWFontStyle, exactName: Bool = true) {
        let expected = UIFont.fw(role, compatibleWith: label.traitCollection)
        if exactName { XCTAssertEqual(label.font.fontName, expected.fontName, label.text ?? "") }
        XCTAssertEqual(label.font.pointSize, expected.pointSize, accuracy: 0.5, label.text ?? "")
    }

    private func assertLabelsFit(_ parent: UIView) {
        for label in descendants(parent).compactMap({ $0 as? UILabel })
            where !label.isHidden && label.text?.isEmpty == false
        {
            XCTAssertGreaterThan(label.bounds.width, 0, label.text ?? "")
            XCTAssertGreaterThanOrEqual(
                label.bounds.height + 1,
                label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height,
                label.text ?? ""
            )
            XCTAssertTrue(
                parent.bounds.insetBy(dx: -1, dy: -1).contains(label.convert(label.bounds, to: parent)),
                label.text ?? ""
            )
        }
    }

    private func assertRowHit(_ cell: AssetManagementTableCell, _ f: Fixture) {
        let table = f.controller.rootView.tableView
        let visible = cell.convert(cell.bounds, to: f.window)
            .intersection(table.convert(table.bounds.inset(by: table.adjustedContentInset), to: f.window))
        XCTAssertGreaterThanOrEqual(visible.height, 44)
        let point = CGPoint(x: visible.midX, y: visible.midY)
        let hit = f.window.hitTest(point, with: nil)
        XCTAssertTrue(hit === cell || hit?.isDescendant(of: cell) == true, "Visible row accepts its actual hit path")
        // UISwitch is a state indicator; the cell owns the exact-identity tap callback.
        XCTAssertFalse(cell.switchView.isUserInteractionEnabled)
    }

    private func assertHit(_ control: UIControl, _ f: Fixture) {
        XCTAssertGreaterThanOrEqual(control.bounds.height, 44)
        XCTAssertGreaterThanOrEqual(control.bounds.width, 44)
        let point = control.convert(CGPoint(x: control.bounds.midX, y: control.bounds.midY), to: f.window)
        let hit = f.window.hitTest(point, with: nil)
        XCTAssertTrue(
            hit === control || hit?.isDescendant(of: control) == true,
            "Control is covered or offscreen: \(control)"
        )
    }

    private func reveal(_ view: UIView, _ f: Fixture) async {
        let table = f.controller.rootView.tableView
        for _ in 0 ..< 8 {
            table.scrollRectToVisible(view.convert(view.bounds, to: table), animated: false)
            await settle(f)
            if table.bounds.inset(by: table.adjustedContentInset).insetBy(dx: -1, dy: -1)
                .contains(view.convert(view.bounds, to: table)) { break }
        }
    }

    private func settle(_ f: Fixture) async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        f.window.layoutIfNeeded()
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }

    private func close(_ f: Fixture) {
        f.controller.view.endEditing(true)
        f.window.isHidden = true
        f.window.rootViewController = nil
        f.defaults.removePersistentDomain(forName: f.suite)
    }

    private func capture(_ f: Fixture, name: String) {
        let view = f.controller.view!
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        })
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let metrics = descendants(view).compactMap { $0 as? UILabel }.filter { !$0.isHidden }.map { [
            "text": $0.text ?? "",
            "font": $0.font.fontName,
            "size": String(Double($0.font.pointSize)),
            "bounds": NSCoder.string(for: $0.bounds),
            "frame": NSCoder.string(for: $0.convert($0.bounds, to: view)),
        ] }
        if let data = try? JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys]) {
            let item = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            item.name = name + "-metrics"; item.lifetime = .keepAlways; add(item)
        }
    }
}

private final class ManagePresentationOutput: AssetManagementViewOutput {
    var done = 0, networks = 0, resets = 0, refreshes = 0
    var filters: [ManageAssetsFilter] = []
    var searches: [String?] = []
    var groups: [String] = [], expansions: [String] = []
    var assets: [AssetKey] = [], automatic: [AssetKey] = []
    func didLoad(view _: AssetManagementViewInput) {}
    func doneButtonDidTapped() { done += 1 }
    func searchTextDidChanged(_ text: String?) { searches.append(text) }
    func allNetworkButtonDidTapped() { networks += 1 }
    func didSelectRow(at indexPath: IndexPath, viewModel: AssetManagementViewModel) {
        assets.append(viewModel.list[indexPath.section].cells[indexPath.row].chainAsset.assetKey)
    }

    func didTap(on section: Int, viewModel: AssetManagementViewModel) { expansions.append(viewModel.list[section].id) }
    func didPullToRefresh() { refreshes += 1 }
    func didSelectVisibilityFilter(_ filter: ManageAssetsFilter) { filters.append(filter) }
    func didToggleGroup(on section: Int, viewModel: AssetManagementViewModel) {
        groups.append(viewModel.list[section].id)
    }

    func didResetToAutomatic(at indexPath: IndexPath, viewModel: AssetManagementViewModel) {
        automatic.append(viewModel.list[indexPath.section].cells[indexPath.row].chainAsset.assetKey)
    }

    func didTapResetOrder() { resets += 1 }
}
