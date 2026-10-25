import XCTest
import SSFModels
import BigInt
import SoraKeystore
@testable import fearless

final class SendNetworkSwitchTests: XCTestCase {
    @MainActor
    func testLiveBalanceListenerRejectsOldSelectionAndWrongAccount() async throws {
        let asset = try XCTUnwrap(SendNetworkFixture.assets().first { $0.chain.name == "Ethereum" })
        let wallet = AccountGenerator.generateMetaAccount()
        let account = try XCTUnwrap(wallet.fetch(for: asset.chain.accountRequest()))
        let scope = SendRequestScope()
        var deliveries: [String] = []
        let old = SendScopedAccountInfoListener(wallet: wallet, scope: scope, request: scope.snapshot()) { _, _ in deliveries.append("old") }
        old.handleAccountInfo(result: .success(nil), accountId: account.accountId, chainAsset: asset)
        scope.begin()
        let current = SendScopedAccountInfoListener(wallet: wallet, scope: scope, request: scope.begin()) { _, returnedAsset in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(returnedAsset.assetKey, asset.assetKey)
            deliveries.append("current")
        }
        old.handleAccountInfo(result: .success(nil), accountId: account.accountId, chainAsset: asset)
        current.handleAccountInfo(result: .success(nil), accountId: Data([0]), chainAsset: asset)
        current.handleAccountInfo(result: .success(nil), accountId: account.accountId, chainAsset: asset)
        let drained = expectation(description: "balance delivery")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
        XCTAssertEqual(deliveries, ["current"])
    }

    func testAdapterKeepsQueuedRecipientAndDropsQueuedDeliveryAfterReset() throws {
        let asset = try XCTUnwrap(SendNetworkFixture.assets().first { $0.chain.name == "Ethereum" })
        let wallet = AccountGenerator.generateMetaAccount()
        let account = try XCTUnwrap(wallet.fetch(for: asset.chain.accountRequest()))
        let adapter = AccountInfoSubscriptionAdapter(walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryStub(), selectedMetaAccount: wallet)
        let first = SendBalanceDeliverySpy(), second = SendBalanceDeliverySpy()
        let queue = DispatchQueue(label: "send-subscription-test")
        queue.suspend()
        adapter.subscribe(chainsAssets: [], handler: first, deliveryOn: queue, notifyJustWhenUpdated: false)
        adapter.handleAccountInfo(result: .success(nil), accountId: account.accountId, chainAsset: asset)
        adapter.subscribe(chainsAssets: [], handler: second, deliveryOn: queue, notifyJustWhenUpdated: false)
        let firstDrained = expectation(description: "original recipient delivered")
        queue.async { firstDrained.fulfill() }
        queue.resume()
        wait(for: [firstDrained], timeout: 2)
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 0)
        queue.suspend()
        adapter.handleAccountInfo(result: .success(nil), accountId: account.accountId, chainAsset: asset)
        adapter.reset()
        adapter.subscribe(chainsAssets: [], handler: first, deliveryOn: queue, notifyJustWhenUpdated: false)
        adapter.handleAccountInfo(result: .success(nil), accountId: account.accountId, chainAsset: asset)
        let resetDrained = expectation(description: "reset rejected old queue")
        queue.async { resetDrained.fulfill() }
        queue.resume()
        wait(for: [resetDrained], timeout: 2)
        XCTAssertEqual(first.count, 2)
        XCTAssertEqual(second.count, 0)
    }

    func testRequestScopeRejectsOldRequestEvenAfterSwitchingBack() {
        let scope = SendRequestScope()
        let first = scope.snapshot()
        XCTAssertTrue(scope.isCurrent(first))
        let second = scope.begin()
        XCTAssertNotEqual(first, second)
        XCTAssertFalse(scope.isCurrent(first))
        XCTAssertTrue(scope.isCurrent(second))
        let third = scope.begin()
        XCTAssertFalse(scope.isCurrent(first))
        XCTAssertFalse(scope.isCurrent(second))
        XCTAssertTrue(scope.isCurrent(third))
    }

    @MainActor
    func testFeeListenerDropsStaleSuccessAndFailureBeforeDelivery() async {
        let scope = SendRequestScope()
        var delivered = 0
        let stale = SendScopedFeeListener(scope: scope, request: scope.snapshot()) { _ in delivered += 1 }
        stale.didReceiveFee(fee: 10)
        stale.didReceiveFeeError(feeError: NSError(domain: "fixture", code: 1))
        let current = SendScopedFeeListener(scope: scope, request: scope.begin()) { _ in
            XCTAssertTrue(Thread.isMainThread)
            delivered += 1
        }
        current.didReceiveFee(fee: 20)
        current.didReceiveFeeError(feeError: NSError(domain: "fixture", code: 2))
        let drained = expectation(description: "callbacks delivered")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
        XCTAssertEqual(delivered, 2)
    }

    func testSwitchCandidatesUseApprovedIdentitiesOnly() throws {
        let assets = try SendNetworkFixture.assets()
        let source = try XCTUnwrap(assets.first { $0.chain.name == "Ethereum" && $0.asset.symbol.lowercased() == "usdt" })
        let impostor = ChainAsset(chain: source.chain, asset: AssetModel(id: "impostor", name: "Tether", symbol: "USDT", precision: 6, isUtility: false, isNative: false))
        let members = SendNetworkSelection.members(for: source, among: assets + [impostor])
        XCTAssertEqual(members.count, 3)
        XCTAssertTrue(members.allSatisfy { CanonicalTokenGroupCatalog.bundled.group(for: $0)?.id == "usdt" })
        XCTAssertFalse(members.contains { $0.assetKey == impostor.assetKey })
    }

    func testSameSymbolOnTargetNetworkNeverOverridesCuratedMember() throws {
        let assets = try SendNetworkFixture.assets()
        let members = assets.filter { CanonicalTokenGroupCatalog.bundled.group(for: $0)?.id == "usdt" }
        let source = try XCTUnwrap(members.first)
        let target = try XCTUnwrap(members.last)
        target.chain.assets.insert(AssetModel(id: "fake-usdt", name: "Tether", symbol: target.asset.symbol, precision: target.asset.precision, isUtility: false, isNative: false))
        XCTAssertEqual(SendNetworkSelection.member(for: source, on: target.chain)?.assetKey, target.assetKey)
    }

    func testUngroupedAssetAndMissingCatalogNeverSwitchByTicker() throws {
        let assets = try SendNetworkFixture.assets()
        let original = try XCTUnwrap(assets.first { $0.chain.name == "Ethereum" && $0.asset.symbol.lowercased() == "usdt" })
        let other = try XCTUnwrap(assets.first { $0.chain.name == "Polkadot AssetHub" && $0.asset.symbol.lowercased() == "usdt" })
        let empty = CanonicalTokenGroupCatalog(data: nil, testnets: .bundled)
        XCTAssertEqual(SendNetworkSelection.members(for: original, among: [original, other], catalog: empty).map(\.assetKey), [original.assetKey])
        XCTAssertNil(SendNetworkSelection.member(for: original, on: other.chain, catalog: empty))
        XCTAssertEqual(SendNetworkSelection.member(for: original, on: original.chain, catalog: empty)?.assetKey, original.assetKey)
    }

    func testNoMemberOnTargetReturnsNoSelection() throws {
        let assets = try SendNetworkFixture.assets()
        let source = try XCTUnwrap(assets.first { $0.chain.name == "Ethereum" && $0.asset.symbol.lowercased() == "usdt" })
        let kusama = try XCTUnwrap(assets.first { $0.chain.name == "Kusama" })
        XCTAssertNil(SendNetworkSelection.member(for: source, on: kusama.chain))
    }
}

private final class SendBalanceDeliverySpy: AccountInfoSubscriptionAdapterHandler {
    var count = 0
    func handleAccountInfo(result _: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) { count += 1 }
}

enum SendNetworkFixture {
    static func assets() throws -> [ChainAsset] {
        let url = try XCTUnwrap(Bundle(for: SendNetworkSwitchTests.self).url(forResource: "chains_v13_20261009", withExtension: "json", subdirectory: "Registry"))
        let data = try Data(contentsOf: url)
        let chains = try JSONDecoder().decode([ChainModel].self, from: ChainSyncService.coerceChainsPayloadForCompatibility(data))
        return chains.flatMap(\.chainAssets) + UniversalWalletRegistry.appOwnedProductionChains.flatMap(\.chainAssets)
    }
}

@testable import fearless
import SoraFoundation
import SoraUI
import UIKit

@MainActor
final class SendPresentationTests: XCTestCase {
    private let languages = ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"]
    private let recipient = "0x2222222222222222222222222222222222222222"
    private let expectedSendAll: [String: String] = [
        "en": "Send all tokens and allow this network account to close",
        "ru": "Отправить все токены и разрешить закрытие аккаунта в этой сети",
        "ja": "すべてのトークンを送信し、このネットワーク上のアカウントの削除を許可する",
        "zh-Hans": "发送所有代币，并允许关闭此网络上的账户",
        "id": "Kirim semua token dan izinkan penutupan akun di jaringan ini",
        "pt-PT": "Enviar todos os tokens e permitir o encerramento da conta nesta rede",
        "tr": "Bu ağdaki tüm tokenları gönder ve hesabın kapatılmasına izin ver",
        "vi": "Gửi tất cả token và cho phép đóng tài khoản trên mạng này",
    ]

