import XCTest
import UIKit
import SSFModels
@testable import fearless

final class WalletSendConfirmNetworkRowTests: XCTestCase {
    func testFactoryNamesActualNetworkAndTokenStandard() throws {
        let assets = try SendNetworkFixture.assets()
        let erc20 = try XCTUnwrap(assets.first { $0.chain.name == "Ethereum" && $0.asset.symbol.lowercased() == "usdt" })
        XCTAssertEqual(WalletSendConfirmViewModelFactory.networkName(chain: erc20.chain, asset: erc20.asset), "Ethereum · ERC-20")
        for id in [UniversalWalletRegistry.bitcoinMainnet.chainId, UniversalWalletRegistry.solanaMainnet.chainId] {
            let asset = try XCTUnwrap(assets.first { $0.chain.chainId == id })
            let factory = WalletSendConfirmViewModelFactory(amountFormatterFactory: AssetBalanceFormatterFactory(), assetInfo: asset.asset.displayInfo(with: asset.chain.icon))
            let model = factory.buildViewModel(parameters: WalletSendConfirmViewModelFactoryParameters(
                amount: 1, senderAccountViewModel: nil, receiverAccountViewModel: nil, assetBalanceViewModel: nil,
                tipRequired: false, tipViewModel: nil, feeViewModel: nil, wallet: AccountGenerator.generateMetaAccount(),
                locale: Locale(identifier: "en"), scamInfo: nil, assetModel: asset.asset, chain: asset.chain
            ))
            XCTAssertEqual(model.networkName, asset.chain.name)
            XCTAssertFalse(model.networkIsTestnet)
        }
    }

