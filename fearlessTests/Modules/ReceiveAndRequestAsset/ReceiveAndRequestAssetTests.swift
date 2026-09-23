import UIKit
import XCTest
@testable import fearless

final class ReceiveAndRequestAssetTests: XCTestCase {
    func testInputAccessibilityFrameMatchesItsFullTouchTarget() {
        let first = CommonInputView()
        let second = CommonInputViewV2()
        first.title = "Wallet nickname"
        second.title = "Wallet nickname"
        first.text = "QA wallet"
        second.text = "QA wallet"
        let inputs: [(UIView, UIView, UITextField)] = [
            (first, first.animatedInputField, first.animatedInputField.textField),
            (second, second.animatedInputField, second.animatedInputField.textField)
        ]
        for (input, target, field) in inputs {
            let controller = UIViewController()
            controller.view.addSubview(input)
            withVisibleFixture(controller, category: .large) {
                input.frame = CGRect(x: 16, y: 80, width: 288, height: 52)
                input.setNeedsLayout()
                input.layoutIfNeeded()
                XCTAssertGreaterThanOrEqual(target.bounds.height, 44)
                XCTAssertEqual(field.accessibilityFrame,
                    UIAccessibility.convertToScreenCoordinates(target.bounds, in: target))
                for point in [CGPoint(x: 24, y: 2), CGPoint(x: 24, y: target.bounds.maxY - 2)] {
                    XCTAssertNotNil(target.hitTest(point, with: nil))
                }
                input.frame.size.width = 240
                controller.view.bounds.origin.y = 24
                input.setNeedsLayout()
                input.layoutIfNeeded()
                XCTAssertEqual(field.accessibilityFrame,
                    UIAccessibility.convertToScreenCoordinates(target.bounds, in: target))
            }
        }
    }

    func testInputFieldsKeepLocalizedNamesWhenEmptyOrFilled() {
        let first = CommonInputView()
        let second = CommonInputViewV2()
        first.title = "Wallet nickname"
        second.title = "Wallet nickname"
        XCTAssertEqual(first.animatedInputField.textField.accessibilityLabel, "Wallet nickname")
        XCTAssertEqual(second.animatedInputField.textField.accessibilityLabel, "Wallet nickname")
        first.text = "QA wallet"
        second.text = "QA wallet"
        first.title = "Nombre de la cartera"
        second.title = "Nombre de la cartera"
        XCTAssertEqual(first.animatedInputField.textField.accessibilityLabel, "Nombre de la cartera")
        XCTAssertEqual(second.animatedInputField.textField.accessibilityLabel, "Nombre de la cartera")
        XCTAssertEqual(first.text, "QA wallet")
        XCTAssertEqual(second.text, "QA wallet")
    }

    func testCustomButtonExposesOneNamedActionAndTracksLocalizedTitle() {
        let button = TriangularedButton(frame: CGRect(x: 0, y: 0, width: 280, height: 48))
        button.imageWithTitleView?.title = "Create a new wallet"
        XCTAssertTrue(button.isAccessibilityElement)
        XCTAssertTrue(button.accessibilityTraits.contains(.button))
        XCTAssertEqual(button.accessibilityLabel, "Create a new wallet")
        button.imageWithTitleView?.title = "Crear una cartera"
        XCTAssertEqual(button.accessibilityLabel, "Crear una cartera")
        button.accessibilityLabel = "Custom action"
        XCTAssertEqual(button.accessibilityLabel, "Custom action")
        button.accessibilityLabel = nil
        XCTAssertEqual(button.accessibilityLabel, "Crear una cartera")
    }

    func testCustomButtonAccessibilityActivationUsesExistingTouchAction() {
        let button = TriangularedButton()
        var activations = 0
        button.addAction(UIAction { _ in activations += 1 }, for: .touchUpInside)
        XCTAssertTrue(button.accessibilityActivate())
        XCTAssertEqual(activations, 1)
        button.set(enabled: false)
        XCTAssertTrue(button.accessibilityTraits.contains(.notEnabled))
        XCTAssertFalse(button.accessibilityActivate())
        button.set(enabled: true)
        XCTAssertFalse(button.accessibilityTraits.contains(.notEnabled))
        XCTAssertTrue(button.accessibilityActivate())
        XCTAssertEqual(activations, 2)
    }