    func testActualSendControlsAndMoneyLabelsAcrossLocalesAndTextSizes() async throws {
        try XCTSkipUnless(FWAppearance.sendPresentationRestyled)
        for language in languages {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let f = try sendFixture(language: language, category: category)
                defer { close(f.window) }
                await settle(f.window)
                let root = f.controller.rootView
                let name = "send-presentation-\(language)-\(category.rawValue)"
                capture(f.controller, name: name + "-top")
                assertFont(root.navigationTitleLabel, .titleM, language)
                assertLabelsFit(root.navigationTitleLabel)
                assertFont(root.amountView.textField, .displayL, language)
                assertFont(root.searchView.textField, .monoM, language)
                for (label, view) in [("recipient", root.searchView as UIView), ("amount", root.amountView),
                                      ("network", root.selectNetworkView), ("fee", root.feeView), ("tip", root.tipView)]
                {
                    await reveal(view, scroll: root.contentView.scrollView, window: f.window)
                    assertLabelsFit(view)
                    capture(f.controller, name: name + "-" + label)
                }
                XCTAssertEqual(root.searchView.textField.text, recipient)
                XCTAssertEqual(root.selectNetworkView.subtitle, "Ethereum · ERC-20")
                XCTAssertEqual(root.amountView.inputFieldText, f.input.displayAmount)
                await reveal(root.sendAllContainerView, scroll: root.contentView.scrollView, window: f.window)
                assertLabelsFit(root.sendAllContainerView)
                XCTAssertEqual(root.sendAllLabel.text, expectedSendAll[language])
                capture(f.controller, name: name + "-send-all")
                assertHit(root.sendAllSwitch, window: f.window)
                root.sendAllSwitch.isOn = true
                root.sendAllSwitch.sendActions(for: .valueChanged)
                XCTAssertEqual(f.output.all, [true])
                for (label, button) in [("scan", root.scanButton), ("history", root.historyButton), ("continue", root.actionButton)] {
                    await reveal(button, scroll: root.contentView.scrollView, window: f.window)
                    assertHit(button, window: f.window)
                    button.sendActions(for: .touchUpInside)
                    capture(f.controller, name: name + "-" + label)
                }
                XCTAssertEqual(f.output.scan, 1)
                XCTAssertEqual(f.output.history, 1)
                XCTAssertEqual(f.output.proceed, 1)
                assertHit(root.navigationBar.backButton, window: f.window)
                root.navigationBar.backButton.sendActions(for: .touchUpInside)
                XCTAssertEqual(f.output.back, 1)
            }
        }
    }

    func testActualConfirmFullRecipientAmountsAndCallbacksAcrossLocalesAndTextSizes() async throws {
        try XCTSkipUnless(FWAppearance.sendPresentationRestyled)
        for language in languages {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let f = try confirmFixture(language: language, category: category)
                defer { close(f.window) }
                await settle(f.window)
                let root = f.controller.rootView
                let name = "send-confirm-presentation-\(language)-\(category.rawValue)"
                capture(f.controller, name: name + "-top")
                assertFont(root.amountLabel, .displayL, language)
                assertLabelsFit(root.navigationBar.titleLabel)
                assertFont(root.networkView.nameLabel, .titleS, language)
                XCTAssertTrue(root.infoViewsStackView.arrangedSubviews.first === root.networkView)
                XCTAssertEqual(root.receiverView.valueTop.text, recipient)
                XCTAssertEqual(root.receiverView.valueTop.numberOfLines, 0, "Full recipient must wrap for review")
                for (label, view) in [("network", root.networkView as UIView), ("sender", root.senderView),
                                      ("receiver", root.receiverView), ("amount", root.amountView),
                                      ("fee", root.feeView), ("tip", root.tipView)]
                {
                    await reveal(view, scroll: root.contentView.scrollView, window: f.window)
                    assertLabelsFit(view)
                    capture(f.controller, name: name + "-" + label)
                }
                XCTAssertFalse(root.networkView.testnetLabel.isHidden)
                XCTAssertTrue(root.networkView.accessibilityLabel?.contains("Ethereum Sepolia") == true)
                XCTAssertEqual(root.feeView.valueTop.text, "0.00123456789 ETH")
                await reveal(root.confirmButton, scroll: root.contentView.scrollView, window: f.window)
                assertHit(root.confirmButton, window: f.window)
                assertLabelsFit(root.confirmButton)
                capture(f.controller, name: name + "-confirm")
                root.confirmButton.sendActions(for: .touchUpInside)
                XCTAssertEqual(f.output.confirm, 1)
                root.navigationBar.backButton.sendActions(for: .touchUpInside)
                XCTAssertEqual(f.output.back, 1)
            }
        }
    }

    func testLiveLocaleAndTextSizeRetainNativeAmountEditorAndConfirmValues() async throws {
        try XCTSkipUnless(FWAppearance.sendPresentationRestyled)
        let send = try sendFixture(language: "en", category: .large)
        defer { close(send.window) }
        await settle(send.window)
        let root = send.controller.rootView
        let input = root.amountView.textField
        await reveal(root.amountView, scroll: root.contentView.scrollView, window: send.window)
        XCTAssertTrue(input.becomeFirstResponder())
        if let position = input.position(from: input.beginningOfDocument, offset: 4) {
            input.selectedTextRange = input.textRange(from: position, to: position)
        }
        let before = input.text
        send.localization.selectedLocalization = "ja"
        await settle(send.window)
        XCTAssertTrue(input.isFirstResponder)
        XCTAssertEqual(input.text, before)
        XCTAssertEqual(input.selectedTextRange.map { input.offset(from: input.beginningOfDocument, to: $0.start) }, 4)
        XCTAssertEqual(root.navigationTitleLabel.text, R.string.localizable.sendFundTitle(preferredLanguages: ["ja"]))
        capture(send.controller, name: "send-presentation-live-ja-editor")
        input.resignFirstResponder()
        if #available(iOS 17.0, *) { send.window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
        await settle(send.window)
        assertFont(root.navigationTitleLabel, .titleM, "ja")
        assertFont(input, .displayL, "ja")
        assertLabelsFit(root.navigationTitleLabel)
        XCTAssertTrue(root.navigationTitleLabel.superview === root.contentView.stackView)
        capture(send.controller, name: "send-presentation-live-ja-AX5")
        if #available(iOS 17.0, *) { send.window.traitOverrides.preferredContentSizeCategory = .large }
        await settle(send.window)
        XCTAssertTrue(root.navigationTitleLabel.superview === root.navigationBar.centerStackView)
        assertLabelsFit(root.navigationTitleLabel)

        let confirm = try confirmFixture(language: "en", category: .large)
        defer { close(confirm.window) }
        await settle(confirm.window)
        confirm.localization.selectedLocalization = "ja"
        if #available(iOS 17.0, *) { confirm.window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
        await settle(confirm.window)
        XCTAssertEqual(
            confirm.controller.rootView.receiverView.titleLabel.text,
            R.string.localizable.walletSendReceiverTitle(preferredLanguages: ["ja"])
        )
        XCTAssertEqual(confirm.controller.rootView.receiverView.valueTop.text, recipient)
        assertFont(confirm.controller.rootView.amountLabel, .displayL, "ja")
        await reveal(
            confirm.controller.rootView.receiverView,
            scroll: confirm.controller.rootView.contentView.scrollView,
            window: confirm.window
        )
        assertLabelsFit(confirm.controller.rootView.navigationBar.titleLabel)
        XCTAssertTrue(confirm.controller.rootView.navigationBar.titleLabel.superview === confirm.controller.rootView.contentView.stackView)
        capture(confirm.controller, name: "send-confirm-presentation-live-ja-AX5")
        confirm.localization.selectedLocalization = "ru"
        await settle(confirm.window)
        assertLabelsFit(confirm.controller.rootView.navigationBar.titleLabel)
        XCTAssertTrue(confirm.controller.rootView.navigationBar.titleLabel.superview === confirm.controller.rootView.contentView.stackView)
        if #available(iOS 17.0, *) { confirm.window.traitOverrides.preferredContentSizeCategory = .large }
        await settle(confirm.window)
        XCTAssertTrue(confirm.controller.rootView.navigationBar.titleLabel.superview === confirm.controller.rootView.contentView.stackView)
        assertLabelsFit(confirm.controller.rootView.navigationBar.titleLabel)
        confirm.window.frame.size.width = 568
        await settle(confirm.window)
        XCTAssertTrue(confirm.controller.rootView.navigationBar.titleLabel.superview === confirm.controller.rootView.navigationBar.centerStackView)
        assertLabelsFit(confirm.controller.rootView.navigationBar.titleLabel)
        confirm.window.frame.size.width = 320
        await settle(confirm.window)
        XCTAssertTrue(confirm.controller.rootView.navigationBar.titleLabel.superview === confirm.controller.rootView.contentView.stackView)
        assertLabelsFit(confirm.controller.rootView.navigationBar.titleLabel)
    }

    func testSwitchReservedRegionContainsMinimumTouchTargetAcrossLocalesAndTextSizes() async throws {
        try XCTSkipUnless(FWAppearance.sendPresentationRestyled)
        for language in languages {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let f = try sendFixture(language: language, category: category)
                defer { close(f.window) }
                await settle(f.window)
                await reveal(f.controller.rootView.sendAllContainerView, scroll: f.controller.rootView.contentView.scrollView, window: f.window)
                assertHit(f.controller.rootView.sendAllSwitch, window: f.window)
            }
        }
    }

    func testRecipientClearPasteAndExistingFocusPolicyRemainReachable() async throws {
        try XCTSkipUnless(FWAppearance.sendPresentationRestyled)
        for language in languages {
            let f = try sendFixture(language: language, category: .accessibilityExtraExtraExtraLarge)
            defer { close(f.window) }
            let root = f.controller.rootView
            await settle(f.window)
            await reveal(root.searchView, scroll: root.contentView.scrollView, window: f.window)
            let field = root.searchView.textField
            _ = field.becomeFirstResponder()
            await settle(f.window)
            XCTAssertFalse(field.isFirstResponder, "Preserve the existing recipient focus policy")
            XCTAssertEqual(field.text, recipient)
            let clear = try recipientButton("clean", in: root.searchView)
            await reveal(clear, scroll: root.contentView.scrollView, window: f.window)
            assertHit(clear, window: f.window)
            clear.sendActions(for: .touchUpInside)
            await settle(f.window)
            XCTAssertTrue(field.text?.isEmpty != false)
            XCTAssertEqual(
                root.searchView.sendPlaceholderLabel.text,
                R.string.localizable.searchTextfieldPlaceholder(preferredLanguages: [language])
            )
            assertFont(root.searchView.sendPlaceholderLabel, .bodyM, language)
            XCTAssertFalse(root.searchView.sendPlaceholderLabel.isHidden)
            XCTAssertNil(field.attributedPlaceholder)
            XCTAssertEqual(f.output.search, [""])
            let paste = try recipientButton("pasteTapped", in: root.searchView)
            await reveal(paste, scroll: root.contentView.scrollView, window: f.window)
            let prompt = root.searchView.sendPlaceholderLabel
            let diagnostic: [String: Any] = [
                "locale": language,
                "intrinsic": NSCoder.string(for: prompt.intrinsicContentSize),
                "fitting": NSCoder.string(for: prompt.sizeThatFits(CGSize(width: prompt.bounds.width, height: .greatestFiniteMagnitude))),
                "preferredMaxLayoutWidth": prompt.preferredMaxLayoutWidth,
                "compression": prompt.contentCompressionResistancePriority(for: .vertical).rawValue,
                "constraints": prompt.constraintsAffectingLayout(for: .vertical).map { $0.description },
                "parentConstraints": prompt.superview?.constraints.map { $0.description } ?? [],
            ]
            let diagnosticAttachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: diagnostic, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
            diagnosticAttachment.name = "recipient-prompt-constraints-\(language)"
            diagnosticAttachment.lifetime = .keepAlways
            add(diagnosticAttachment)
            assertLabelsFit(root.searchView)
            assertHit(paste, window: f.window)
            paste.sendActions(for: .touchUpInside)
            XCTAssertEqual(f.output.paste, 1)
            capture(f.controller, name: "send-recipient-paste-\(language)-AX5")
            await reveal(prompt, scroll: root.contentView.scrollView, window: f.window)
            let viewport = root.contentView.scrollView.convert(root.contentView.scrollView.bounds, to: f.window)
            XCTAssertTrue(viewport.insetBy(dx: -1, dy: -1).contains(prompt.convert(prompt.bounds, to: f.window)))
            capture(f.controller, name: "send-recipient-prompt-\(language)-AX5")
            f.window.frame.size.width = 568
            await settle(f.window)
            assertLabelsFit(root.searchView)
            if #available(iOS 17.0, *) { f.window.traitOverrides.preferredContentSizeCategory = .large }
            await settle(f.window)
            assertFont(root.searchView.sendPlaceholderLabel, .bodyM, language)
            assertLabelsFit(root.searchView)
            f.window.frame.size.width = 320
            if #available(iOS 17.0, *) { f.window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
            await settle(f.window)
            assertLabelsFit(root.searchView)
            f.controller.didReceive(viewModel: RecipientViewModel(address: recipient, icon: nil, isValid: true, canEditing: true))
            await settle(f.window)
            XCTAssertTrue(root.searchView.sendPlaceholderLabel.isHidden)
            XCTAssertEqual(field.text, recipient)
        }
    }

    private func recipientButton(_ action: String, in root: UIView) throws -> UIControl {
        try XCTUnwrap(descendants(root).compactMap { $0 as? UIControl }.first { button in
            button.allTargets.contains { button.actions(forTarget: $0.base, forControlEvent: .touchUpInside)?.contains(action) == true }
        })
    }

    func testActualKeyboardNotificationsRetainEditorAndReachContinue() async throws {
        try XCTSkipUnless(FWAppearance.sendPresentationRestyled)
        let f = try sendFixture(language: "ja", category: .accessibilityExtraExtraExtraLarge)
        defer { close(f.window) }
        let root = f.controller.rootView
        await settle(f.window)
        let field = root.amountView.textField
        XCTAssertTrue(field.becomeFirstResponder())
        try? await Task.sleep(nanoseconds: 500_000_000)
        let value = field.text
        let keyboard = CGRect(x: 0, y: 340.5, width: 320, height: 227.5)
        let info: [AnyHashable: Any] = [
            UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: keyboard),
            UIResponder.keyboardAnimationDurationUserInfoKey: 0,
            UIResponder.keyboardAnimationCurveUserInfoKey: 0,
        ]
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil, userInfo: info)
        NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil, userInfo: info)
        await settle(f.window)
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertEqual(field.text, value)
        XCTAssertLessThanOrEqual(root.contentView.convert(root.contentView.bounds, to: f.window).maxY, keyboard.minY + 1)
        capture(f.controller, name: "send-presentation-keyboard-editor-ja-AX5")
        await reveal(root.actionButton, scroll: root.contentView.scrollView, window: f.window)
        XCTAssertTrue(field.isFirstResponder)
        assertHit(root.actionButton, window: f.window)
        XCTAssertLessThanOrEqual(root.actionButton.convert(root.actionButton.bounds, to: f.window).maxY, keyboard.minY + 1)
        capture(f.controller, name: "send-presentation-keyboard-continue-ja-AX5")
        field.resignFirstResponder()
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil, userInfo: info)
        await settle(f.window)
    }

    func testLoadingTransitionsKeepButtonsAndReviewSkeletonContained() async throws {
        try XCTSkipUnless(FWAppearance.sendPresentationRestyled)
        let send = try sendFixture(language: "ru", category: .accessibilityExtraExtraExtraLarge)
        defer { close(send.window) }
        await settle(send.window)
        let button = send.controller.rootView.actionButton
        send.controller.didStartFeeCalculation()
        XCTAssertTrue(button.wrappingLabel?.isHidden == true)
        XCTAssertFalse(button.accessibilityActivate())
        send.controller.didStopFeeCalculation()
        XCTAssertFalse(button.wrappingLabel?.isHidden == true)
        XCTAssertTrue(button.isEnabled)
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            if #available(iOS 17.0, *) { send.window.traitOverrides.preferredContentSizeCategory = category }
            let fee = send.controller.rootView.feeView
            for (step, pending) in [true, false, true].enumerated() {
                send.controller.didReceive(feeViewModel: pending ? nil : BalanceViewModel(amount: "0.00123456789 ETH", price: "$3.45"))
                try? await Task.sleep(nanoseconds: 300_000_000)
                await reveal(fee, scroll: send.controller.rootView.contentView.scrollView, window: send.window)
                XCTAssertEqual(fee.activityIndicator.isAnimating, pending)
                XCTAssertEqual(fee.fiatLabel == nil, pending)
                assertLabelsFit(fee)
                if pending {
                    XCTAssertTrue(fee.bounds.contains(fee.activityIndicator.frame))
                    XCTAssertGreaterThanOrEqual(fee.activityIndicator.frame.minY, fee.titleLabel.frame.maxY)
                }
                capture(send.controller, name: "send-fee-\(category.rawValue)-step-\(step)-pending-\(pending)")
            }
        }
        let confirm = try confirmFixture(language: "ru", category: .large, pendingFees: true)
        defer { close(confirm.window) }
        let root = confirm.controller.rootView
        await settle(confirm.window)
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            if #available(iOS 17.0, *) { confirm.window.traitOverrides.preferredContentSizeCategory = category }
            for state in ["empty", "populated", "empty-reuse"] {
                let pending = state != "populated"
                confirm.controller.didReceive(state: .loaded(confirmModel(pendingFees: pending)))
                for (name, view) in [("fee", root.feeView), ("tip", root.tipView)] {
                    await reveal(view, scroll: root.contentView.scrollView, window: confirm.window)
                    if pending {
                        try assertRenderedSkeleton(view)
                    } else {
                        XCTAssertEqual(view.valueTop.alpha, 1)
                        XCTAssertFalse(descendants(view).contains { $0 is SkrullableView })
                        assertLabelsFit(view)
                    }
                    capture(confirm.controller, name: "send-confirm-loading-ru-\(category.rawValue)-\(state)-\(name)")
                }
            }
            confirm.controller.didReceive(state: .loaded(confirmModel(pendingFees: true, tipRequired: false)))
            await settle(confirm.window)
            XCTAssertTrue(root.tipView.isHidden)
            XCTAssertEqual(root.tipView.valueTop.alpha, 1, "A hidden tip must leave loading state")
            XCTAssertFalse(descendants(root.tipView).contains { $0 is SkrullableView }, "Hidden tip overlay must be removed")
            confirm.controller.didReceive(state: .loaded(confirmModel()))
            await settle(confirm.window)
        }
        confirm.controller.didReceive(isLoading: true)
        XCTAssertFalse(root.confirmButton.accessibilityActivate())
        confirm.controller.didReceive(isLoading: false)
        await reveal(root.confirmButton, scroll: root.contentView.scrollView, window: confirm.window)
        assertHit(root.confirmButton, window: confirm.window)
        root.confirmButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(confirm.output.confirm, 1)
    }

    func testCompiledLegacySendAndConfirmRoutes() async throws {
        try XCTSkipIf(FWAppearance.sendPresentationRestyled)
        for language in languages {
            let send = try sendFixture(language: language, category: .large)
            await settle(send.window)
            capture(send.controller, name: "send-presentation-rollback-\(language)-normal")
            XCTAssertEqual(send.controller.rootView.searchView.textField.text, recipient)
            send.controller.rootView.actionButton.sendActions(for: .touchUpInside)
            XCTAssertEqual(send.output.proceed, 1)
            close(send.window)
            let confirm = try confirmFixture(language: language, category: .large)
            await settle(confirm.window)
            capture(confirm.controller, name: "send-confirm-presentation-rollback-\(language)-normal")
            XCTAssertEqual(confirm.controller.rootView.receiverView.valueTop.text, recipient)
            confirm.controller.rootView.confirmButton.sendActions(for: .touchUpInside)
            XCTAssertEqual(confirm.output.confirm, 1)
            close(confirm.window)
        }
    }

    func testUnfocusedSendAmountIsFullyReadableAtNormalSizeAcrossLocales() async throws {
        try XCTSkipUnless(FWAppearance.sendPresentationRestyled)
        for language in languages {
            let f = try sendFixture(language: language, category: .large)
            defer { close(f.window) }
            await reveal(f.controller.rootView.amountView, scroll: f.controller.rootView.contentView.scrollView, window: f.window)
            XCTAssertFalse(f.controller.rootView.amountView.textField.isFirstResponder)
            assertFullAmountVisible(f.controller.rootView.amountView, expected: "1234.5678")
            capture(f.controller, name: "send-full-amount-normal-\(language)")
        }
    }

    func testUnfocusedSendAmountIsFullyReadableAtLargestTextSizeAcrossLocales() async throws {
        try XCTSkipUnless(FWAppearance.sendPresentationRestyled)
        for language in languages {
            let f = try sendFixture(language: language, category: .accessibilityExtraExtraExtraLarge)
            defer { close(f.window) }
            await reveal(f.controller.rootView.amountView, scroll: f.controller.rootView.contentView.scrollView, window: f.window)
            XCTAssertFalse(f.controller.rootView.amountView.textField.isFirstResponder)
            assertFullAmountVisible(f.controller.rootView.amountView, expected: "1234.5678")
            capture(f.controller, name: "send-full-amount-AX5-\(language)")
        }
    }

    func testNativeAmountEditingEndsWithCompleteCurrentValueAtLargestTextSize() async throws {
        try XCTSkipUnless(FWAppearance.sendPresentationRestyled)
        let f = try sendFixture(language: "en", category: .accessibilityExtraExtraExtraLarge)
        defer { close(f.window) }
        let amount = f.controller.rootView.amountView
        let field = amount.textField
        await reveal(amount, scroll: f.controller.rootView.contentView.scrollView, window: f.window)
        XCTAssertTrue(field.becomeFirstResponder())
        XCTAssertTrue(field.isFirstResponder)
        let first = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 1))
        field.selectedTextRange = field.textRange(from: field.beginningOfDocument, to: first)
        let allowsNativeMutation = f.controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 1), replacementString: "9")
        XCTAssertFalse(allowsNativeMutation, "The production delegate applies the model change and rejects duplicate native mutation")
        XCTAssertEqual(field.text, "9234.5678")
        XCTAssertEqual(f.input.displayAmount, "9234.5678")
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertTrue(field.delegate === f.controller)
        field.resignFirstResponder()
        await reveal(amount, scroll: f.controller.rootView.contentView.scrollView, window: f.window)
        XCTAssertTrue(field === amount.textField)
        XCTAssertFalse(field.isFirstResponder)
        assertFullAmountVisible(amount, expected: "9234.5678")
        capture(f.controller, name: "send-full-amount-native-edit-ended-AX5")
    }

    func testAmountReadoutTracksModelReplacementAndLiveTextSizeWithoutChangingValue() async throws {
        try XCTSkipUnless(FWAppearance.sendPresentationRestyled)
        let f = try sendFixture(language: "en", category: .large)
        defer { close(f.window) }
        let amount = f.controller.rootView.amountView
        let field = amount.textField
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 8
        formatter.usesGroupingSeparator = false
        let input = AmountInputViewModel(symbol: "USDT", amount: Decimal(string: "9876.54321"), formatter: formatter, inputLocale: Locale(identifier: "en"), precision: 8)
        f.controller.didReceive(amountInputViewModel: input)
        f.localization.selectedLocalization = "ja"
        if #available(iOS 17.0, *) { f.window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
        await reveal(amount, scroll: f.controller.rootView.contentView.scrollView, window: f.window)
        XCTAssertTrue(field === amount.textField)
        XCTAssertEqual(field.text, "9876.54321")
        XCTAssertEqual(input.decimalAmount, Decimal(string: "9876.54321"))
        assertFullAmountVisible(amount, expected: "9876.54321")
        capture(f.controller, name: "send-full-amount-replacement-live-ja-AX5")
        input.didUpdateAmount(to: 0)
        await reveal(amount, scroll: f.controller.rootView.contentView.scrollView, window: f.window)
        XCTAssertEqual(field.text, "0")
        assertFullAmountVisible(amount, expected: "0")
        capture(f.controller, name: "send-full-amount-replacement-zero-AX5")
    }

    func testFullAmountReadoutYieldsToNativeEditorAndKeepsEmptyPlaceholderSeparate() async throws {
        try XCTSkipUnless(FWAppearance.sendPresentationRestyled)
        let f = try sendFixture(language: "en", category: .accessibilityExtraExtraExtraLarge)
        defer { close(f.window) }
        let amount = f.controller.rootView.amountView
        let field = amount.textField
        await reveal(amount, scroll: f.controller.rootView.contentView.scrollView, window: f.window)
        assertFullAmountVisible(amount, expected: "1234.5678")
        let font = field.font
        XCTAssertTrue(field.becomeFirstResponder())
        await settle(f.window)
        XCTAssertGreaterThan(field.textColor?.cgColor.alpha ?? 0, 0)
        let nativeAccessibilityElement = field.isAccessibilityElement
        let nativeAccessibilityTraits = field.accessibilityTraits
        XCTAssertFalse(descendants(amount).compactMap { $0 as? UILabel }.contains {
            !$0.isDescendant(of: field) && isEffectivelyVisible($0) && $0.text == "1234.5678"
        })
        XCTAssertFalse(f.controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 1), replacementString: "9"))
        XCTAssertEqual(field.text, "9234.5678")
        XCTAssertEqual(f.input.displayAmount, "9234.5678")
        XCTAssertEqual(field.isAccessibilityElement, nativeAccessibilityElement)
        XCTAssertEqual(field.accessibilityTraits, nativeAccessibilityTraits)
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertTrue(field.delegate === f.controller)
        XCTAssertEqual(field.font, font)
        capture(f.controller, name: "send-full-amount-visible-native-editor-AX5")
        field.resignFirstResponder()
        await reveal(amount, scroll: f.controller.rootView.contentView.scrollView, window: f.window)
        assertFullAmountVisible(amount, expected: "9234.5678")
        let visibleReadout = try XCTUnwrap(descendants(amount).compactMap { $0 as? UILabel }.first {
            !$0.isDescendant(of: field) && isEffectivelyVisible($0) && $0.text == "9234.5678"
        })
        XCTAssertFalse(visibleReadout.isAccessibilityElement)
        XCTAssertFalse(visibleReadout.isUserInteractionEnabled)
        amount.inputFieldText = ""
        await reveal(amount, scroll: f.controller.rootView.contentView.scrollView, window: f.window)
        XCTAssertEqual(field.text, "", "A visible zero placeholder must not change the input value")
        XCTAssertEqual(visibleReadout.text, "0")
        XCTAssertTrue(isEffectivelyVisible(visibleReadout))
        XCTAssertEqual(field.font, font)
        capture(f.controller, name: "send-full-amount-empty-placeholder-AX5")
    }

    func testUnconfiguredLegacyAndSwapAmountViewsKeepNativeTextVisible() {
        for type in [SelectableAmountInputViewType.send, .swapSend, .swapReceive] {
            let view = SelectableAmountInputView(type: type)
            let field = view.textField
            let font = field.font
            view.inputFieldText = "1234.5678"
            for event in [UIControl.Event.editingDidBegin, .editingChanged, .editingDidEnd] {
                field.sendActions(for: event)
                XCTAssertEqual(field.text, "1234.5678")
                XCTAssertEqual(field.font, font)
                XCTAssertGreaterThan(field.textColor?.cgColor.alpha ?? 0, 0)
                XCTAssertFalse(descendants(view).compactMap { $0 as? UILabel }.contains {
                    !$0.isDescendant(of: field) && !$0.isHidden && $0.text == "1234.5678"
                })
            }
        }
    }

    private func assertFullAmountVisible(_ view: SelectableAmountInputView, expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = view.textField
        XCTAssertEqual(field.text, expected, file: file, line: line)
        XCTAssertFalse(field.isFirstResponder, file: file, line: line)
        let neededWidth = (expected as NSString).size(withAttributes: [.font: field.font!]).width
        let availableWidth = field.textRect(forBounds: field.bounds).width
        let editorShowsFullValue = isEntirelyVisible(field) && (field.textColor?.cgColor.alpha ?? 0) > 0 && neededWidth <= availableWidth + 1
        let fullLabels = descendants(view).compactMap { $0 as? UILabel }.filter { label in
            guard !label.isDescendant(of: field), isEntirelyVisible(label),
                  (label.textColor?.cgColor.alpha ?? 0) > 0, label.text == expected,
                  view.bounds.insetBy(dx: -1, dy: -1).contains(label.convert(label.bounds, to: view)) else { return false }
            let needed = label.sizeThatFits(CGSize(width: label.numberOfLines == 1 ? .greatestFiniteMagnitude : label.bounds.width, height: .greatestFiniteMagnitude))
            return needed.height <= label.bounds.height + 1 && (label.numberOfLines != 1 || needed.width <= label.bounds.width + 1)
        }
        XCTAssertTrue(editorShowsFullValue || !fullLabels.isEmpty, "Unfocused amount must render every digit without ellipsis; native text needs \(neededWidth)pt but has \(availableWidth)pt, complete visible labels=\(fullLabels.count)", file: file, line: line)
    }

    private func isEntirelyVisible(_ view: UIView) -> Bool {
        guard isEffectivelyVisible(view), let window = view.window,
              window.bounds.insetBy(dx: -1, dy: -1).contains(view.convert(view.bounds, to: window)) else { return false }
        var ancestor = view.superview
        while let parent = ancestor {
            if parent.clipsToBounds, !parent.bounds.insetBy(dx: -1, dy: -1).contains(view.convert(view.bounds, to: parent)) {
                return false
            }
            ancestor = parent.superview
        }
        return true
    }

    private struct SendFixture {
        let controller: SendViewController
        let output: SendPresentationOutput
        let localization: LocalizationManager
        let window: UIWindow
        let input: AmountInputViewModel
    }

    private struct ConfirmFixture {
        let controller: WalletSendConfirmViewController
        let output: ConfirmPresentationOutput
        let localization: LocalizationManager
        let window: UIWindow
    }

    private func sendFixture(language: String, category: UIContentSizeCategory) throws -> SendFixture {
        let localization = try XCTUnwrap(LocalizationManager(localization: language))
        let output = SendPresentationOutput()
        let controller = SendViewController(initialData: .address(recipient), output: output, localizationManager: localization)
        let window = try host(controller, category: category)
        controller.didReceive(assetBalanceViewModel: AssetBalanceViewModel(
            symbol: "USDT", balance: "123,456.789012", fiatBalance: "$123,456.78", price: "$1.00", iconViewModel: nil, selectable: true
        ))
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.usesGroupingSeparator = false
        let input = AmountInputViewModel(symbol: "USDT", amount: Decimal(string: "1234.5678"), formatter: formatter, inputLocale: Locale(identifier: "en"), precision: 8)
        controller.didReceive(amountInputViewModel: input)
        controller.didReceive(viewModel: RecipientViewModel(address: recipient, icon: nil, isValid: true, canEditing: true))
        controller.didReceive(selectNetworkViewModel: SelectNetworkViewModel(chainName: "Ethereum · ERC-20", iconViewModel: nil))
        controller.didReceive(feeViewModel: BalanceViewModel(amount: "0.00123456789 ETH", price: "$3.45"))
        controller.didReceive(tipViewModel: TipViewModel(balanceViewModel: BalanceViewModel(amount: "0.00012345678 ETH", price: "$0.34"), tipRequired: true))
        controller.switchEnableSendAllVisibility(isVisible: true)
        controller.setHistoryButton(isVisible: true)
        controller.didStopFeeCalculation()
        return SendFixture(controller: controller, output: output, localization: localization, window: window, input: input)
    }

    private func confirmFixture(language: String, category: UIContentSizeCategory, pendingFees: Bool = false) throws -> ConfirmFixture {
        let localization = try XCTUnwrap(LocalizationManager(localization: language))
        let output = ConfirmPresentationOutput()
        let controller = WalletSendConfirmViewController(presenter: output, localizationManager: localization)
        let window = try host(controller, category: category)
        controller.didReceive(state: .loaded(confirmModel(pendingFees: pendingFees)))
        controller.didReceive(isLoading: false)
        return ConfirmFixture(controller: controller, output: output, localization: localization, window: window)
    }

    private func confirmModel(pendingFees: Bool = false, tipRequired: Bool = true) -> WalletSendConfirmViewModel {
        WalletSendConfirmViewModel(
            networkName: "Ethereum Sepolia · ERC-20", networkIsTestnet: true, networkIcon: nil,
            amountAttributedString: NSAttributedString(string: "1,234,567.890123 USDT"), amountString: "1,234,567.890123 USDT",
            senderNameString: "Public long wallet name", senderAddressString: "0x1111111111111111111111111111111111111111",
            receiverAddressString: recipient, priceString: "$1,234,567.89",
            feeAmountString: pendingFees ? "" : "0.00123456789 ETH", feePriceString: pendingFees ? "" : "$3.45",
            tipRequired: tipRequired, tipAmountString: pendingFees ? "" : "0.00012345678 ETH",
            tipPriceString: pendingFees ? "" : "$0.34", showWarning: false,
            symbolViewModel: SymbolViewModel(symbolViewModel: nil, shadowColor: nil)
        )
    }

    private func assertRenderedSkeleton(_ view: TitleMultiValueView) throws {
        let overlay = try XCTUnwrap(view.subviews.first { $0 is SkrullableView })
        XCTAssertEqual(view.subviews.filter { $0 is SkrullableView }.count, 1)
        XCTAssertTrue(view.bounds.insetBy(dx: -1, dy: -1).contains(overlay.frame))
        let labels = [view.valueTop, view.valueBottom].filter { !$0.isHidden }
        let bars = descendants(overlay).flatMap { item in
            (item.layer.sublayers ?? []).compactMap { layer -> CGRect? in
                guard layer is CAGradientLayer else { return nil }
                return item.convert(layer.frame, to: view)
            }
        }.sorted { $0.minY < $1.minY }
        XCTAssertEqual(bars.count, labels.count)
        for (bar, label) in zip(bars, labels) {
            let target = label.convert(label.bounds, to: view)
            XCTAssertEqual(label.alpha, 0)
            XCTAssertGreaterThan(bar.width, 0)
            XCTAssertGreaterThan(bar.height, 0)
            XCTAssertTrue(view.bounds.insetBy(dx: -1, dy: -1).contains(bar))
            XCTAssertTrue(target.insetBy(dx: -1, dy: -1).contains(bar), "Gradient must lie in its label's reserved bounds")
            XCTAssertEqual(bar.minX, target.minX, accuracy: 1)
            XCTAssertEqual(bar.midY, target.midY, accuracy: 1)
        }
        for index in bars.indices.dropFirst() { XCTAssertLessThanOrEqual(bars[index - 1].maxY, bars[index].minY) }
    }

    private func host(_ controller: UIViewController, category: UIContentSizeCategory) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        window.rootViewController = controller
        window.makeKeyAndVisible()
        return window
    }

    private func assertFont(_ view: UIView, _ role: FWFontStyle, _ language: String) {
        let actual = (view as? UILabel)?.font ?? (view as? UITextField)?.font
        let expected = UIFont.fw(role, locale: Locale(identifier: language), compatibleWith: view.traitCollection)
        XCTAssertEqual(actual?.fontName, expected.fontName)
        XCTAssertEqual(actual?.pointSize ?? 0, expected.pointSize, accuracy: 0.5)
    }

    private func assertLabelsFit(_ parent: UIView) {
        for label in descendants(parent).compactMap({ $0 as? UILabel }) where isEffectivelyVisible(label) && label.text?.isEmpty == false {
            let width = label.numberOfLines == 1 ? CGFloat.greatestFiniteMagnitude : label.bounds.width
            let needed = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            if label.numberOfLines == 1 { XCTAssertGreaterThanOrEqual(label.bounds.width + 1, needed.width, label.text ?? "") }
            XCTAssertGreaterThanOrEqual(label.bounds.height + 1, needed.height, label.text ?? "")
            XCTAssertTrue(parent.bounds.insetBy(dx: -1, dy: -1).contains(label.convert(label.bounds, to: parent)), label.text ?? "")
        }
    }

    private func isEffectivelyVisible(_ view: UIView) -> Bool {
        var current: UIView? = view
        while let item = current {
            if item.isHidden || item.alpha == 0 { return false }
            current = item.superview
        }
        return true
    }

    private func assertHit(_ control: UIControl, window: UIWindow) {
        if control is UISwitch {
            // Native drawing stays small; its reserved row must contain the complete 44-point hit rectangle.
            let target = CGRect(x: control.bounds.midX - 22, y: control.bounds.midY - 22, width: 44, height: 44)
            if let parent = control.superview {
                XCTAssertTrue(parent.bounds.contains(control.convert(target, to: parent)), "Switch bounds \(control.bounds), frame \(control.frame), parent \(parent.bounds), target \(control.convert(target, to: parent))")
                XCTAssertTrue(parent.bounds.contains(control.convert(control.bounds, to: parent)), "Native switch bounds \(control.bounds), frame \(control.frame), parent \(parent.bounds), alignment \(control.alignmentRectInsets), intrinsic \(control.intrinsicContentSize), fitting \(control.sizeThatFits(.zero)), drawing \(control.convert(control.bounds, to: parent))")
                let occupied = control.convert(target, to: parent)
                for sibling in parent.subviews where sibling !== control && isEffectivelyVisible(sibling) {
                    XCTAssertFalse(occupied.intersects(sibling.frame), "Switch hit target overlaps another view")
                }
            }
            for dx: CGFloat in [-21, 0, 21] {
                for dy: CGFloat in [-21, 0, 21] {
                    let point = control.convert(CGPoint(x: control.bounds.midX + dx, y: control.bounds.midY + dy), to: window)
                    let hit = window.hitTest(point, with: nil)
                    XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true, "Native switch effective44pt touch area")
                }
            }
        } else {
            XCTAssertGreaterThanOrEqual(control.bounds.height, 44)
            XCTAssertGreaterThanOrEqual(control.bounds.width, 44)
        }
        let point = control.convert(CGPoint(x: control.bounds.midX, y: control.bounds.midY), to: window)
        let hit = window.hitTest(point, with: nil)
        XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true, "Control is covered or offscreen")
    }

    private func reveal(_ view: UIView, scroll: UIScrollView, window: UIWindow) async {
        for _ in 0 ..< 3 {
            scroll.scrollRectToVisible(view.convert(view.bounds, to: scroll), animated: false)
            await settle(window)
        }
    }

    private func settle(_ window: UIWindow) async {
        try? await Task.sleep(nanoseconds: 120_000_000)
        window.layoutIfNeeded()
    }

    private func close(_ window: UIWindow) {
        window.endEditing(true)
        window.isHidden = true
        window.rootViewController = nil
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }

    private func capture(_ controller: UIViewController, name: String) {
        let view = controller.view!
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        })
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let rows = descendants(view).compactMap { $0 as? UILabel }.map { [
            "text": $0.text ?? "", "font": $0.font.fontName, "size": String(Double($0.font.pointSize)),
            "bounds": NSCoder.string(for: $0.bounds), "frame": NSCoder.string(for: $0.convert($0.bounds, to: view)),
            "adjustsFontSizeToFitWidth": String($0.adjustsFontSizeToFitWidth), "minimumScaleFactor": String(Double($0.minimumScaleFactor)),
        ] }
        if let data = try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]) {
            let metrics = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            metrics.name = name + "-metrics"
            metrics.lifetime = .keepAlways
            add(metrics)
        }
    }
}