    /// A Solana token transfer that opens the recipient's token account shows that deposit on
    /// its own row under the fee that includes it; other transfers show no such row.
    @MainActor
    func testRecipientAccountDepositHasItsOwnRowOnlyWhenTheTransferOpensAnAccount() throws {
        let assets = try SendNetworkFixture.assets()
        let solana = try XCTUnwrap(assets.first { $0.chain.chainId == UniversalWalletRegistry.solanaMainnet.chainId })
        let factory = WalletSendConfirmViewModelFactory(
            amountFormatterFactory: AssetBalanceFormatterFactory(),
            assetInfo: solana.asset.displayInfo(with: solana.chain.icon)
        )
        func model(deposit: BalanceViewModelProtocol?) -> WalletSendConfirmViewModel {
            factory.buildViewModel(parameters: WalletSendConfirmViewModelFactoryParameters(
                amount: 1, senderAccountViewModel: nil, receiverAccountViewModel: nil, assetBalanceViewModel: nil,
                tipRequired: false, tipViewModel: nil,
                feeViewModel: BalanceViewModel(amount: "0.00204428 SOL", price: "$0.39"),
                wallet: AccountGenerator.generateMetaAccount(), locale: Locale(identifier: "en"), scamInfo: nil,
                assetModel: solana.asset, chain: solana.chain, accountCreationDepositViewModel: deposit
            ))
        }

        for language in ["en", "ja", "pt-PT", "zh-Hans"] {
            let layout = WalletSendConfirmViewLayout()
            layout.locale = Locale(identifier: language)
            let bundle = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)))
            let title = bundle.localizedString(forKey: "solana.transfer.account_creation.title", value: nil, table: nil)
            let note = bundle.localizedString(forKey: "solana.transfer.account_creation.included", value: nil, table: nil)
            XCTAssertFalse(title.hasPrefix("solana."), language)

            layout.bind(confirmViewModel: model(deposit: BalanceViewModel(amount: "0.00203928 SOL", price: "$0.38")))
            XCTAssertFalse(layout.accountCreationView.isHidden, language)
            XCTAssertEqual(layout.accountCreationView.titleLabel.text, title)
            XCTAssertEqual(layout.accountCreationView.valueTop.text, "0.00203928 SOL")
            XCTAssertEqual(layout.accountCreationView.valueBottom.text, "$0.38 · \(note)")
            XCTAssertEqual(layout.feeView.valueTop.text, "0.00204428 SOL", "The fee still includes the deposit")
            let rows = layout.infoViewsStackView.arrangedSubviews
            XCTAssertEqual(rows.firstIndex(of: layout.accountCreationView), rows.firstIndex(of: layout.feeView).map { $0 + 1 })

            layout.bind(confirmViewModel: model(deposit: nil))
            XCTAssertTrue(layout.accountCreationView.isHidden, language)
        }
    }

    @MainActor
    func testNetworkIsFirstDetailAndTestnetWarningIsAlwaysReadable() throws {
        let layout = WalletSendConfirmViewLayout()
        XCTAssertTrue(layout.infoViewsStackView.arrangedSubviews.first === layout.networkView)
        layout.networkView.bind(name: "Taira", isTestnet: true, icon: nil, locale: Locale(identifier: "en"))
        XCTAssertEqual(layout.networkView.titleLabel.text, "NETWORK")
        XCTAssertFalse(layout.networkView.testnetLabel.isHidden)
        XCTAssertTrue(layout.networkView.accessibilityLabel?.contains("Test tokens have no value") == true)
        layout.networkView.bind(name: "Bitcoin", isTestnet: false, icon: nil, locale: Locale(identifier: "en"))
        XCTAssertTrue(layout.networkView.testnetLabel.isHidden)
        XCTAssertFalse(layout.networkView.accessibilityLabel?.contains("Test tokens") == true)
    }

    @MainActor
    func testLongNetworkWrapsOnSmallScreenAtLargestTextSize() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        let parent = UIViewController()
        let child = UIViewController()
        let layout = WalletSendConfirmViewLayout()
        child.view = layout
        parent.addChild(child)
        parent.view.addSubview(layout)
        layout.frame = parent.view.bounds
        layout.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        child.didMove(toParent: parent)
        parent.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge), forChild: child)
        window.rootViewController = parent
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let name = "Very long network name that must remain fully visible · ERC-20"
        layout.locale = Locale(identifier: "en")
        layout.bind(confirmViewModel: WalletSendConfirmViewModel(
            networkName: name, networkIsTestnet: true, networkIcon: nil,
            amountAttributedString: NSAttributedString(string: "1 USDT"), amountString: "1 USDT",
            senderNameString: "Test wallet", senderAddressString: "0x1111…1111",
            receiverAddressString: "0x2222…2222", priceString: "$1.00",
            feeAmountString: "0.001 ETH", feePriceString: "$0.10", tipRequired: false,
            tipAmountString: "", tipPriceString: "", showWarning: false,
            symbolViewModel: SymbolViewModel(symbolViewModel: nil, shadowColor: nil)
        ))
        window.layoutIfNeeded()
        layout.layoutIfNeeded()
        layout.contentView.layoutIfNeeded()
        layout.networkView.layoutIfNeeded()
        let label = layout.networkView.nameLabel
        XCTAssertEqual(label.numberOfLines, 0)
        XCTAssertGreaterThan(label.bounds.height, label.font.lineHeight * 1.8)
        XCTAssertGreaterThan(label.bounds.width, 100)
        XCTAssertEqual(label.bounds.width, layout.networkView.bounds.width, accuracy: 1)
        XCTAssertLessThanOrEqual(
            layout.networkView.titleLabel.bounds.height,
            layout.networkView.titleLabel.font.lineHeight * 1.25
        )
        let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
        XCTAssertGreaterThanOrEqual(label.bounds.height + 1, needed.height)
        XCTAssertTrue(layout.networkView.accessibilityLabel?.contains(name) == true)
        if !FWAppearance.sendPresentationRestyled {
            XCTAssertLessThanOrEqual(layout.contentView.frame.maxY, layout.confirmButton.frame.minY)
        }
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: layout.bounds).image { _ in
            layout.drawHierarchy(in: layout.bounds, afterScreenUpdates: true)
        })
        attachment.name = "send-network-first-small-largest-text"
        attachment.lifetime = .keepAlways
        add(attachment)

        // The first network detail may be taller than the viewport. Its warning still
        // has to be reachable inside the visible content viewport by ordinary scrolling.
        let scrollView = layout.contentView.scrollView
        let warningRect = layout.networkView.testnetLabel.convert(layout.networkView.testnetLabel.bounds, to: scrollView)
        scrollView.scrollRectToVisible(warningRect, animated: false)
        layout.layoutIfNeeded()
        let visibleWarning = layout.networkView.testnetLabel.convert(layout.networkView.testnetLabel.bounds, to: layout)
        XCTAssertGreaterThanOrEqual(visibleWarning.minY, layout.contentView.frame.minY)
        XCTAssertLessThanOrEqual(visibleWarning.maxY, layout.contentView.frame.maxY)
        if !FWAppearance.sendPresentationRestyled {
            XCTAssertLessThanOrEqual(visibleWarning.maxY, layout.confirmButton.frame.minY)
        }
        XCTAssertEqual(layout.confirmButton.imageWithTitleView?.title, "Confirm")
        let scrolled = XCTAttachment(image: UIGraphicsImageRenderer(bounds: layout.bounds).image { _ in
            layout.drawHierarchy(in: layout.bounds, afterScreenUpdates: true)
        })
        scrolled.name = "send-network-warning-small-largest-text-scrolled"
        scrolled.lifetime = .keepAlways
        add(scrolled)
        if FWAppearance.sendPresentationRestyled {
            scrollView.scrollRectToVisible(layout.confirmButton.convert(layout.confirmButton.bounds, to: scrollView), animated: false)
            window.layoutIfNeeded()
            let buttonRect = layout.confirmButton.convert(layout.confirmButton.bounds, to: layout)
            XCTAssertGreaterThanOrEqual(buttonRect.minY, layout.contentView.frame.minY)
            XCTAssertLessThanOrEqual(buttonRect.maxY, layout.contentView.frame.maxY)
            let point = layout.confirmButton.convert(CGPoint(x: layout.confirmButton.bounds.midX, y: layout.confirmButton.bounds.midY), to: window)
            let hit = window.hitTest(point, with: nil)
            XCTAssertTrue(hit === layout.confirmButton || hit?.isDescendant(of: layout.confirmButton) == true)
        }
    }
}