    func testCustomButtonLoadingRetainsNameAndPreventsAccessibilitySubmission() {
        let button = TriangularedButton()
        button.imageWithTitleView?.title = "Continue"
        var activations = 0
        button.addAction(UIAction { _ in activations += 1 }, for: .touchUpInside)
        button.set(loading: true)
        XCTAssertEqual(button.accessibilityLabel, "Continue")
        XCTAssertTrue(button.accessibilityTraits.contains(.notEnabled))
        XCTAssertFalse(button.accessibilityActivate())
        button.set(enabled: false)
        button.set(loading: false)
        XCTAssertFalse(button.accessibilityActivate())
        button.set(enabled: true)
        XCTAssertFalse(button.accessibilityTraits.contains(.notEnabled))
        XCTAssertTrue(button.accessibilityActivate())
        XCTAssertEqual(activations, 1)
        button.isHidden = true
        XCTAssertFalse(button.accessibilityActivate())
        button.isHidden = false
        button.isUserInteractionEnabled = false
        XCTAssertTrue(button.accessibilityTraits.contains(.notEnabled))
        XCTAssertFalse(button.accessibilityActivate())
        XCTAssertEqual(activations, 1)
    }

    func testSearchFieldFitsLegacyHostLayoutsAtBothTextSizes() {
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            UITraitCollection(preferredContentSizeCategory: category).performAsCurrent {
                let details = WalletDetailsViewLayout()
                let pools = LiquidityPoolsListViewLayout()
                pools.searchTextField.isHidden = false
                let connections = WalletConnectActiveSessionsViewLayout()
                let assets = AssetListSearchViewLayout()
                let hosts: [(UIView, SearchTextField)] = [
                    (details, details.searchTextField),
                    (pools, pools.searchTextField),
                    (connections, connections.searchView),
                    (assets, assets.searchTextField)
                ]
                for (host, search) in hosts {
                    search.textField.placeholder = "Search"
                    let controller = UIViewController()
                    controller.view = host
                    withVisibleFixture(controller, category: category) {
                        XCTAssertGreaterThanOrEqual(search.textField.bounds.height, 44)
                        XCTAssertGreaterThanOrEqual(search.textField.bounds.height + 1,
                            search.textField.font?.lineHeight ?? 0)
                        XCTAssertTrue(host.bounds.contains(search.convert(search.bounds, to: host)))
                    }
                }
            }
        }
    }

    func testSearchInputHasMinimumTouchTargetScalesAndSubmits() {
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            UITraitCollection(preferredContentSizeCategory: category).performAsCurrent {
                let view = AssetManagementViewLayout()
                view.locale = Locale(identifier: "en")
                view.setFilter(title: "Bitcoin")
                let controller = UIViewController()
                controller.view = view
                var query: String?
                view.searchTextField.onTextDidChanged = { query = $0 }
                withVisibleFixture(controller, category: category) {
                    let input = view.searchTextField.textField
                    XCTAssertGreaterThanOrEqual(input.bounds.height, 44)
                    XCTAssertGreaterThanOrEqual(input.bounds.height + 1, input.font?.lineHeight ?? 0)
                    XCTAssertEqual(input.font?.pointSize,
                        UIFont.preferredFont(forTextStyle: .body, compatibleWith: view.traitCollection).pointSize)
                    XCTAssertEqual(input.placeholder, "Search")
                    XCTAssertEqual(input.accessibilityLabel, "Search")
                    input.placeholder = "Search networks"
                    XCTAssertEqual(input.accessibilityLabel, "Search networks")
                    XCTAssertEqual(input.attributedPlaceholder?.string, "Search networks")
                    input.accessibilityLabel = "Find assets"
                    XCTAssertEqual(input.accessibilityLabel, "Find assets")
                    input.accessibilityLabel = nil
                    input.placeholder = "Search"
                    XCTAssertGreaterThanOrEqual(view.manageAssetStubLabel.bounds.height + 1,
                        view.manageAssetStubLabel.sizeThatFits(CGSize(width: view.manageAssetStubLabel.bounds.width,
                            height: .greatestFiniteMagnitude)).height)
                    XCTAssertFalse(input.leftView is UIControl)
                    XCTAssertEqual(input.leftView?.isAccessibilityElement, false)
                    attachFixture(view, name: "manage-assets-search-320pt-\(category.rawValue)")
                    XCTAssertTrue(input.becomeFirstResponder())
                    input.text = "Bitcoin"
                    XCTAssertTrue(view.searchTextField.textFieldShouldReturn(input))
                    XCTAssertEqual(query, "Bitcoin")
                    XCTAssertFalse(input.isFirstResponder)
                }
            }
        }
    }

    func testManageAssetsRowFitsFullAmountsAtMaximumText() {
        let category = UIContentSizeCategory.accessibilityExtraExtraExtraLarge
        UITraitCollection(preferredContentSizeCategory: category).performAsCurrent {
            let cell = AssetManagementTableCell(style: .default, reuseIdentifier: nil)
            cell.symbolLabel.text = "BTC"
            cell.chainNameLabel.text = "Bitcoin Mainnet"
            cell.balanceLabel.text = "123456789.12345678"
            cell.fiatBalanceLabel.text = "$123,456,789.01"
            let controller = UIViewController()
            controller.view.addSubview(cell)
            withVisibleFixture(controller, category: category) {
                cell.frame = CGRect(x: 0, y: 0, width: 320, height: 55)
                cell.layoutIfNeeded()
                let size = cell.contentView.systemLayoutSizeFitting(CGSize(width: 320, height: 0),
                    withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
                XCTAssertGreaterThan(size.height, 55)
                cell.frame.size.height = size.height
                cell.setNeedsLayout()
                cell.layoutIfNeeded()
                for label in [cell.symbolLabel, cell.chainNameLabel, cell.balanceLabel, cell.fiatBalanceLabel] {
                    XCTAssertGreaterThan(label.bounds.width, 100)
                    XCTAssertGreaterThanOrEqual(label.bounds.height + 1,
                        label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
                    XCTAssertTrue(cell.contentView.bounds.contains(label.convert(label.bounds, to: cell.contentView)))
                }
                attachFixture(cell, name: "manage-assets-row-320pt-maximum-text")
                let header = AssetManagementTableHeaderView(reuseIdentifier: nil)
                header.symbolLabel.text = "Long grouped token name"
                header.countLabel.text = "123 networks"
                controller.view.addSubview(header)
                header.frame = CGRect(x: 0, y: 0, width: 320, height: 55)
                header.layoutIfNeeded()
                let headerSize = header.contentView.systemLayoutSizeFitting(CGSize(width: 320, height: 0),
                    withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
                header.frame.size.height = headerSize.height
                header.setNeedsLayout()
                header.layoutIfNeeded()
                XCTAssertGreaterThan(headerSize.height, 55)
                for label in [header.symbolLabel, header.countLabel] {
                    XCTAssertGreaterThanOrEqual(label.bounds.height + 1,
                        label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
                    XCTAssertLessThanOrEqual(label.frame.maxX, header.imageView.frame.minX)
                }
                attachFixture(header, name: "manage-assets-group-320pt-maximum-text")
            }
        }
    }

    func testWalletSwitcherConstructsBothModesAndKeepsBackClearOfTitle() {
        for type in [WalletsManagmentType.wallets, .selectYourWallet(selectedWalletId: nil)] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                UITraitCollection(preferredContentSizeCategory: category).performAsCurrent {
                    let view = WalletsManagmentViewLayout(type: type)
                    view.locale = Locale(identifier: "en")
                    let controller = UIViewController()
                    controller.view = view
                    withVisibleFixture(controller, category: category) {
                        XCTAssertGreaterThanOrEqual(view.backButton.bounds.width, 44)
                        XCTAssertGreaterThanOrEqual(view.backButton.bounds.height, 44)
                        let backFrame = view.backButton.convert(view.backButton.bounds, to: view)
                        let titleFrame = view.titleLabel.convert(view.titleLabel.bounds, to: view)
                        XCTAssertLessThanOrEqual(backFrame.maxX + 8, titleFrame.minX)
                        XCTAssertGreaterThanOrEqual(view.titleLabel.bounds.height + 1,
                            view.titleLabel.sizeThatFits(CGSize(width: view.titleLabel.bounds.width, height: .greatestFiniteMagnitude)).height)
                    }
                }
            }
        }
    }

    func testManageAssetsHeaderFitsMaximumTextAboveSearch() {
        let category = UIContentSizeCategory.accessibilityExtraExtraExtraLarge
        UITraitCollection(preferredContentSizeCategory: category).performAsCurrent {
            let view = AssetManagementViewLayout()
            view.locale = Locale(identifier: "en")
            view.setFilter(title: "Ethereum Mainnet")
            let controller = UIViewController()
            controller.view = view
            withVisibleFixture(controller, category: category) {
                for button in [view.doneButton, view.filterNetworksButton] as [UIControl] {
                    XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                    for label in descendants(in: button).compactMap({ $0 as? UILabel }) {
                        XCTAssertGreaterThanOrEqual(label.bounds.height + 1,
                            label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
                        XCTAssertLessThanOrEqual(label.convert(label.bounds, to: view).maxY, view.searchTextField.frame.minY)
                    }
                }
                attachFixture(view, name: "manage-assets-header-320pt-maximum-text")
            }
        }
    }

    func testWalletHeaderCopyActionUsesFullAddress() {
        let address = "bc1qzmtrqsfuaf6l6kkcsseumq26ukaphfj9skkug6"
        let view = WalletMainContainerViewLayout()
        view.bind(viewModel: WalletMainContainerViewModel(walletName: "My wallet", selectedFilter: "Bitcoin", selectedFilterImage: nil, address: address, accountScoreViewModel: nil))
        let controller = UIViewController()
        controller.view = view
        var copied = false
        view.addressCopyableLabel.onСopied = { copied = true }
        withVisibleFixture(controller, category: .large) {
            XCTAssertGreaterThanOrEqual(view.addressCopyableLabel.bounds.height, 44)
            XCTAssertEqual(view.addressCopyableLabel.accessibilityValue, address)
            XCTAssertTrue(view.addressCopyableLabel.accessibilityTraits.contains(.button))
            XCTAssertTrue(view.addressCopyableLabel.accessibilityActivate())
            XCTAssertTrue(copied)
            XCTAssertEqual(UIPasteboard.general.string, address)
        }
    }

    func testReceiveShowsExactNetworkAndFullAddressAtLargeTextSize() {
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            let traits = UITraitCollection(preferredContentSizeCategory: category)
            traits.performAsCurrent {
                let view = ReceiveAndRequestAssetViewLayout()
                view.locale = Locale(identifier: "en")
                let address = "0x1234567890abcdef1234567890abcdef12345678"
                view.bind(viewModel: ReceiveAssetViewModel(asset: "USDT", networkName: "Ethereum", accountName: "My wallet", address: address, isSora: false))
                view.bind(assetViewModel: nil)
                let qr = CIFilter(name: "CIQRCodeGenerator")!
                qr.setValue(Data(address.utf8), forKey: "inputMessage")
                view.qrView.qrImageView.image = UIImage(ciImage: qr.outputImage!.transformed(by: CGAffineTransform(scaleX: 5, y: 5)))
                let controller = UIViewController()
                controller.view = view
                withVisibleFixture(controller, category: category) {
                    XCTAssertEqual(view.networkLabel.text, "USDT · Ethereum")
                    XCTAssertTrue(view.networkInstructionLabel.text?.contains("Ethereum") == true)
                    XCTAssertEqual(view.addressLabel.text, address)
                    XCTAssertEqual(view.addressLabel.numberOfLines, 0)
                    XCTAssertGreaterThanOrEqual(view.navigationBar.backButton.bounds.width, 44)
                    XCTAssertGreaterThanOrEqual(view.navigationBar.titleLabel.bounds.height + 1, view.navigationBar.titleLabel.sizeThatFits(CGSize(width: view.navigationBar.titleLabel.bounds.width, height: .greatestFiniteMagnitude)).height)
                    XCTAssertTrue(view.addressLabel.adjustsFontForContentSizeCategory)
                    XCTAssertLessThanOrEqual(view.addressLabel.bounds.width, 288)
                    attachFixture(view, name: "receive-320pt-\(category.rawValue)-top")
                    let scroll = view.contentView.scrollView
                    XCTAssertTrue(scroll.clipsToBounds)
                    let addressContentFrame = view.addressLabel.convert(view.addressLabel.bounds, to: scroll)
                    let minimumOffset = -scroll.adjustedContentInset.top
                    let maximumOffset = max(minimumOffset, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                    let addressStartOffset = min(maximumOffset, max(minimumOffset, addressContentFrame.minY - scroll.adjustedContentInset.top))
                    for (position, offset) in [("start", addressStartOffset), ("end", maximumOffset)] {
                        scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                        view.layoutIfNeeded()
                        let viewport = scroll.convert(scroll.bounds.inset(by: scroll.adjustedContentInset), to: view)
                        let addressFrame = view.addressLabel.convert(view.addressLabel.bounds, to: view)
                        let visibleAddress = addressFrame.intersection(viewport)
                        XCTAssertFalse(visibleAddress.isNull, "Address must remain reachable at \(position)")
                        XCTAssertGreaterThan(visibleAddress.height, 0)
                        XCTAssertGreaterThanOrEqual(visibleAddress.minY, view.navigationBar.frame.maxY)
                        XCTAssertLessThanOrEqual(visibleAddress.maxY, view.copyButton.frame.minY + 1)
                        if position == "start" {
                            XCTAssertEqual(visibleAddress.minY, addressFrame.minY, accuracy: 1)
                        } else {
                            XCTAssertEqual(visibleAddress.maxY, addressFrame.maxY, accuracy: 1)
                        }
                        XCTAssertEqual(view.addressLabel.text, address)
                        XCTAssertEqual(view.addressLabel.accessibilityLabel, address)
                        XCTAssertEqual(view.networkLabel.text, "USDT · Ethereum")
                        XCTAssertTrue(view.copyButton.isUserInteractionEnabled)
                        attachFixture(view, name: "receive-320pt-\(category.rawValue)-address-\(position)")
                    }
                }
            }
        }
    }

    func testWalletNavigationControlsHaveActionNamesAndTouchAreas() {
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            UITraitCollection(preferredContentSizeCategory: category).performAsCurrent {
                let view = WalletMainContainerViewLayout()
                view.locale = Locale(identifier: "en")
                view.bind(viewModel: WalletMainContainerViewModel(walletName: "My wallet", selectedFilter: "Ethereum", selectedFilterImage: nil, address: "0x1234567890abcdef1234567890abcdef12345678", accountScoreViewModel: nil))
                let balance = BalanceInfoViewLayout()
                balance.bind(viewModel: BalanceInfoViewModel(dayChangeAttributedString: NSAttributedString(string: "+$12.34 (1.2%)"), balanceString: "$12,345.67", infoButtonEnabled: true))
                view.addBalance(balance)
                let controller = UIViewController()
                controller.view = view
                withVisibleFixture(controller, category: category) {
                    for control in [view.switchWalletButton, view.searchButton, view.scanQRButton, view.selectNetworkButton] {
                        XCTAssertGreaterThanOrEqual(control.bounds.height, 44)
                        XCTAssertGreaterThanOrEqual(control.bounds.width, 44)
                        XCTAssertFalse(control.accessibilityLabel?.isEmpty ?? true)
                        let frame = control.convert(control.bounds, to: view)
                        XCTAssertGreaterThanOrEqual(frame.minX, 0)
                        XCTAssertLessThanOrEqual(frame.maxX, view.bounds.width)
                    }
                    let walletFrame = view.switchWalletButton.convert(view.switchWalletButton.bounds, to: view)
                    let networkFrame = view.selectNetworkButton.convert(view.selectNetworkButton.bounds, to: view)
                    XCTAssertLessThanOrEqual(walletFrame.maxY, networkFrame.minY)
                    let pageContainer = view.pageViewController.view.superview!
                    XCTAssertGreaterThanOrEqual(pageContainer.bounds.height, 200,
                        "The wallet header must leave a usable asset viewport at maximum text size")
                    if category.isAccessibilityCategory {
                        XCTAssertGreaterThan(view.headerScrollView.contentSize.height, view.headerScrollView.bounds.height)
                        view.headerScrollView.setContentOffset(CGPoint(
                            x: 0, y: view.headerScrollView.contentSize.height - view.headerScrollView.bounds.height
                        ), animated: false)
                        view.layoutIfNeeded()
                        let scoreFrame = view.accountScoreView.convert(view.accountScoreView.bounds, to: view)
                        XCTAssertLessThanOrEqual(scoreFrame.maxY, pageContainer.frame.minY)
                        XCTAssertGreaterThanOrEqual(view.accountScoreView.starView.bounds.height,
                            view.accountScoreView.starView.settings.textFont.lineHeight)
                        for layer in view.accountScoreView.starView.layer.sublayers ?? [] {
                            XCTAssertGreaterThanOrEqual(layer.frame.minY, 0)
                            XCTAssertLessThanOrEqual(layer.frame.maxY, view.accountScoreView.starView.bounds.height)
                        }
                    }
                    let labels = (descendants(in: balance) + descendants(in: view.selectNetworkButton)
                        + descendants(in: view.addressCopyableLabel)).compactMap { $0 as? UILabel }
                    XCTAssertTrue(labels.contains { $0.text == "$12,345.67" })
                    for label in labels {
                        let frame = label.convert(label.bounds, to: view)
                        XCTAssertGreaterThanOrEqual(frame.minX, 0)
                        XCTAssertLessThanOrEqual(frame.maxX, view.bounds.width)
                        XCTAssertGreaterThanOrEqual(label.bounds.height + 1, label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
                    }
                    attachFixture(view, name: "wallet-header-balance-320pt-\(category.rawValue)")
                }
            }
        }
    }

    func testTypographyUsesPreferredContentSizeRatherThanScreenHeight() {
        var standard: CGFloat = 0
        var accessible: CGFloat = 0
        UITraitCollection(preferredContentSizeCategory: .large).performAsCurrent { standard = UIFont.p1Paragraph.pointSize }
        UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge).performAsCurrent { accessible = UIFont.p1Paragraph.pointSize }
        XCTAssertGreaterThan(accessible, standard)
        XCTAssertEqual(UIFont.systemFont(ofSize: 14).dynamicSize(fromSize: 14, figmaScreenHeight: 2000).pointSize,
                       UIFont.systemFont(ofSize: 14).dynamicSize(fromSize: 14, figmaScreenHeight: 400).pointSize)
    }

    func testSegmentedControlCanLayoutBeforeConfigurationAndUsesLocalBounds() {
        let control = FWSegmentedControl(frame: CGRect(x: 20, y: 40, width: 280, height: 44))
        control.layoutIfNeeded()
        XCTAssertTrue(descendants(in: control).allSatisfy { $0.frame.origin.x.isFinite && $0.frame.width.isFinite })
        control.setSegmentItems(["Receive", "Request"])
        control.setNeedsLayout()
        control.layoutIfNeeded()
        XCTAssertEqual(control.subviews.first?.frame, control.bounds)
        XCTAssertTrue(descendants(in: control).allSatisfy { $0.frame.origin.x.isFinite && $0.frame.width.isFinite })
    }

    func testUnavailableFeatureHasWorkingRecoveryActions() {
        var actions: [String] = []
        let category = UIContentSizeCategory.accessibilityExtraExtraExtraLarge
        UITraitCollection(preferredContentSizeCategory: category).performAsCurrent {
            let controller = FeatureUnavailableViewController(title: "Swap", message: "Choose a supported network to continue.", icon: UIImage(systemName: "arrow.triangle.2.circlepath"),
                actionTitle: "Choose network", action: { _ in actions.append("network") },
                secondaryActionTitle: "Manage wallets", secondaryAction: { _ in actions.append("wallets") })
            withVisibleFixture(controller, category: category) {
                let buttons = descendants(in: controller.view).compactMap { $0 as? UIButton }
                XCTAssertEqual(buttons.count, 2)
                buttons.forEach { button in
                    XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                    let labels = descendants(in: button).compactMap { $0 as? UILabel }.filter { $0.text?.isEmpty == false }
                    for label in labels {
                        XCTAssertTrue(button.bounds.contains(label.convert(label.bounds, to: button)))
                        XCTAssertGreaterThanOrEqual(label.bounds.height + 1, label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
                    }
                    button.sendActions(for: .touchUpInside)
                }
                XCTAssertEqual(actions, ["network", "wallets"])
                attachFixture(controller.view, name: "unavailable-320pt-maximum-text-top")
                let scroll = descendants(in: controller.view).compactMap { $0 as? UIScrollView }.first!
                scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height)), animated: false)
                controller.view.layoutIfNeeded()
                XCTAssertLessThanOrEqual(buttons.last!.convert(buttons.last!.bounds, to: controller.view).maxY, controller.view.bounds.maxY)
                attachFixture(controller.view, name: "unavailable-320pt-maximum-text-actions")
            }
        }
    }

    private func descendants(in view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(in: $0) }
    }

    private func withVisibleFixture(_ controller: UIViewController, category: UIContentSizeCategory, checks: () -> Void) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        XCTAssertNotNil(scene, "Accessibility layout needs a live window scene")
        let window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: .zero)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        checks()
        window.isHidden = true
        window.rootViewController = nil
    }

    private func attachFixture(_ view: UIView, name: String) {
        let image = UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