private final class SendPresentationOutput: SendViewOutput {
    var scan = 0, history = 0, proceed = 0, back = 0, paste = 0
    var search: [String] = []
    var all: [Bool] = []
    func didLoad(view _: SendViewInput) {}
    func didTapBackButton() { back += 1 }
    func didTapContinueButton() { proceed += 1 }
    func didTapScanButton() { scan += 1 }
    func didTapHistoryButton() { history += 1 }
    func didTapPasteButton() { paste += 1 }
    func didTapSelectAsset() {}
    func didTapSelectNetwork() {}
    func searchTextDidChanged(_ value: String) { search.append(value) }
    func selectAmountPercentage(_: Float, validate _: Bool) {}
    func didEditAmount(_: Decimal) -> () -> Void { {} }
    func updateAmount(_: Decimal) {}
    func didSwitchSendAll(_ enabled: Bool) { all.append(enabled) }
}

private final class ConfirmPresentationOutput: WalletSendConfirmPresenterProtocol {
    var confirm = 0, back = 0, warning = 0
    func setup() {}
    func didTapConfirmButton() { confirm += 1 }
    func didTapBackButton() { back += 1 }
    func didTapScamWarningButton() { warning += 1 }
}

@MainActor
final class AccountScoreBindingOwnershipTests: XCTestCase {
    func testHealthyCurrentScoreResponseUpdatesActualView() async {
        let fetcher = ControlledAccountScoreFetcher()
        defer { fetcher.finishAll() }
        let view = ObservedAccountScoreView()
        let model = await bind(address: Self.addressA, fetcher: fetcher, view: view)
        let rendered = expectation(description: "current score rendered")
        view.onScore = { if $0 == 80 { rendered.fulfill() } }
        fetcher.yield(score: Decimal(8) / 10, address: Self.addressA)
        await fulfillment(of: [rendered], timeout: 2)
        XCTAssertEqual(view.starView.text, "80")
        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(model.address, Self.addressA)
    }

    func testLatePreviousRecipientScoreCannotReplaceCurrentRecipientScore() async {
        let fetcher = ControlledAccountScoreFetcher()
        defer { fetcher.finishAll() }
        let view = ObservedAccountScoreView()
        let previous = await bind(address: Self.addressA, fetcher: fetcher, view: view)
        let current = await bind(address: Self.addressB, fetcher: fetcher, view: view)
        let rendered = expectation(description: "replacement score rendered")
        view.onScore = { if $0 == 80 { rendered.fulfill() } }
        fetcher.yield(score: Decimal(8) / 10, address: Self.addressB)
        await fulfillment(of: [rendered], timeout: 2)
        XCTAssertEqual(view.starView.text, "80")
        let obsolete = expectation(description: "obsolete score must not bind")
        obsolete.isInverted = true
        view.onScore = { if $0 == 20 { obsolete.fulfill() } }
        fetcher.yield(score: Decimal(2) / 10, address: Self.addressA)
        await fulfillment(of: [obsolete], timeout: 0.5)
        XCTAssertEqual(view.starView.text, "80")
        XCTAssertEqual(previous.address, Self.addressA)
        XCTAssertEqual(current.address, Self.addressB)
    }

    func testLateResponseCannotRepopulateClearedScoreBinding() async {
        let fetcher = ControlledAccountScoreFetcher()
        defer { fetcher.finishAll() }
        let view = ObservedAccountScoreView()
        let previous = await bind(address: Self.addressA, fetcher: fetcher, view: view)
        view.bind(viewModel: nil)
        XCTAssertEqual(view.starView.text, "N/A")
        let obsolete = expectation(description: "cleared model must not bind")
        obsolete.isInverted = true
        view.onScore = { if $0 == 20 { obsolete.fulfill() } }
        fetcher.yield(score: Decimal(2) / 10, address: Self.addressA)
        await fulfillment(of: [obsolete], timeout: 0.5)
        XCTAssertEqual(view.starView.text, "N/A")
        XCTAssertEqual(previous.address, Self.addressA)
    }

    private static let addressA = "0x1111111111111111111111111111111111111111"
    private static let addressB = "0x2222222222222222222222222222222222222222"

    private func bind(address: String, fetcher: ControlledAccountScoreFetcher, view: AccountScoreView) async -> AccountScoreViewModel {
        let subscribed = expectation(description: "subscription starts for \(address)")
        fetcher.expectSubscription(address: address, expectation: subscribed)
        let model = AccountScoreViewModel(
            fetcher: fetcher,
            address: address,
            chain: nil,
            settings: InMemorySettingsManager(),
            eventCenter: EventCenter(),
            logger: nil
        )
        view.bind(viewModel: model)
        await fulfillment(of: [subscribed], timeout: 2)
        return model
    }
}

private final class ObservedAccountScoreView: AccountScoreView {
    var onScore: ((Int) -> Void)?

    override func bind(score: Int, rate: AccountScoreRate) {
        super.bind(score: score, rate: rate)
        onScore?(score)
    }
}

private final class ControlledAccountScoreFetcher: AccountStatisticsFetching {
    private let lock = NSLock()
    private var expectations: [String: XCTestExpectation] = [:]
    private var continuations: [String: AsyncThrowingStream<AccountStatisticsResponse, Error>.Continuation] = [:]

    func expectSubscription(address: String, expectation: XCTestExpectation) {
        lock.lock()
        expectations[address] = expectation
        lock.unlock()
    }

    func subscribeForStatistics(address: String) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        AsyncThrowingStream { continuation in
            lock.lock()
            continuations[address] = continuation
            let expectation = expectations.removeValue(forKey: address)
            lock.unlock()
            expectation?.fulfill()
        }
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? { nil }

    func yield(score: Decimal, address: String) {
        lock.lock()
        let continuation = continuations[address]
        lock.unlock()
        XCTAssertNotNil(continuation)
        continuation?.yield(AccountStatisticsResponse(data: AccountStatistics(score: score, address: address, stats: nil)))
    }

    func finishAll() {
        lock.lock()
        let values = Array(continuations.values)
        continuations.removeAll()
        lock.unlock()
        values.forEach { $0.finish() }
    }
}

@MainActor
final class AccountScoreBindingLifecycleTests: XCTestCase {
    private let address = "0x3333333333333333333333333333333333333333"

    func testSameModelRebindingCancelsOldSubscriptionAndRendersFreshResponse() async {
        let first = request("first", cancellation: true)
        let second = request("second")
        let fetcher = AccountScoreRequestsFetcher([first, second])
        defer { fetcher.finishAll() }
        let view = ObservedAccountScoreView()
        let model = makeModel(fetcher)
        view.bind(viewModel: model)
        await fulfillment(of: [first.subscribed], timeout: 2)
        await render(80, from: first, in: view)
        view.bind(viewModel: model)
        await fulfillment(of: [first.cancelled!, second.subscribed], timeout: 2)
        await render(90, from: second, in: view)
        first.yield(20)
        XCTAssertEqual(view.starView.text, "90")
        XCTAssertEqual(fetcher.subscriptionCount, 2)
    }

    func testNoncooperativeOldSubscriptionReturnCannotReplaceFreshBinding() async {
        let gate = AccountScoreSubscriptionGate()
        let first = request("held old", gate: gate)
        let second = request("current")
        let fetcher = AccountScoreRequestsFetcher([first, second])
        defer { fetcher.finishAll() }
        let view = ObservedAccountScoreView()
        let old = makeModel(fetcher)
        let current = makeModel(fetcher)
        view.bind(viewModel: old)
        await fulfillment(of: [first.subscribed], timeout: 2)
        view.bind(viewModel: current)
        await fulfillment(of: [second.subscribed], timeout: 2)
        await render(80, from: second, in: view)
        let stale = expectation(description: "held old response cannot render")
        stale.isInverted = true
        view.onScore = { if $0 == 20 { stale.fulfill() } }
        first.yield(20)
        gate.release()
        await fulfillment(of: [first.returned, stale], timeout: 0.5)
        XCTAssertEqual(view.starView.text, "80")
        XCTAssertEqual(old.address, current.address)
    }

    func testClearingPreviousViewCannotCancelModelNowBoundToAnotherView() async {
        let first = request("original view", cancellation: true)
        let second = request("new view")
        let fetcher = AccountScoreRequestsFetcher([first, second])
        defer { fetcher.finishAll() }
        let oldView = ObservedAccountScoreView()
        let newView = ObservedAccountScoreView()
        let model = makeModel(fetcher)
        oldView.bind(viewModel: model)
        await fulfillment(of: [first.subscribed], timeout: 2)
        newView.bind(viewModel: model)
        await fulfillment(of: [first.cancelled!, second.subscribed], timeout: 2)
        oldView.bind(viewModel: nil)
        await render(80, from: second, in: newView)
        XCTAssertEqual(oldView.starView.text, "N/A")
        XCTAssertEqual(newView.starView.text, "80")
    }

    func testViewDeallocationCancelsSubscriptionEvenWhenModelIsRetained() async {
        let first = request("view deallocation", cancellation: true)
        let fetcher = AccountScoreRequestsFetcher([first])
        defer { fetcher.finishAll() }
        var view: ObservedAccountScoreView? = ObservedAccountScoreView()
        weak var observedView = view
        let model = makeModel(fetcher)
        view?.bind(viewModel: model)
        await fulfillment(of: [first.subscribed], timeout: 2)
        view = nil
        await fulfillment(of: [first.cancelled!], timeout: 2)
        XCTAssertNil(observedView)
        XCTAssertEqual(model.address, address)
    }

    func testRetiredModelDeallocatesWhileNoncooperativeSubscriptionWaits() async {
        let gate = AccountScoreSubscriptionGate()
        let first = request("model deallocation", gate: gate)
        let fetcher = AccountScoreRequestsFetcher([first])
        defer { fetcher.finishAll() }
        let queue = DispatchQueue(label: "score-test-event-center")
        let view = ObservedAccountScoreView()
        var model: AccountScoreViewModel? = makeModel(fetcher, eventCenter: EventCenter(syncQueue: queue))
        weak var observedModel = model
        view.bind(viewModel: model)
        await fulfillment(of: [first.subscribed], timeout: 2)
        queue.sync {}
        view.bind(viewModel: nil)
        model = nil
        XCTAssertNil(observedModel)
        gate.release()
        await fulfillment(of: [first.returned], timeout: 2)
        XCTAssertEqual(view.starView.text, "N/A")
    }

    func testQueuedSettingsEventCannotRestoreRetiredModel() async {
        let first = request("settings old", cancellation: true)
        let fetcher = AccountScoreRequestsFetcher([first])
        defer { fetcher.finishAll() }
        let view = ObservedAccountScoreView()
        let model = makeModel(fetcher)
        view.bind(viewModel: model)
        await fulfillment(of: [first.subscribed], timeout: 2)
        model.processAccountScoreSettingsChanged()
        view.bind(viewModel: nil)
        let drained = expectation(description: "queued settings delivery drained")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [first.cancelled!, drained], timeout: 2)
        XCTAssertEqual(fetcher.subscriptionCount, 1)
        XCTAssertEqual(view.starView.text, "N/A")
    }

    func testCurrentSettingsChangesStillHideAndRestoreCurrentScoreView() async {
        let first = request("enabled", cancellation: true)
        let second = request("disabled", cancellation: true)
        let third = request("reenabled")
        let fetcher = AccountScoreRequestsFetcher([first, second, third])
        defer { fetcher.finishAll() }
        let settings = InMemorySettingsManager()
        let view = ObservedAccountScoreView()
        let model = makeModel(fetcher, settings: settings)
        view.bind(viewModel: model)
        await fulfillment(of: [first.subscribed], timeout: 2)
        await render(80, from: first, in: view)
        settings.accountScoreEnabled = false
        model.processAccountScoreSettingsChanged()
        await fulfillment(of: [first.cancelled!, second.subscribed], timeout: 2)
        XCTAssertTrue(view.isHidden)
        settings.accountScoreEnabled = true
        model.processAccountScoreSettingsChanged()
        await fulfillment(of: [second.cancelled!, third.subscribed], timeout: 2)
        await render(90, from: third, in: view)
        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(fetcher.subscriptionCount, 3)
    }

    func testCurrentMissingScoreStillRendersEmptyState() async {
        let first = request("missing score")
        let fetcher = AccountScoreRequestsFetcher([first])
        defer { fetcher.finishAll() }
        let view = AccountScoreEmptyObservedView()
        view.bind(viewModel: makeModel(fetcher))
        await fulfillment(of: [first.subscribed], timeout: 2)
        let empty = expectation(description: "current missing score renders empty")
        view.onEmpty = { empty.fulfill() }
        first.yield(nil)
        await fulfillment(of: [empty], timeout: 2)
        XCTAssertEqual(view.starView.text, "N/A")
    }

    func testCurrentStreamErrorStillRendersEmptyState() async {
        let first = request("stream error")
        let fetcher = AccountScoreRequestsFetcher([first])
        defer { fetcher.finishAll() }
        let view = AccountScoreEmptyObservedView()
        view.bind(viewModel: makeModel(fetcher))
        await fulfillment(of: [first.subscribed], timeout: 2)
        let empty = expectation(description: "current stream error renders empty")
        view.onEmpty = { empty.fulfill() }
        first.continuation.finish(throwing: AccountScoreRequestsFetcher.Failure.fixture)
        await fulfillment(of: [empty], timeout: 2)
        XCTAssertEqual(view.starView.text, "N/A")
    }

    func testNilAddressDoesNotStartSubscription() {
        let fetcher = AccountScoreRequestsFetcher([])
        let view = ObservedAccountScoreView()
        let model = AccountScoreViewModel(
            fetcher: fetcher,
            address: nil,
            chain: nil,
            settings: InMemorySettingsManager(),
            eventCenter: EventCenter(),
            logger: nil
        )
        view.bind(viewModel: model)
        XCTAssertEqual(fetcher.subscriptionCount, 0)
        XCTAssertTrue(view.isHidden)
        view.bind(viewModel: nil)
        XCTAssertEqual(view.starView.text, "N/A")
    }

    private func request(_ name: String, cancellation: Bool = false, gate: AccountScoreSubscriptionGate? = nil) -> AccountScorePendingRequest {
        AccountScorePendingRequest(
            subscribed: expectation(description: name + " subscribed"),
            returned: XCTestExpectation(description: name + " subscription returned"),
            cancelled: cancellation ? expectation(description: name + " cancelled") : nil,
            gate: gate
        )
    }

    private func makeModel(
        _ fetcher: AccountStatisticsFetching,
        settings: SettingsManagerProtocol = InMemorySettingsManager(),
        eventCenter: EventCenterProtocol = EventCenter()
    ) -> AccountScoreViewModel {
        AccountScoreViewModel(fetcher: fetcher, address: address, chain: nil, settings: settings, eventCenter: eventCenter, logger: nil)
    }

    private func render(_ score: Int, from request: AccountScorePendingRequest, in view: ObservedAccountScoreView) async {
        let rendered = expectation(description: "actual score renders \(score)")
        view.onScore = { if $0 == score { rendered.fulfill() } }
        request.yield(score)
        await fulfillment(of: [rendered], timeout: 2)
        XCTAssertEqual(view.starView.text, String(score))
        view.onScore = nil
    }
}

private final class AccountScoreEmptyObservedView: AccountScoreView {
    var onEmpty: (() -> Void)?
    override func bindEmptyViewModel() {
        super.bindEmptyViewModel()
        onEmpty?()
    }
}

private final class AccountScoreSubscriptionGate {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if released {
                lock.unlock()
                continuation.resume()
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }
    }

    func release() {
        lock.lock()
        released = true
        let waiting = continuation
        continuation = nil
        lock.unlock()
        waiting?.resume()
    }
}

private final class AccountScorePendingRequest {
    let subscribed: XCTestExpectation
    let returned: XCTestExpectation
    let cancelled: XCTestExpectation?
    let gate: AccountScoreSubscriptionGate?
    let stream: AsyncThrowingStream<AccountStatisticsResponse, Error>
    let continuation: AsyncThrowingStream<AccountStatisticsResponse, Error>.Continuation

    init(subscribed: XCTestExpectation, returned: XCTestExpectation, cancelled: XCTestExpectation?, gate: AccountScoreSubscriptionGate?) {
        self.subscribed = subscribed
        self.returned = returned
        self.cancelled = cancelled
        self.gate = gate
        var captured: AsyncThrowingStream<AccountStatisticsResponse, Error>.Continuation!
        stream = AsyncThrowingStream { captured = $0 }
        continuation = captured
        continuation.onTermination = { reason in
            if case .cancelled = reason { cancelled?.fulfill() }
        }
    }

    func yield(_ score: Int?) {
        continuation.yield(AccountStatisticsResponse(data: AccountStatistics(score: score.map { Decimal($0) / 100 }, address: "public fixture", stats: nil)))
    }
}

private final class AccountScoreRequestsFetcher: AccountStatisticsFetching {
    enum Failure: Error { case fixture }
    private let lock = NSLock()
    private let requests: [AccountScorePendingRequest]
    private var index = 0

    init(_ requests: [AccountScorePendingRequest]) { self.requests = requests }

    var subscriptionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return index
    }

    private func next() throws -> AccountScorePendingRequest {
        lock.lock()
        defer { lock.unlock() }
        guard index < requests.count else {
            XCTFail("Unexpected score subscription")
            throw Failure.fixture
        }
        defer { index += 1 }
        return requests[index]
    }

    func subscribeForStatistics(address _: String) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        let request = try next()
        request.subscribed.fulfill()
        if let gate = request.gate { await gate.wait() }
        request.returned.fulfill()
        return request.stream
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? { nil }

    func finishAll() {
        requests.forEach { $0.gate?.release(); $0.continuation.finish() }
    }
}

@MainActor
extension SendPresentationTests {
    func testSendAllExplanationFitsItsActualRowAcrossLocalesAndTextSizes() async throws {
        for language in languages {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let fixture = try sendFixture(language: language, category: category)
                defer { close(fixture.window) }
                let root = fixture.controller.rootView
                await reveal(root.sendAllContainerView, scroll: root.contentView.scrollView, window: fixture.window)
                XCTAssertFalse(root.sendAllContainerView.isHidden)
                XCTAssertEqual(root.sendAllLabel.text, expectedSendAll[language])
                assertLabelsFit(root.sendAllContainerView)
                capture(fixture.controller, name: "send-all-row-\(language)-\(category.rawValue)")
            }
        }
    }

    func testSendAllNativeSwitchDrawingStaysInsideItsActualRow() async throws {
        for language in languages {
            let fixture = try sendFixture(language: language, category: .large)
            defer { close(fixture.window) }
            let root = fixture.controller.rootView
            await reveal(root.sendAllContainerView, scroll: root.contentView.scrollView, window: fixture.window)
            let drawing = root.sendAllSwitch.convert(root.sendAllSwitch.bounds, to: root.sendAllContainerView)
            XCTAssertTrue(
                root.sendAllContainerView.bounds.contains(drawing),
                "\(language): native drawing \(drawing) in row \(root.sendAllContainerView.bounds)"
            )
            let center = root.sendAllSwitch.convert(
                CGPoint(x: root.sendAllSwitch.bounds.midX, y: root.sendAllSwitch.bounds.midY), to: fixture.window
            )
            let hit = fixture.window.hitTest(center, with: nil)
            XCTAssertTrue(hit === root.sendAllSwitch || hit?.isDescendant(of: root.sendAllSwitch) == true)
        }
    }

    func testSendAllVisibilityRoundTripPreservesNativeControlAndCallbacks() async throws {
        let fixture = try sendFixture(language: "en", category: .large)
        defer { close(fixture.window) }
        let root = fixture.controller.rootView
        let original = root.sendAllSwitch
        for enabled in [true, false, true] {
            fixture.controller.switchEnableSendAllVisibility(isVisible: false)
            await settle(fixture.window)
            XCTAssertTrue(root.sendAllContainerView.isHidden)
            fixture.controller.switchEnableSendAllVisibility(isVisible: true)
            await reveal(root.sendAllContainerView, scroll: root.contentView.scrollView, window: fixture.window)
            XCTAssertTrue(root.sendAllSwitch === original)
            root.sendAllSwitch.isOn = enabled
            root.sendAllSwitch.sendActions(for: .valueChanged)
        }
        XCTAssertEqual(fixture.output.all, [true, false, true])
        XCTAssertEqual(root.searchView.textField.text, recipient)
        XCTAssertEqual(root.amountView.inputFieldText, fixture.input.displayAmount)
    }

    func testSendAllSwitchRetainsNativeWidthAfterLocaleAndTextSizeChanges() async throws {
        let fixture = try sendFixture(language: "en", category: .large)
        defer { close(fixture.window) }
        let root = fixture.controller.rootView
        for language in languages {
            root.locale = Locale(identifier: language)
            if #available(iOS 17.0, *) {
                fixture.window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
            }
            await reveal(root.sendAllContainerView, scroll: root.contentView.scrollView, window: fixture.window)
            XCTAssertEqual(root.sendAllLabel.text, expectedSendAll[language])
            XCTAssertGreaterThanOrEqual(
                root.sendAllSwitch.bounds.width + 1, root.sendAllSwitch.intrinsicContentSize.width
            )
            XCTAssertTrue(root.sendAllContainerView.bounds.contains(
                root.sendAllSwitch.convert(root.sendAllSwitch.bounds, to: root.sendAllContainerView)
            ))
            assertLabelsFit(root.sendAllContainerView)
            let label = root.sendAllLabel.convert(root.sendAllLabel.bounds, to: root.sendAllContainerView)
            let control = root.sendAllSwitch.convert(root.sendAllSwitch.bounds, to: root.sendAllContainerView)
            XCTAssertLessThanOrEqual(label.maxX, control.minX)
        }
    }
}
