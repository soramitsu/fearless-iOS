import UIKit
import AVFoundation
import BigInt
import SoraFoundation
import IrohaCrypto
import SSFModels
import SSFQRService
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
                XCTAssertEqual(
                    field.accessibilityFrame,
                    UIAccessibility.convertToScreenCoordinates(target.bounds, in: target)
                )
                for point in [CGPoint(x: 24, y: 2), CGPoint(x: 24, y: target.bounds.maxY - 2)] {
                    XCTAssertNotNil(target.hitTest(point, with: nil))
                }
                input.frame.size.width = 240
                controller.view.bounds.origin.y = 24
                input.setNeedsLayout()
                input.layoutIfNeeded()
                XCTAssertEqual(
                    field.accessibilityFrame,
                    UIAccessibility.convertToScreenCoordinates(target.bounds, in: target)
                )
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
                        XCTAssertGreaterThanOrEqual(
                            search.textField.bounds.height + 1,
                            search.textField.font?.lineHeight ?? 0
                        )
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
                    XCTAssertEqual(
                        input.font?.pointSize,
                        UIFont.preferredFont(forTextStyle: .body, compatibleWith: view.traitCollection).pointSize
                    )
                    XCTAssertEqual(input.placeholder, "Search")
                    XCTAssertEqual(input.accessibilityLabel, "Search")
                    input.placeholder = "Search networks"
                    XCTAssertEqual(input.accessibilityLabel, "Search networks")
                    XCTAssertEqual(input.attributedPlaceholder?.string, "Search networks")
                    input.accessibilityLabel = "Find assets"
                    XCTAssertEqual(input.accessibilityLabel, "Find assets")
                    input.accessibilityLabel = nil
                    input.placeholder = "Search"
                    XCTAssertGreaterThanOrEqual(
                        view.manageAssetStubLabel.bounds.height + 1,
                        view.manageAssetStubLabel.sizeThatFits(CGSize(
                            width: view.manageAssetStubLabel.bounds.width,
                            height: .greatestFiniteMagnitude
                        )).height
                    )
                    XCTAssertFalse(input.leftView is UIControl)
                    XCTAssertEqual(input.leftView?.isAccessibilityElement, false)
                    XCTAssertGreaterThanOrEqual(view.container.bounds.height, 160)
                    for filter in ManageAssetsFilter.allCases {
                        view.setVisibilityFilter(filter)
                        view.layoutIfNeeded()
                        let selected = view.visibilityFilterButtons.filter { $0.1.isSelected }
                        XCTAssertEqual(selected.map { $0.0 }, [filter])
                        XCTAssertTrue(selected[0].1.accessibilityTraits.contains(.selected))
                        XCTAssertEqual(selected[0].1.currentTitleColor, R.color.colorPink())
                        XCTAssertTrue(view.visibilityFilterScrollView.bounds.contains(selected[0].1.convert(selected[0].1.bounds, to: view.visibilityFilterScrollView)))
                    }
                    for (_, button) in view.visibilityFilterButtons {
                        XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
                        XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                        XCTAssertFalse(button.currentTitle?.isEmpty ?? true)
                        XCTAssertGreaterThanOrEqual(button.bounds.height + 1, button.titleLabel?.font.lineHeight ?? 0)
                    }
                    view.setVisibilityFilter(.hidden)
                    view.layoutIfNeeded()
                    if category.isAccessibilityCategory {
                        XCTAssertGreaterThan(view.visibilityFilterScrollView.contentSize.width, view.visibilityFilterScrollView.bounds.width)
                    }
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
                let size = cell.contentView.systemLayoutSizeFitting(
                    CGSize(width: 320, height: 0),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
                XCTAssertGreaterThan(size.height, 55)
                cell.frame.size.height = size.height
                cell.setNeedsLayout()
                cell.layoutIfNeeded()
                for label in [cell.symbolLabel, cell.chainNameLabel, cell.balanceLabel, cell.fiatBalanceLabel] {
                    XCTAssertGreaterThan(label.bounds.width, 100)
                    XCTAssertGreaterThanOrEqual(
                        label.bounds.height + 1,
                        label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height
                    )
                    XCTAssertTrue(cell.contentView.bounds.contains(label.convert(label.bounds, to: cell.contentView)))
                }
                attachFixture(cell, name: "manage-assets-row-320pt-maximum-text")
                let header = AssetManagementTableHeaderView(reuseIdentifier: nil)
                header.symbolLabel.text = "Long grouped token name"
                header.countLabel.text = "123 networks"
                controller.view.addSubview(header)
                header.frame = CGRect(x: 0, y: 0, width: 320, height: 55)
                header.layoutIfNeeded()
                let headerSize = header.contentView.systemLayoutSizeFitting(
                    CGSize(width: 320, height: 0),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
                header.frame.size.height = headerSize.height
                header.setNeedsLayout()
                header.layoutIfNeeded()
                XCTAssertGreaterThan(headerSize.height, 55)
                for label in [header.symbolLabel, header.countLabel] {
                    XCTAssertGreaterThanOrEqual(
                        label.bounds.height + 1,
                        label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height
                    )
                    let labelFrame = label.convert(label.bounds, to: header.contentView)
                    let arrowFrame = header.imageView.convert(header.imageView.bounds, to: header.contentView)
                    XCTAssertTrue(header.contentView.bounds.contains(labelFrame))
                    XCTAssertLessThanOrEqual(labelFrame.maxY + 8, arrowFrame.minY)
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
                        XCTAssertGreaterThanOrEqual(
                            view.titleLabel.bounds.height + 1,
                            view.titleLabel.sizeThatFits(CGSize(width: view.titleLabel.bounds.width, height: .greatestFiniteMagnitude)).height
                        )
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
                        XCTAssertGreaterThanOrEqual(
                            label.bounds.height + 1,
                            label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height
                        )
                        XCTAssertLessThanOrEqual(label.convert(label.bounds, to: view).maxY, view.searchTextField.convert(view.searchTextField.bounds, to: view).minY)
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
                        let copyFrame = view.copyButton.convert(view.copyButton.bounds, to: view)
                        XCTAssertLessThanOrEqual(visibleAddress.maxY, copyFrame.minY + 1)
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
                    XCTAssertGreaterThanOrEqual(
                        pageContainer.bounds.height,
                        200,
                        "The wallet header must leave a usable asset viewport at maximum text size"
                    )
                    if category.isAccessibilityCategory {
                        XCTAssertGreaterThan(view.headerScrollView.contentSize.height, view.headerScrollView.bounds.height)
                        view.headerScrollView.setContentOffset(CGPoint(
                            x: 0, y: view.headerScrollView.contentSize.height - view.headerScrollView.bounds.height
                        ), animated: false)
                        view.layoutIfNeeded()
                        let scoreFrame = view.accountScoreView.convert(view.accountScoreView.bounds, to: view)
                        XCTAssertLessThanOrEqual(scoreFrame.maxY, pageContainer.frame.minY)
                        XCTAssertGreaterThanOrEqual(
                            view.accountScoreView.starView.bounds.height,
                            view.accountScoreView.starView.settings.textFont.lineHeight
                        )
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
        XCTAssertEqual(
            UIFont.systemFont(ofSize: 14).dynamicSize(fromSize: 14, figmaScreenHeight: 2000).pointSize,
            UIFont.systemFont(ofSize: 14).dynamicSize(fromSize: 14, figmaScreenHeight: 400).pointSize
        )
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
            let controller = FeatureUnavailableViewController(
                title: "Swap",
                message: "Choose a supported network to continue.",
                icon: UIImage(systemName: "arrow.triangle.2.circlepath"),
                actionTitle: "Choose network",
                action: { _ in actions.append("network") },
                secondaryActionTitle: "Manage wallets",
                secondaryAction: { _ in actions.append("wallets") }
            )
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

@MainActor
final class WalletHeaderPresentationTests: XCTestCase {
    private let languages = ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"]
    private let categories: [UIContentSizeCategory] = [.large, .accessibilityExtraExtraExtraLarge]
    private let address = "0x1234567890abcdef1234567890abcdef12345678"
    private let network = "Synthetic Long Network · Alpha Beta Gamma"

    func testWalletHeaderAllLocalesAndTextSizes() async throws {
        for language in languages {
            for category in categories {
                let fixture = try makeFixture(language: language, category: category)
                defer { close(fixture.window) }
                let layout = fixture.controller.rootView
                for filtered in [false, true] {
                    let model = makeBalance(language: language, filtered: filtered)
                    fixture.balance.didReceiveViewModel(model)
                    layout.bind(viewModel: .init(
                        walletName: walletName(language),
                        selectedFilter: filtered ? network : R.string.localizable.chainSelectionAllNetworks(
                            preferredLanguages: [language]
                        ),
                        selectedFilterImage: nil,
                        address: filtered ? address : nil,
                        accountScoreViewModel: nil
                    ))
                    await settle(fixture.window)
                    let tag = "\(language)-\(category.rawValue)-\(filtered ? "filtered" : "all")"
                    layout.headerScrollView.setContentOffset(.zero, animated: false)
                    await settle(fixture.window)
                    capture(fixture.window, name: tag + "-top")
                    XCTAssertGreaterThanOrEqual(
                        layout.pageViewControllerContainer.bounds.height,
                        FWAppearance.walletHeaderRestyled || category.isAccessibilityCategory ? 200 : 1,
                        "Restyled and accessibility headers preserve the asset viewport; legacy normal may leave only131pt"
                    )
                    let amount = try XCTUnwrap(labels(fixture.balance.view).first { $0.text == model.balanceString })
                    let expectedAmountFont = FWAppearance.walletHeaderRestyled
                        ? UIFont.fw(.displayXL, compatibleWith: fixture.controller.traitCollection)
                        : UIFont.legacySora(
                            size: 30,
                            weight: .bold,
                            textStyle: .largeTitle,
                            compatibleWith: fixture.controller.traitCollection
                        )
                    XCTAssertEqual(
                        amount.font.pointSize,
                        expectedAmountFont.pointSize,
                        "The portfolio total uses its declared display role"
                    )
                    XCTAssertEqual(
                        amount.font.fontName,
                        expectedAmountFont.fontName,
                        "Amounts use system tabular digits and currency coverage"
                    )
                    for label in labels(fixture.balance.view) where !label.isHidden {
                        if FWAppearance.walletHeaderRestyled || label.text != model.filteredPartString {
                            assertLabelFits(label, in: fixture.window)
                        }
                    }
                    for label in labels(layout.selectNetworkButton) { assertLabelFits(label, in: fixture.window) }
                    let wallet = try XCTUnwrap(labels(layout).first { $0.text == walletName(language) })
                    if FWAppearance.walletHeaderRestyled { assertLabelFits(wallet, in: fixture.window) }
                    else { XCTAssertEqual(wallet.numberOfLines, 2) }
                    let controls: [(UIControl, String)] = [
                        (layout.switchWalletButton, "ux.switch_wallet"),
                        (layout.selectNetworkButton, "ux.choose_network"),
                        (layout.searchButton, "ux.search_assets"),
                        (layout.scanQRButton, "ux.scan_qr")
                    ]
                    for (index, pair) in controls.enumerated() {
                        let (control, key) = pair
                        if FWAppearance.walletHeaderRestyled {
                            XCTAssertNotEqual(
                                text(key, language: language),
                                key,
                                "Every shipped locale has an action name"
                            )
                            XCTAssertEqual(control.accessibilityLabel, text(key, language: language))
                        } else { XCTAssertFalse(control.accessibilityLabel?.isEmpty ?? true) }
                        await reveal(control, in: layout.headerScrollView, window: fixture.window)
                        assertHit(control, in: fixture.window)
                        capture(fixture.window, name: tag + "-action-\(index)")
                        control.sendActions(for: .touchUpInside)
                    }
                    layout.headerScrollView.setContentOffset(CGPoint(
                        x: 0, y: max(
                            0,
                            layout.headerScrollView.contentSize.height - layout.headerScrollView.bounds.height
                        )
                    ), animated: false)
                    await settle(fixture.window)
                    capture(fixture.window, name: tag + "-end")
                    if FWAppearance.walletHeaderRestyled {
                        await reveal(amount, in: layout.headerScrollView, window: fixture.window)
                        capture(fixture.window, name: tag + "-amount")
                        if let caption = labels(fixture.balance.view).first(where: {
                            model.filteredPartString != nil && $0.text == model.filteredPartString
                        }) {
                            await reveal(caption, in: layout.headerScrollView, window: fixture.window)
                            capture(fixture.window, name: tag + "-caption")
                        }
                    }
                    XCTAssertEqual(layout.addressCopyableLabel.isHidden, !filtered)
                    if filtered { XCTAssertEqual(layout.addressCopyableLabel.accessibilityValue, address) }
                    XCTAssertEqual(fixture.output.actions, Array(
                        repeating: ["wallet", "network", "search", "qr"],
                        count: filtered ? 2 : 1
                    ).flatMap { $0 })
                }
            }
        }
    }

    func testWalletHeaderLiveLocaleTypeWidthAndCallbacks() async throws {
        let fixture = try makeFixture(language: "en", category: .large)
        defer { close(fixture.window) }
        let layout = fixture.controller.rootView
        let originalControls = [layout.switchWalletButton, layout.searchButton, layout.scanQRButton]
        fixture.balance.didReceiveViewModel(makeBalance(language: "en", filtered: true))
        layout.bind(viewModel: .init(
            walletName: walletName("en"),
            selectedFilter: network,
            selectedFilterImage: nil,
            address: address,
            accountScoreViewModel: nil
        ))
        await settle(fixture.window)
        fixture.localization.selectedLocalization = "ja"
        fixture.balance.didReceiveViewModel(makeBalance(language: "ja", filtered: true))
        layout.bind(viewModel: .init(
            walletName: walletName("ja"),
            selectedFilter: network,
            selectedFilterImage: nil,
            address: address,
            accountScoreViewModel: nil
        ))
        if #available(iOS 17.0, *) {
            fixture.window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        }
        for width: CGFloat in [640, 320] {
            fixture.window.frame.size.width = width
            await settle(fixture.window)
            capture(fixture.window, name: "live-ja-AX5-width-\(Int(width))-top")
            if FWAppearance.walletHeaderRestyled {
                XCTAssertEqual(layout.selectNetworkButton.accessibilityLabel, text("ux.choose_network", language: "ja"))
            } else { XCTAssertFalse(layout.selectNetworkButton.accessibilityLabel?.isEmpty ?? true) }
            for label in labels(fixture.balance.view)
                where !label.isHidden { assertLabelFits(label, in: fixture.window) }
            await reveal(layout.searchButton, in: layout.headerScrollView, window: fixture.window)
            assertHit(layout.searchButton, in: fixture.window)
        }
        for (index, control) in [layout.switchWalletButton, layout.searchButton, layout.scanQRButton].enumerated() {
            XCTAssertTrue(control === originalControls[index])
        }
        layout.selectNetworkButton.sendActions(for: .touchUpInside)
        layout.searchButton.sendActions(for: .touchUpInside)
        layout.switchWalletButton.sendActions(for: .touchUpInside)
        layout.scanQRButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(fixture.output.actions, ["network", "search", "wallet", "qr"])
        // Read only the synthetic value this app writes; reading prior clipboard items can
        // wait for the simulator privacy prompt and is unrelated to the copy callback.
        defer { UIPasteboard.general.string = nil }
        await reveal(layout.addressCopyableLabel, in: layout.headerScrollView, window: fixture.window)
        XCTAssertTrue(layout.addressCopyableLabel.accessibilityActivate())
        XCTAssertEqual(UIPasteboard.general.string, address)
        XCTAssertEqual(fixture.output.actions.last, "copy")
        capture(fixture.window, name: "live-ja-AX5-address")
        fixture.balance.didReceiveViewModel(nil)
        await settle(fixture.window)
        fixture.balance.didReceiveViewModel(makeBalance(language: "ja", filtered: false))
        layout.bind(viewModel: .init(
            walletName: walletName("ja"),
            selectedFilter: "All networks",
            selectedFilterImage: nil,
            address: nil,
            accountScoreViewModel: nil
        ))
        await settle(fixture.window)
        XCTAssertTrue(layout.addressCopyableLabel.isHidden)
        XCTAssertTrue(
            labels(fixture.balance.view)
                .contains {
                    !$0.isHidden && $0.alpha == 1 && $0.text == makeBalance(language: "ja", filtered: false)
                        .balanceString
                }
        )
        XCTAssertFalse(labels(fixture.balance.view).contains { !$0.isHidden && $0.text?.contains(network) == true })
        capture(fixture.window, name: "live-ja-AX5-loading-to-all")
    }

    func testFilteredBalanceCaptionUsesRequestedLocale() throws {
        for language in languages {
            let model = makeBalance(language: language, filtered: true)
            let format = FWAppearance.walletHeaderRestyled
                ? text("portfolio.header.showing_filtered", language: language)
                : Bundle.main.localizedString(
                    forKey: "portfolio.header.showing_filtered",
                    value: nil,
                    table: "Localizable"
                )
            let marker = format.components(separatedBy: "%@").first ?? ""
            XCTAssertTrue(
                model.filteredPartString?.hasPrefix(marker) == true,
                "Selected locale \(language) must control the factory caption"
            )
            XCTAssertTrue(model.filteredPartString?.contains(network) == true)
            XCTAssertNil(makeBalance(language: language, filtered: false).filteredPartString)
        }
    }

    func testWalletNetworkTextInsideRoundedMask() async throws {
        guard FWAppearance.walletHeaderRestyled else { return }
        let fixture = try makeFixture(language: "en", category: .accessibilityExtraExtraExtraLarge)
        defer { close(fixture.window) }
        let layout = fixture.controller.rootView
        layout.bind(viewModel: .init(
            walletName: walletName("en"),
            selectedFilter: network,
            selectedFilterImage: nil,
            address: nil,
            accountScoreViewModel: nil
        ))
        await settle(fixture.window)
        let button = layout.selectNetworkButton
        await reveal(button, in: layout.headerScrollView, window: fixture.window)
        let title = try XCTUnwrap(labels(button).first { $0.text == network })
        let frame = title.convert(title.bounds, to: button).insetBy(dx: 0.5, dy: 0.5)
        let mask = UIBezierPath(roundedRect: button.bounds, cornerRadius: button.layer.cornerRadius)
        for point in [CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.minY),
                      CGPoint(x: frame.minX, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.maxY)] {
            XCTAssertTrue(mask.contains(point), "Rendered rounded mask must contain the complete multiline title")
        }
        capture(fixture.window, name: "network-rounded-mask-AX5")
    }

    func testPortfolioTypographyIsOptInAndLocaleLookupHasFallbacks() throws {
        let layout = BalanceInfoViewLayout()
        let model = makeBalance(language: "en", filtered: false)
        layout.bind(viewModel: model)
        let amount = try XCTUnwrap(labels(layout).first { $0.text == model.balanceString })
        XCTAssertEqual(amount.font.fontName, UIFont.h1Title.fontName)
        XCTAssertEqual(amount.font.pointSize, UIFont.h1Title.pointSize)
        XCTAssertEqual(
            PortfolioHeaderText.string("ux.choose_network", locale: Locale(identifier: "en_US")),
            text("ux.choose_network", language: "en")
        )
        XCTAssertEqual(
            PortfolioHeaderText.string("ux.choose_network", locale: Locale(identifier: "zz-ZZ")),
            text("ux.choose_network", language: "en")
        )
    }

    func testWalletHeaderInitialLocaleAndLiveBoldText() async throws {
        guard FWAppearance.walletHeaderRestyled else { return }
        let fixture = try makeFixture(language: "ru", category: .large)
        defer { close(fixture.window) }
        XCTAssertEqual(fixture.controller.rootView.locale.identifier, "ru")
        let model = makeBalance(language: "ru", filtered: true)
        fixture.balance.didReceiveViewModel(model)
        await settle(fixture.window)
        let amount = try XCTUnwrap(labels(fixture.balance.view).first { $0.text == model.balanceString })
        let price = try XCTUnwrap(
            labels(fixture.balance.view)
                .first { $0.text == model.dayChangeAttributedString?.string }
        )
        XCTAssertLessThanOrEqual(amount.frame.maxY, price.convert(price.bounds, to: amount.superview).minY)
        XCTAssertTrue(amount.accessibilityTraits.contains(.header))
        let regular = try XCTUnwrap(amount.font)
        func weight(_ font: UIFont) -> CGFloat {
            (font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any])?[.weight] as? CGFloat ??
                0
        }
        if #available(iOS 17.0, *) { fixture.window.traitOverrides.legibilityWeight = .bold }
        await settle(fixture.window)
        XCTAssertGreaterThan(weight(amount.font), weight(regular))
        XCTAssertEqual(amount.font.pointSize, regular.pointSize)
        assertLabelFits(amount, in: fixture.window)
        capture(fixture.window, name: "live-ru-bold")
        if #available(iOS 17.0, *) { fixture.window.traitOverrides.legibilityWeight = .regular }
        await settle(fixture.window)
        XCTAssertEqual(amount.font.fontName, regular.fontName)
        XCTAssertEqual(amount.font.pointSize, regular.pointSize)
    }

    private func makeBalance(language: String, filtered: Bool) -> BalanceInfoViewModel {
        let wallet = AccountGenerator.generateMetaAccount()
        let info = WalletBalanceInfo(
            totalFiatValue: 12345.67, enabledAssetFiatBalance: 12345.67,
            dayChangePercent: 0.012, dayChangeValue: 148.20,
            totalDayChangePercent: 0.012, totalDayChangeValue: 148.20,
            currency: wallet.selectedCurrency, prices: [], accountInfos: [:], exclusions: .init(),
            filteredPart: filtered ? .init(
                filter: .chain("synthetic-chain"),
                networkName: network,
                fiatBalance: 1620
            ) : nil
        )
        return BalanceInfoViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
            .buildBalanceInfo(
                with: .networkManagement(wallet: wallet), balances: [wallet.metaId: info],
                infoButtonEnabled: false, locale: Locale(identifier: language)
            )
    }

    private struct Fixture {
        let window: UIWindow
        let controller: WalletMainContainerViewController
        let balance: BalanceInfoViewController
        let output: WalletHeaderRecordingOutput
        let localization: LocalizationManager
    }

    private func makeFixture(language: String, category: UIContentSizeCategory) throws -> Fixture {
        let localization = try XCTUnwrap(LocalizationManager(localization: language))
        let balanceOutput = WalletHeaderBalanceOutput()
        let balance = BalanceInfoViewController(output: balanceOutput, localizationManager: localization)
        let output = WalletHeaderRecordingOutput()
        let controller = WalletMainContainerViewController(
            balanceInfoViewController: balance, pageControllers: [UIViewController(), UIViewController()],
            output: output, localizationManager: localization
        )
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        window.traitCollection.performAsCurrent {
            window.rootViewController = controller
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
        }
        return Fixture(
            window: window,
            controller: controller,
            balance: balance,
            output: output,
            localization: localization
        )
    }

    private func walletName(_ language: String) -> String {
        language == "ja" ? "検証用ウォレット・長い表示名" : "Synthetic wallet · Long visible name"
    }

    private func text(_ key: String, language: String) -> String {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private func labels(_ view: UIView) -> [UILabel] { descendants(view).compactMap { $0 as? UILabel } }
    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }
    private func close(_ window: UIWindow) { window.isHidden = true; window.rootViewController = nil }
    private func settle(_ window: UIWindow) async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        window.layoutIfNeeded()
    }

    private func reveal(_ target: UIView, in scroll: UIScrollView, window: UIWindow) async {
        scroll.scrollRectToVisible(target.convert(target.bounds, to: scroll), animated: false)
        await settle(window)
        let viewport = scroll.convert(scroll.bounds.inset(by: scroll.adjustedContentInset), to: window)
        let frame = target.convert(target.bounds, to: window)
        XCTAssertGreaterThanOrEqual(frame.minY, viewport.minY - 0.5)
        XCTAssertLessThanOrEqual(frame.maxY, viewport.maxY + 0.5)
        XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX - 0.5)
        XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX + 0.5)
    }

    private func assertHit(
        _ control: UIControl,
        in window: UIWindow,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(control.bounds.width, 44, file: file, line: line)
        XCTAssertGreaterThanOrEqual(control.bounds.height, 44, file: file, line: line)
        let point = control.convert(CGPoint(x: control.bounds.midX, y: control.bounds.midY), to: window)
        let hit = window.hitTest(point, with: nil)
        XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true, file: file, line: line)
    }

    private func assertLabelFits(
        _ label: UILabel,
        in window: UIWindow,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = UILabel()
        text.font = label.font
        text.numberOfLines = 0
        text.attributedText = label.attributedText
        let fit = text.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
        XCTAssertLessThanOrEqual(
            fit.height,
            label.bounds.height + 0.5,
            "Complete label height: \(label.text ?? "")",
            file: file,
            line: line
        )
        let frame = label.convert(label.bounds, to: window)
        XCTAssertGreaterThanOrEqual(frame.minX, -0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, window.bounds.width + 0.5, file: file, line: line)
    }

    private func capture(_ window: UIWindow, name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "wallet-header-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
        let metrics = labels(window).map { label in
            ["text": label.text ?? "", "font": label.font.fontName, "pointSize": label.font.pointSize,
             "bounds": NSCoder.string(for: label.bounds),
             "frame": NSCoder.string(for: label.convert(label.bounds, to: window)),
             "hidden": label.isHidden] as [String: Any]
        }
        if let data = try? JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys]) {
            let record = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            record.name = "wallet-header-" + name + "-metrics"
            record.lifetime = .keepAlways
            add(record)
        }
    }
}

private final class WalletHeaderBalanceOutput: BalanceInfoViewOutput {
    func didLoad(view _: BalanceInfoViewInput) {}
}

private final class WalletHeaderRecordingOutput: WalletMainContainerViewOutput {
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

@MainActor
final class ReceivePresentationTests: XCTestCase {
    private let languages = ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"]
    private let address = "0x2222222222222222222222222222222222222222"

    func testActualReceiveAndRequestAcrossLocalesAndTextSizes() async throws {
        try XCTSkipUnless(FWAppearance.receivePresentationRestyled, "Adaptive presentation is compiled out")
        for language in languages {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                for request in [false, true] {
                    let f = try fixture(language: language, category: category, request: request)
                    defer { close(f.window) }
                    await settle(f.window)
                    let root = f.controller.rootView
                    let name = "receive-presentation-\(request ? "request" : "receive")-\(language)-\(category.rawValue)"
                    capture(f.controller, name: name + "-top")
                    XCTAssertEqual(root.networkLabel.text, "\(f.model.asset) · \(f.model.networkName)")
                    XCTAssertEqual(root.addressLabel.text, f.model.address)
                    XCTAssertEqual(root.addressLabel.accessibilityLabel, f.model.address)
                    XCTAssertTrue(root.qrView.qrImageView.image === f.image)
                    assertLabelsFit(root.navigationBar)
                    assertFont(root.networkLabel, .titleS, language)
                    assertFont(root.networkInstructionLabel, .bodyM, language)
                    assertFont(root.addressLabel, .monoM, language)
                    if request {
                        await reveal(root.segmentedControl, fixture: f)
                        assertHit(root.segmentedControl, window: f.window)
                        assertLabelsFit(root.segmentedControl)
                        try tapSegment(1, fixture: f)
                        await settle(f.window, duration: 550_000_000)
                        XCTAssertFalse(root.amountView.isHidden)
                        await reveal(root.amountView, fixture: f)
                        assertLabelsFit(root.amountView)
                        assertFont(root.amountView.textField, .displayL, language)
                        XCTAssertEqual(root.amountView.inputFieldText, f.input.displayAmount)
                        root.amountView.selectHandler?()
                        XCTAssertEqual(f.output.assetSelections, 1)
                        capture(f.controller, name: name + "-amount")
                    } else {
                        XCTAssertTrue(root.segmentedControl.isHidden)
                        XCTAssertTrue(root.amountView.isHidden)
                    }
                    for (suffix, target) in [("network", root.networkInstructionLabel as UIView), ("qr", root.qrView), ("address", root.addressLabel)] {
                        await reveal(target, fixture: f)
                        assertLabelsFit(target)
                        XCTAssertLessThanOrEqual(target.bounds.width, 288)
                        capture(f.controller, name: name + "-" + suffix)
                    }
                    XCTAssertGreaterThan(root.qrView.qrImageView.bounds.width, 0)
                    XCTAssertEqual(root.qrView.qrImageView.bounds.width, root.qrView.qrImageView.bounds.height, accuracy: 0.5)
                    XCTAssertTrue(root.qrView.bounds.contains(root.qrView.qrImageView.frame))
                    // Read only this test app's own copy result; external pasteboard reads can require user consent.
                    UIPasteboard.general.string = "Receive copy fixture"
                    await reveal(root.copyButton, fixture: f)
                    assertHit(root.copyButton, window: f.window)
                    assertLabelsFit(root.copyButton)
                    root.copyButton.sendActions(for: .touchUpInside)
                    XCTAssertEqual(UIPasteboard.general.string, f.model.address)
                    XCTAssertEqual(f.output.closes, 1)
                    await reveal(root.shareButton, fixture: f)
                    assertHit(root.shareButton, window: f.window)
                    assertLabelsFit(root.shareButton)
                    root.shareButton.sendActions(for: .touchUpInside)
                    XCTAssertEqual(f.output.images.count, 1)
                    XCTAssertTrue(f.output.images.first === f.image)
                    capture(f.controller, name: name + "-actions")
                    root.navigationBar.backButton.sendActions(for: .touchUpInside)
                    XCTAssertEqual(f.output.closes, 2)
                }
            }
        }
    }

    func testLiveLocaleTextSizeWidthAndEditorContinuity() async throws {
        try XCTSkipUnless(FWAppearance.receivePresentationRestyled, "Adaptive presentation is compiled out")
        let f = try fixture(language: "en", category: .large, request: true)
        defer { close(f.window) }
        await settle(f.window)
        try tapSegment(1, fixture: f)
        await settle(f.window, duration: 550_000_000)
        let root = f.controller.rootView
        let field = root.amountView.textField
        await reveal(field, fixture: f)
        XCTAssertTrue(field.becomeFirstResponder())
        let position = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 3))
        field.selectedTextRange = field.textRange(from: position, to: position)
        let originalText = field.text
        f.localization.selectedLocalization = "ja"
        f.controller.applyLocalization()
        await settle(f.window)
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertEqual(field.text, originalText)
        XCTAssertEqual(field.offset(from: field.beginningOfDocument, to: try XCTUnwrap(field.selectedTextRange).start), 3)
        XCTAssertEqual(root.navigationTitleLabel.text, R.string.localizable.walletReceiveNavigationTitle("XOR", preferredLanguages: ["ja"]))
        XCTAssertEqual(root.networkInstructionLabel.text, "このアドレスには XOR を SORA Testnet ネットワークでのみ送金してください。")
        for width: CGFloat in [568, 320] {
            f.window.frame.size.width = width
            if #available(iOS 17.0, *) { f.window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
            await settle(f.window)
            assertFont(root.networkLabel, .titleS, "ja")
            await reveal(root.networkInstructionLabel, fixture: f)
            assertLabelsFit(root.networkInstructionLabel)
            await reveal(field, fixture: f)
            assertFont(field, .displayL, "ja")
            XCTAssertTrue(field.isFirstResponder)
            XCTAssertEqual(field.text, originalText)
            capture(f.controller, name: "receive-presentation-live-ja-AX5-\(Int(width))")
        }
        let regular = try XCTUnwrap(field.font)
        if #available(iOS 17.0, *) { f.window.traitOverrides.legibilityWeight = .bold }
        await settle(f.window)
        let bold = try XCTUnwrap(field.font)
        XCTAssertEqual(bold.pointSize, regular.pointSize, accuracy: 0.5)
        XCTAssertGreaterThan(weight(bold), weight(regular))
        if #available(iOS 17.0, *) {
            f.window.traitOverrides.legibilityWeight = .regular
            f.window.traitOverrides.preferredContentSizeCategory = .large
        }
        await settle(f.window)
        assertFont(field, .displayL, "ja")
        XCTAssertTrue(root.qrView.qrImageView.image === f.image)
        XCTAssertEqual(root.addressLabel.text, f.model.address)
    }

    func testAmountModelReplacementDetachesOldObserverAndPreservesCallbacks() async throws {
        let f = try fixture(language: "en", category: .large, request: true)
        defer { close(f.window) }
        await settle(f.window)
        let replacement = input(amount: "42.5")
        f.controller.didReceive(amountInputViewModel: replacement)
        f.output.amounts.removeAll()
        f.input.didUpdateAmount(to: 123)
        XCTAssertTrue(f.output.amounts.isEmpty, "Old model must not update the current request or trigger QR regeneration")
        replacement.didUpdateAmount(to: 24)
        XCTAssertEqual(f.output.amounts, [24])
        XCTAssertEqual(f.controller.rootView.amountView.inputFieldText, replacement.displayAmount)
        f.controller.didReceive(amountInputViewModel: nil)
        f.output.amounts.removeAll()
        replacement.didUpdateAmount(to: 99)
        XCTAssertTrue(f.output.amounts.isEmpty, "Detached input must not submit a spurious zero request")
        f.controller.didReceive(amountInputViewModel: replacement)
        f.controller.didSelect(on: AmountInputAccessoryView(), percentage: 0.5)
        XCTAssertEqual(f.output.percentages, [0.5])
    }

    func testActiveRequestEditorAndActionsStayAboveKeyboardNotificationFrame() async throws {
        try XCTSkipUnless(FWAppearance.receivePresentationRestyled, "Adaptive presentation is compiled out")
        let f = try fixture(language: "ja", category: .accessibilityExtraExtraExtraLarge, request: true)
        defer { close(f.window) }
        await settle(f.window)
        try tapSegment(1, fixture: f)
        await settle(f.window, duration: 550_000_000)
        let root = f.controller.rootView
        let field = root.amountView.textField
        await reveal(field, fixture: f)
        XCTAssertTrue(field.becomeFirstResponder())
        await settle(f.window, duration: 600_000_000)
        let initialText = field.text
        let position = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 3))
        field.selectedTextRange = field.textRange(from: position, to: position)
        let frame = CGRect(x: 0, y: 340.5, width: 320, height: 227.5)
        let info: [AnyHashable: Any] = [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: frame), UIResponder.keyboardAnimationDurationUserInfoKey: 0]
        for name in [UIResponder.keyboardWillShowNotification, UIResponder.keyboardWillChangeFrameNotification] {
            NotificationCenter.default.post(name: name, object: nil, userInfo: info)
            await settle(f.window)
        }
        await reveal(field, fixture: f)
        XCTAssertLessThanOrEqual(field.convert(field.bounds, to: f.controller.view).maxY, 340.5)
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertEqual(field.text, initialText)
        XCTAssertEqual(field.offset(from: field.beginningOfDocument, to: try XCTUnwrap(field.selectedTextRange).start), 3)
        capture(f.controller, name: "receive-presentation-request-ja-AX5-keyboard-editor")
        for control in [root.copyButton, root.shareButton] {
            await reveal(control, fixture: f)
            assertHit(control, window: f.window)
            XCTAssertLessThanOrEqual(control.convert(control.bounds, to: f.controller.view).maxY, 340.5)
            XCTAssertTrue(field.isFirstResponder)
        }
        capture(f.controller, name: "receive-presentation-request-ja-AX5-keyboard-actions")
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil, userInfo: info)
    }

    func testSelectedRequestIndicatorSurvivesLayoutAndLocaleReflow() async throws {
        let f = try fixture(language: "en", category: .large, request: true)
        defer { close(f.window) }
        await settle(f.window)
        try tapSegment(1, fixture: f)
        await settle(f.window, duration: 550_000_000)
        let control = f.controller.rootView.segmentedControl
        for width: CGFloat in [320, 568, 320] {
            f.window.frame.size.width = width
            control.setNeedsLayout()
            await settle(f.window)
            await reveal(control, fixture: f)
            XCTAssertEqual(control.selectedSegmentIndex, 1)
            let slider = try XCTUnwrap(descendants(control).compactMap { $0 as? FWSegmentedControl.SliderView }.first)
            let frame = slider.convert(slider.bounds, to: control)
            XCTAssertEqual(frame.midX, control.bounds.width * 0.75, accuracy: 1, "Selection drawing must track the selected Request segment")
            capture(f.controller, name: "receive-presentation-request-selected-width-\(Int(width))")
        }
    }

    func testAccessibleSegmentsReuseAndExactReplacementIdentity() async throws {
        try XCTSkipUnless(FWAppearance.receivePresentationRestyled, "Adaptive presentation is compiled out")
        let f = try fixture(language: "ru", category: .accessibilityExtraExtraExtraLarge, request: true)
        defer { close(f.window) }
        await settle(f.window)
        let root = f.controller.rootView
        await reveal(root.segmentedControl, fixture: f)
        let initial = try XCTUnwrap(root.segmentedControl.accessibilityElements as? [UIAccessibilityElement])
        XCTAssertEqual(initial.count, 2)
        for element in initial {
            XCTAssertGreaterThanOrEqual(element.accessibilityFrameInContainerSpace.height, 44)
            XCTAssertGreaterThanOrEqual(element.accessibilityFrameInContainerSpace.width, 44)
            XCTAssertTrue(element.accessibilityTraits.contains(.button))
        }
        XCTAssertTrue(initial[1].accessibilityActivate())
        await settle(f.window, duration: 550_000_000)
        XCTAssertEqual(root.segmentedControl.selectedSegmentIndex, 1)
        XCTAssertFalse(root.amountView.isHidden)
        let selected = try XCTUnwrap(root.segmentedControl.accessibilityElements as? [UIAccessibilityElement])
        XCTAssertTrue(selected[1].accessibilityTraits.contains(.selected))
        XCTAssertFalse(selected[0].accessibilityTraits.contains(.selected))
        root.segmentedControl.isEnabled = false
        XCTAssertFalse(selected[0].accessibilityActivate())
        XCTAssertEqual(root.segmentedControl.selectedSegmentIndex, 1)
        root.segmentedControl.isEnabled = true
        await reveal(root.amountView.textField, fixture: f)
        XCTAssertTrue(root.amountView.textField.becomeFirstResponder())
        let replacementAddress = "0x3333333333333333333333333333333333333333"
        let model = ReceiveAssetViewModel(asset: "ETH", networkName: "Ethereum Sepolia", accountName: "Replacement public wallet", address: replacementAddress, isSora: false)
        let replacementImage = UIImage(systemName: "qrcode")!
        f.controller.didReceive(viewModel: model)
        f.controller.didReceive(assetBalanceViewModel: nil)
        f.controller.didReceive(amountInputViewModel: nil)
        f.controller.didReceive(image: replacementImage)
        await settle(f.window)
        XCTAssertTrue(root.amountView.isHidden)
        XCTAssertTrue(root.segmentedControl.isHidden)
        XCTAssertFalse(root.amountView.textField.isFirstResponder)
        XCTAssertEqual(root.networkLabel.text, "ETH · Ethereum Sepolia")
        XCTAssertEqual(root.addressLabel.text, replacementAddress)
        XCTAssertEqual(root.addressLabel.accessibilityLabel, replacementAddress)
        await reveal(root.copyButton, fixture: f)
        root.copyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(UIPasteboard.general.string, replacementAddress)
        await reveal(root.shareButton, fixture: f)
        root.shareButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(f.output.images.last === replacementImage)
        f.controller.didReceive(viewModel: f.model)
        f.controller.didReceive(assetBalanceViewModel: AssetBalanceViewModel(symbol: "XOR", balance: "22", fiatBalance: nil, price: nil, iconViewModel: nil, selectable: true))
        f.controller.didReceive(amountInputViewModel: f.input)
        await settle(f.window)
        XCTAssertFalse(root.segmentedControl.isHidden)
        XCTAssertFalse(root.amountView.isHidden)
        XCTAssertEqual(root.amountView.textField.text, f.input.displayAmount)
        await reveal(root.segmentedControl, fixture: f)
        let restored = try XCTUnwrap(root.segmentedControl.accessibilityElements as? [UIAccessibilityElement])
        XCTAssertTrue(restored[0].accessibilityActivate())
        await settle(f.window, duration: 550_000_000)
        XCTAssertTrue(root.amountView.isHidden)
        capture(f.controller, name: "receive-presentation-reuse-ru-AX5")
    }

    func testRequestModelRemovalAndRebindKeepControlsConsistent() async throws {
        let f = try fixture(language: "en", category: .large, request: true)
        defer { close(f.window) }
        await settle(f.window)
        let root = f.controller.rootView
        try tapSegment(1, fixture: f)
        await settle(f.window, duration: 550_000_000)
        XCTAssertFalse(root.amountView.isHidden)
        await reveal(root.amountView.textField, fixture: f)
        XCTAssertTrue(root.amountView.textField.becomeFirstResponder())
        f.controller.didReceive(assetBalanceViewModel: nil)
        f.controller.didReceive(amountInputViewModel: nil)
        await settle(f.window)
        XCTAssertTrue(root.segmentedControl.isHidden)
        XCTAssertTrue(root.amountView.isHidden)
        XCTAssertFalse(root.amountView.textField.isFirstResponder)
        XCTAssertTrue(root.amountView.textField.text?.isEmpty ?? true)
        f.controller.didReceive(assetBalanceViewModel: AssetBalanceViewModel(symbol: "XOR", balance: "22", fiatBalance: nil, price: nil, iconViewModel: nil, selectable: true))
        f.controller.didReceive(amountInputViewModel: f.input)
        await settle(f.window)
        XCTAssertFalse(root.segmentedControl.isHidden)
        XCTAssertFalse(root.amountView.isHidden)
        XCTAssertEqual(root.amountView.textField.text, f.input.displayAmount)
        try tapSegment(0, fixture: f)
        await settle(f.window, duration: 550_000_000)
        XCTAssertTrue(root.amountView.isHidden)
        capture(f.controller, name: "receive-presentation-request-model-rebind")
    }

    func testSafeAreaHeaderAndLiveAccessoryLanguage() async throws {
        try XCTSkipUnless(FWAppearance.receivePresentationRestyled, "Adaptive presentation is compiled out")
        let f = try fixture(language: "en", category: .large, request: true)
        defer { close(f.window) }
        await settle(f.window)
        let root = f.controller.rootView
        let back = root.navigationBar.backButton.convert(root.navigationBar.backButton.bounds, to: root.navigationBar)
        XCTAssertTrue(root.navigationBar.bounds.contains(back), "Back must remain inside its header")
        XCTAssertLessThanOrEqual(root.navigationBar.backButton.convert(root.navigationBar.backButton.bounds, to: root).maxY, root.contentView.frame.minY)
        XCTAssertEqual(root.navigationTitleLabel.text, "Receive XOR")
        assertLabelsFit(root.navigationBar)
        let toolbar = try XCTUnwrap(root.amountView.textField.inputAccessoryView as? AmountInputAccessoryView)
        let maxItem = try XCTUnwrap(toolbar.items?.first { $0.action == #selector(AmountInputAccessoryView.actionSelect100) })
        let doneItem = try XCTUnwrap(toolbar.items?.first { $0.action == #selector(AmountInputAccessoryView.actionSelectDone) })
        XCTAssertEqual(maxItem.title, R.string.localizable.commonMax(preferredLanguages: ["en"]).uppercased())
        XCTAssertEqual(doneItem.title, R.string.localizable.commonDone(preferredLanguages: ["en"]))
        try tapSegment(1, fixture: f)
        await settle(f.window, duration: 550_000_000)
        await reveal(root.amountView.textField, fixture: f)
        XCTAssertTrue(root.amountView.textField.becomeFirstResponder())
        f.localization.selectedLocalization = "ja"
        f.controller.applyLocalization()
        await settle(f.window)
        XCTAssertTrue(root.amountView.textField.inputAccessoryView === toolbar)
        XCTAssertTrue(root.amountView.textField.isFirstResponder)
        XCTAssertEqual(maxItem.title, R.string.localizable.commonMax(preferredLanguages: ["ja"]).uppercased())
        XCTAssertEqual(doneItem.title, R.string.localizable.commonDone(preferredLanguages: ["ja"]))
        toolbar.actionSelect50()
        XCTAssertEqual(f.output.percentages, [0.5])
        XCTAssertFalse(root.amountView.textField.isFirstResponder)
        XCTAssertTrue(root.amountView.textField.becomeFirstResponder())
        toolbar.actionSelectDone()
        XCTAssertFalse(root.amountView.textField.isFirstResponder)
    }

    func testLocalizationBeforeViewLoadPreservesLazyLifecycle() throws {
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = ReceiveAndRequestAssetViewController(output: ReceivePresentationOutput(), localizationManager: manager)
        XCTAssertFalse(controller.isViewLoaded)
        controller.applyLocalization()
        XCTAssertFalse(controller.isViewLoaded)
    }

    func testCompiledRollbackKeepsExactIdentityAndRequestCallbacks() async throws {
        try XCTSkipIf(FWAppearance.receivePresentationRestyled, "Requires compiled rollback flag")
        for (language, category) in [("en", UIContentSizeCategory.large), ("ru", .accessibilityExtraExtraExtraLarge)] {
            for request in [false, true] {
                let f = try fixture(language: language, category: category, request: request)
                defer { close(f.window) }
                await settle(f.window)
                let root = f.controller.rootView
                if request {
                    try tapSegment(1, fixture: f)
                    await settle(f.window, duration: 550_000_000)
                    XCTAssertFalse(root.amountView.isHidden)
                    XCTAssertEqual(root.amountView.inputFieldText, f.input.displayAmount)
                }
                XCTAssertEqual(root.addressLabel.text, f.model.address)
                XCTAssertTrue(root.qrView.qrImageView.image === f.image)
                capture(f.controller, name: "receive-presentation-rollback-\(language)-\(category.rawValue)-\(request ? "request" : "receive")")
                await reveal(root.copyButton, fixture: f)
                root.copyButton.sendActions(for: .touchUpInside)
                XCTAssertEqual(UIPasteboard.general.string, f.model.address)
                root.shareButton.sendActions(for: .touchUpInside)
                XCTAssertTrue(f.output.images.last === f.image)
                XCTAssertEqual(f.output.closes, 1)
            }
        }
    }

    private struct Fixture {
        let controller: ReceiveAndRequestAssetViewController
        let output: ReceivePresentationOutput
        let localization: LocalizationManager
        let window: UIWindow
        let input: AmountInputViewModel
        let image: UIImage
        let model: ReceiveAssetViewModel
    }

    private func fixture(language: String, category: UIContentSizeCategory, request: Bool) throws -> Fixture {
        let localization = try XCTUnwrap(LocalizationManager(localization: language))
        let output = ReceivePresentationOutput()
        let controller = ReceiveAndRequestAssetViewController(output: output, localizationManager: localization)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.applyLocalization()
        let displayAddress = request ? try SS58AddressFactory().address(fromAccountId: Data(repeating: 0x22, count: 32), type: 69) : address
        let model = ReceiveAssetViewModel(asset: request ? "XOR" : "USDT", networkName: request ? "SORA Testnet" : "Ethereum Sepolia · ERC-20", accountName: "Public long wallet name", address: displayAddress, isSora: request)
        controller.didReceive(viewModel: model)
        controller.didReceive(assetBalanceViewModel: request ? AssetBalanceViewModel(symbol: model.asset, balance: "123,456.789012", fiatBalance: "$123,456.78", price: "$1.00", iconViewModel: nil, selectable: true) : nil)
        let inputModel = input(amount: "1234.5678")
        controller.didReceive(amountInputViewModel: request ? inputModel : nil)
        let qr = try XCTUnwrap(CIFilter(name: "CIQRCodeGenerator"))
        qr.setValue(Data(displayAddress.utf8), forKey: "inputMessage")
        qr.setValue("H", forKey: "inputCorrectionLevel")
        let code = try XCTUnwrap(qr.outputImage).transformed(by: CGAffineTransform(scaleX: 5, y: 5))
        let image = UIImage(cgImage: try XCTUnwrap(CIContext().createCGImage(code, from: code.extent)))
        controller.didReceive(image: image)
        return Fixture(controller: controller, output: output, localization: localization, window: window, input: inputModel, image: image, model: model)
    }

    private func input(amount: String) -> AmountInputViewModel {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 8
        formatter.usesGroupingSeparator = false
        return AmountInputViewModel(symbol: "USDT", amount: Decimal(string: amount), formatter: formatter, inputLocale: Locale(identifier: "en"), precision: 8)
    }

    private func tapSegment(_ index: Int, fixture: Fixture) throws {
        let control = fixture.controller.rootView.segmentedControl
        let action = NSSelectorFromString("didTapWithTapGesture:")
        XCTAssertTrue(control.responds(to: action), "Fixture uses the production tap recognizer callback")
        guard control.responds(to: action) else { throw NSError(domain: "Receive fixture gesture", code: 1) }
        let point = CGPoint(x: control.bounds.width * (CGFloat(index) + 0.5) / 2, y: control.bounds.midY)
        let tap = ReceivePresentationTap(point: point)
        control.perform(action, with: tap)
        XCTAssertEqual(control.selectedSegmentIndex, index)
    }

    private func assertFont(_ view: UIView, _ role: FWFontStyle, _ language: String) {
        let actual = (view as? UILabel)?.font ?? (view as? UITextField)?.font
        let expected = UIFont.fw(role, locale: Locale(identifier: language), compatibleWith: view.traitCollection)
        XCTAssertEqual(actual?.fontName, expected.fontName)
        XCTAssertEqual(actual?.pointSize ?? 0, expected.pointSize, accuracy: 0.5)
    }

    private func weight(_ font: UIFont) -> CGFloat {
        (font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any])?[.weight] as? CGFloat ?? 0
    }

    private func assertLabelsFit(_ parent: UIView) {
        for label in descendants(parent).compactMap({ $0 as? UILabel }) where visible(label) && label.text?.isEmpty == false {
            let needed = label.sizeThatFits(CGSize(width: label.numberOfLines == 1 ? .greatestFiniteMagnitude : label.bounds.width, height: .greatestFiniteMagnitude))
            if label.numberOfLines == 1 { XCTAssertGreaterThanOrEqual(label.bounds.width + 1, needed.width, label.text ?? "") }
            XCTAssertGreaterThanOrEqual(label.bounds.height + 1, needed.height, label.text ?? "")
            XCTAssertTrue(parent.bounds.insetBy(dx: -1, dy: -1).contains(label.convert(label.bounds, to: parent)), label.text ?? "")
        }
    }

    private func visible(_ view: UIView) -> Bool {
        var item: UIView? = view
        while let current = item { if current.isHidden || current.alpha == 0 { return false }; item = current.superview }
        return true
    }

    private func assertHit(_ control: UIControl, window: UIWindow) {
        XCTAssertGreaterThanOrEqual(control.bounds.width, 44)
        XCTAssertGreaterThanOrEqual(control.bounds.height, 44)
        let point = control.convert(CGPoint(x: control.bounds.midX, y: control.bounds.midY), to: window)
        let hit = window.hitTest(point, with: nil)
        XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true, "Control covered or offscreen")
    }

    private func reveal(_ view: UIView, fixture: Fixture) async {
        let scroll = fixture.controller.rootView.contentView.scrollView
        for _ in 0 ..< 2 {
            if view.isDescendant(of: scroll) { scroll.scrollRectToVisible(view.convert(view.bounds, to: scroll), animated: false) }
            await settle(fixture.window)
        }
    }

    private func settle(_ window: UIWindow, duration: UInt64 = 120_000_000) async {
        try? await Task.sleep(nanoseconds: duration)
        window.layoutIfNeeded()
    }

    private func close(_ window: UIWindow) { window.endEditing(true); window.isHidden = true; window.rootViewController = nil }
    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }

    private func capture(_ controller: UIViewController, name: String) {
        let view = controller.view!
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: view.bounds).image { _ in view.drawHierarchy(in: view.bounds, afterScreenUpdates: true) })
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let rows = descendants(view).compactMap { $0 as? UILabel }.map { ["text": $0.text ?? "", "font": $0.font.fontName, "size": String(Double($0.font.pointSize)), "bounds": NSCoder.string(for: $0.bounds), "frame": NSCoder.string(for: $0.convert($0.bounds, to: view))] }
        if let data = try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]) {
            let metrics = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            metrics.name = name + "-metrics"; metrics.lifetime = .keepAlways; add(metrics)
        }
    }
}

private final class ReceivePresentationOutput: ReceiveAndRequestAssetViewOutput {
    var closes = 0, assetSelections = 0
    var images: [UIImage] = []
    var percentages: [Float] = []
    var amounts: [Decimal] = []
    func didLoad(view _: ReceiveAndRequestAssetViewInput) {}
    func share(qrImage: UIImage) { images.append(qrImage) }
    func close() { closes += 1 }
    func presentAccountOptions() {}
    func didTapSelectAsset() { assetSelections += 1 }
    func selectAmountPercentage(_ percentage: Float) { percentages.append(percentage) }
    func updateAmount(_ newValue: Decimal) { amounts.append(newValue) }
}

private final class ReceivePresentationTap: UITapGestureRecognizer {
    let point: CGPoint
    init(point: CGPoint) { self.point = point; super.init(target: nil, action: nil) }
    override func location(in _: UIView?) -> CGPoint { point }
}

@MainActor
final class ReceiveQRGenerationOwnershipTests: XCTestCase {
    func testOlderImageCannotReplaceNewAmountQR() async throws {
        let f = try fixture()
        let first = expectation(description: "initial QR entered provider")
        let second = expectation(description: "new amount QR entered provider")
        f.qr.started = { index in (index == 0 ? first : second).fulfill() }
        f.presenter.didLoad(view: f.view)
        await fulfillment(of: [first], timeout: 2)
        f.presenter.updateAmount(42)
        await fulfillment(of: [second], timeout: 2)
        let current = UIImage()
        let delivered = expectation(description: "current QR delivered")
        f.view.onImage = { _ in delivered.fulfill() }
        try f.qr.finish(1, result: .success(current))
        await fulfillment(of: [delivered], timeout: 2)
        let stale = expectation(description: "obsolete QR must not be delivered")
        stale.isInverted = true
        f.view.onImage = { _ in stale.fulfill() }
        try f.qr.finish(0, result: .success(UIImage()))
        await fulfillment(of: [stale], timeout: 0.3)
        XCTAssertEqual(f.view.images.count, 1)
        XCTAssertTrue(f.view.images.first === current)
        XCTAssertTrue(f.router.errors.isEmpty)
    }

    func testOlderFailureCannotInterruptSelectedAssetQR() async throws {
        let f = try fixture()
        let first = expectation(description: "old asset QR entered provider")
        let second = expectation(description: "selected asset QR entered provider")
        f.qr.started = { index in (index == 0 ? first : second).fulfill() }
        f.presenter.didLoad(view: f.view)
        await fulfillment(of: [first], timeout: 2)
        let selected = ChainAsset(chain: f.asset.chain, asset: AssetModel(id: "fixture-selected", name: "Selected public asset", symbol: "VAL", precision: 18, currencyId: "fixture-selected", isUtility: false, isNative: false))
        f.presenter.assetSelection(didCompleteWith: selected, contextTag: nil)
        await fulfillment(of: [second], timeout: 2)
        let current = UIImage()
        let delivered = expectation(description: "selected asset QR delivered")
        f.view.onImage = { _ in delivered.fulfill() }
        try f.qr.finish(1, result: .success(current))
        await fulfillment(of: [delivered], timeout: 2)
        let stale = expectation(description: "obsolete error must not be presented")
        stale.isInverted = true
        f.router.onError = { _ in stale.fulfill() }
        try f.qr.finish(0, result: .failure(ReceiveQRFixtureError.failed))
        await fulfillment(of: [stale], timeout: 0.3)
        XCTAssertEqual(f.view.models.last?.asset, "VAL")
        XCTAssertTrue(f.view.images.last === current)
        XCTAssertTrue(f.router.errors.isEmpty)
    }

    func testCloseRetiresPendingImageAndError() async throws {
        for fails in [false, true] {
            let f = try fixture()
            let started = expectation(description: "pending QR entered provider")
            f.qr.started = { _ in started.fulfill() }
            f.presenter.didLoad(view: f.view)
            await fulfillment(of: [started], timeout: 2)
            f.presenter.close()
            XCTAssertEqual(f.router.dismissCount, 1)
            let stale = expectation(description: "closed Receive must not deliver image or error")
            stale.isInverted = true
            f.view.onImage = { _ in stale.fulfill() }
            f.router.onError = { _ in stale.fulfill() }
            try f.qr.finish(0, result: fails ? .failure(ReceiveQRFixtureError.failed) : .success(UIImage()))
            await fulfillment(of: [stale], timeout: 0.3)
            XCTAssertTrue(f.view.images.isEmpty)
            XCTAssertTrue(f.router.errors.isEmpty)
        }
    }

    func testNewAmountInvalidatesPreviouslyVisibleAndShareableQR() async throws {
        let f = try fixture()
        let first = expectation(description: "initial QR entered provider")
        let second = expectation(description: "replacement QR entered provider")
        f.qr.started = { index in (index == 0 ? first : second).fulfill() }
        f.presenter.didLoad(view: f.view)
        await fulfillment(of: [first], timeout: 2)
        let previous = UIImage()
        let initialDelivered = expectation(description: "initial QR delivered")
        f.view.onImage = { _ in initialDelivered.fulfill() }
        try f.qr.finish(0, result: .success(previous))
        await fulfillment(of: [initialDelivered], timeout: 2)
        f.view.onImage = nil
        f.presenter.updateAmount(42)
        XCTAssertNil(f.view.currentImage, "Previous amount QR must be cleared immediately")
        f.presenter.share(qrImage: previous)
        XCTAssertEqual(f.router.shares.count, 0, "Previous QR must not be shareable while replacement is pending")
        await fulfillment(of: [second], timeout: 2)
        guard case let .addressInfo(info) = try f.qr.request(1) else {
            return XCTFail("Sora Request must carry account/asset/amount payload")
        }
        XCTAssertEqual(info.assetId, "fixture-xor")
        XCTAssertEqual(info.amount, "42")
        XCTAssertEqual(info.username, "Public QR fixture")
        XCTAssertEqual(info.rawPublicKey, Data(repeating: 0x22, count: 32))
        XCTAssertEqual(info.address, f.view.models.last?.address)
        let current = UIImage()
        let replacementDelivered = expectation(description: "replacement QR delivered")
        f.view.onImage = { _ in replacementDelivered.fulfill() }
        try f.qr.finish(1, result: .success(current))
        await fulfillment(of: [replacementDelivered], timeout: 2)
        XCTAssertTrue(f.view.currentImage === current)
        f.presenter.share(qrImage: current)
        XCTAssertEqual(f.router.shares.count, 1)
    }

    func testCurrentGenerationErrorIsStillPresented() async throws {
        let f = try fixture()
        let started = expectation(description: "current QR entered provider")
        f.qr.started = { _ in started.fulfill() }
        let delivered = expectation(description: "current error delivered")
        f.router.onError = { _ in delivered.fulfill() }
        f.presenter.didLoad(view: f.view)
        await fulfillment(of: [started], timeout: 2)
        try f.qr.finish(0, result: .failure(ReceiveQRFixtureError.failed))
        await fulfillment(of: [delivered], timeout: 2)
        XCTAssertEqual(f.router.errors.count, 1)
        XCTAssertTrue(f.view.images.isEmpty)
    }

    func testActualGeneratedRequestQRDecodesExactPublicPayload() async throws {
        let service = WalletQRService()
        let f = try fixture(qrService: service)
        let initial = expectation(description: "real provider produced initial QR")
        f.view.onImage = { _ in initial.fulfill() }
        f.presenter.didLoad(view: f.view)
        await fulfillment(of: [initial], timeout: 3)
        let replacement = expectation(description: "real provider produced Request QR")
        f.view.onImage = { _ in replacement.fulfill() }
        f.presenter.updateAmount(Decimal(string: "42.125")!)
        await fulfillment(of: [replacement], timeout: 3)
        let image = try XCTUnwrap(f.view.currentImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "receive-actual-provider-public-request-42.125"
        attachment.lifetime = .keepAlways
        add(attachment)
        guard case let .qrInfo(.sora(info)) = try service.extractQrCode(from: image) else {
            return XCTFail("Actual generated Request QR must decode as Sora")
        }
        XCTAssertEqual(info.amount, "42.125")
        XCTAssertEqual(info.assetId, "fixture-xor")
        XCTAssertEqual(info.username, "Public QR fixture")
        XCTAssertEqual(info.rawPublicKey, Data(repeating: 0x22, count: 32))
        XCTAssertEqual(info.address, f.view.models.last?.address)
        f.presenter.share(qrImage: image)
        XCTAssertTrue(f.router.shares.first?.first as? UIImage === image)
        XCTAssertEqual(f.router.shares.first?.last as? String, info.address)
        f.presenter.close()
    }

    func testActualControllerClearsImageAndDisablesShareUntilReplacement() throws {
        let output = ReceivePresentationOutput()
        let controller = ReceiveAndRequestAssetViewController(output: output, localizationManager: try XCTUnwrap(LocalizationManager(localization: "en")))
        controller.loadViewIfNeeded()
        let old = UIImage()
        controller.didReceive(image: old)
        XCTAssertTrue(controller.rootView.shareButton.isEnabled)
        controller.didStartQRGeneration()
        XCTAssertNil(controller.rootView.qrView.qrImageView.image)
        XCTAssertEqual(controller.rootView.qrView.alpha, 0)
        XCTAssertFalse(controller.rootView.shareButton.isEnabled)
        controller.rootView.shareButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(output.images.isEmpty)
        let current = UIImage()
        controller.didReceive(image: current)
        XCTAssertEqual(controller.rootView.qrView.alpha, 1)
        XCTAssertTrue(controller.rootView.shareButton.isEnabled)
        controller.rootView.shareButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(output.images.last === current)
    }

    func testInitialSoraReceiveQRDecodesWithoutAnAmount() async throws {
        let service = WalletQRService()
        let f = try fixture(qrService: service)
        let delivered = expectation(description: "initial Sora Receive QR generated")
        f.view.onImage = { _ in delivered.fulfill() }
        f.presenter.didLoad(view: f.view)
        await fulfillment(of: [delivered], timeout: 3)
        let image = try XCTUnwrap(f.view.currentImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "receive-actual-provider-public-no-amount"
        attachment.lifetime = .keepAlways
        add(attachment)
        guard case let .qrInfo(.sora(info)) = try service.extractQrCode(from: image) else {
            return XCTFail("Initial Sora Receive QR must decode")
        }
        XCTAssertTrue(info.amount == nil || info.amount == "")
        XCTAssertEqual(info.assetId, "fixture-xor")
        XCTAssertEqual(info.address, f.view.models.last?.address)
        guard case let .qrInfo(.sora(legacyInfo)) = try QRServiceDefault().extractQrCode(from: image) else {
            return XCTFail("New no-amount QR must remain readable by the installed six-field decoder")
        }
        XCTAssertEqual(legacyInfo.amount, "")
        XCTAssertEqual(legacyInfo.address, info.address)
        XCTAssertEqual(legacyInfo.assetId, info.assetId)
        f.presenter.close()
    }

    func testLegacyFiveFieldReceiveImageRemainsReadable() async throws {
        let legacy = SoraQRInfo(prefix: "substrate", address: "public-legacy-address", rawPublicKey: Data(repeating: 0x22, count: 32), username: "Public legacy wallet", assetId: "fixture-xor", amount: nil)
        let image = try await QRServiceDefault().generate(with: .addressInfo(legacy), qrSize: CGSize(width: 240, height: 240))
        guard case let .qrInfo(.sora(info)) = try WalletQRService().extractQrCode(from: image) else {
            return XCTFail("Previously saved five-field Receive QR must remain readable")
        }
        XCTAssertNil(info.amount)
        XCTAssertEqual(info.username, legacy.username)
        XCTAssertEqual(info.assetId, legacy.assetId)
        XCTAssertEqual(info.address, legacy.address)
        XCTAssertEqual(info.rawPublicKey, legacy.rawPublicKey)
    }

    func testBokoloRequestPayloadUsesItsRoundedAmount() async throws {
        let f = try fixture()
        let initial = expectation(description: "initial QR generated")
        let selected = expectation(description: "selected Bokolo QR generated")
        let amount = expectation(description: "rounded Bokolo Request QR generated")
        f.qr.started = { index in [initial, selected, amount][index].fulfill() }
        f.presenter.didLoad(view: f.view)
        await fulfillment(of: [initial], timeout: 2)
        try f.qr.finish(0, result: .success(UIImage()))
        let asset = AssetModel(id: "fixture-bokolo", name: "Public Bokolo", symbol: "BOKO", precision: 2, currencyId: BokoloConstants.bokoloCashAssetCurrencyId, isUtility: false, isNative: false)
        f.presenter.assetSelection(didCompleteWith: ChainAsset(chain: f.asset.chain, asset: asset), contextTag: nil)
        await fulfillment(of: [selected], timeout: 2)
        try f.qr.finish(1, result: .success(UIImage()))
        f.presenter.updateAmount(Decimal(string: "12.345")!)
        await fulfillment(of: [amount], timeout: 2)
        guard case let .addressInfo(info) = try f.qr.request(2) else {
            return XCTFail("Bokolo Request must carry Sora payload")
        }
        XCTAssertEqual(info.assetId, BokoloConstants.bokoloCashAssetCurrencyId)
        XCTAssertEqual(info.amount, "12.35")
        let service = WalletQRService()
        let image = try await service.generate(with: .addressInfo(info), qrSize: CGSize(width: 240, height: 240))
        guard case let .qrInfo(.sora(decoded)) = try service.extractQrCode(from: image) else {
            return XCTFail("Actual rounded Bokolo Request QR must decode")
        }
        XCTAssertEqual(decoded.amount, "12.35")
        XCTAssertEqual(decoded.assetId, info.assetId)
        XCTAssertEqual(decoded.address, info.address)
        try f.qr.finish(2, result: .success(UIImage()))
        f.presenter.close()
    }

    func testWalletNameWithSeparatorSurvivesGeneratedRequestQR() async throws {
        let service = WalletQRService()
        let name = "Public: savings: wallet"
        let f = try fixture(qrService: service, walletName: name)
        let initial = expectation(description: "named Receive QR generated")
        f.view.onImage = { _ in initial.fulfill() }
        f.presenter.didLoad(view: f.view)
        await fulfillment(of: [initial], timeout: 3)
        guard case let .qrInfo(.sora(initialInfo)) = try service.extractQrCode(from: XCTUnwrap(f.view.currentImage)) else {
            return XCTFail("Named Receive QR without an amount must decode")
        }
        XCTAssertEqual(initialInfo.username, name)
        XCTAssertNil(initialInfo.amount)
        XCTAssertEqual(initialInfo.assetId, "fixture-xor")
        let request = expectation(description: "named Request QR generated")
        f.view.onImage = { _ in request.fulfill() }
        f.presenter.updateAmount(7)
        await fulfillment(of: [request], timeout: 3)
        let image = try XCTUnwrap(f.view.currentImage)
        guard case let .qrInfo(.sora(info)) = try service.extractQrCode(from: image) else {
            return XCTFail("Named Request QR must decode")
        }
        XCTAssertEqual(info.username, name)
        XCTAssertEqual(info.amount, "7")
        XCTAssertEqual(info.assetId, "fixture-xor")
        f.presenter.close()
    }

    func testMaxBalanceUpdateInvalidatesAndRegeneratesRequestedAmount() async throws {
        for rate in [Float(0.5), Float(1)] {
            let f = try fixture()
            let initial = expectation(description: "initial QR requested")
            let maxRequested = expectation(description: "initial Max QR requested")
            let updated = expectation(description: "new balance Max QR requested")
            f.qr.started = { index in [initial, maxRequested, updated][index].fulfill() }
            f.presenter.didLoad(view: f.view)
            await fulfillment(of: [initial], timeout: 2)
            try f.qr.finish(0, result: .success(UIImage()))
            f.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: BigUInt("10000000000000000000"))), for: f.asset)
            f.presenter.selectAmountPercentage(rate)
            await fulfillment(of: [maxRequested], timeout: 2)
            let old = UIImage()
            let delivered = expectation(description: "initial Max QR delivered")
            f.view.onImage = { _ in delivered.fulfill() }
            try f.qr.finish(1, result: .success(old))
            await fulfillment(of: [delivered], timeout: 2)
            f.view.onImage = nil
            f.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: BigUInt("20000000000000000000"))), for: f.asset)
            XCTAssertEqual(f.view.input?.decimalAmount, rate == 1 ? 20 : 10)
            XCTAssertNil(f.view.currentImage, "Changed Max amount must invalidate previous QR immediately")
            f.presenter.share(qrImage: old)
            XCTAssertTrue(f.router.shares.isEmpty)
            await fulfillment(of: [updated], timeout: 2)
            guard case let .addressInfo(info) = try f.qr.request(2) else {
                return XCTFail("Updated Max must produce an amount payload")
            }
            XCTAssertEqual(info.amount, rate == 1 ? "20" : "10")
            try f.qr.finish(2, result: .success(UIImage()))
            f.presenter.close()
        }
    }

    func testRawCameraPayloadReachesTheWalletQRDecoder() throws {
        let f = try fixture()
        f.presenter.didLoad(view: f.view)
        f.presenter.close()
        let address = try XCTUnwrap(f.view.models.first?.address)
        let code = "substrate:\(address):0x\(String(repeating: "22", count: 32)):Public QR fixture:fixture-xor:42.125"
        let output = ReceiveQRScanOutputSpy()
        let interactor = ScanQRInteractor(qrService: QRServiceDefault(), qrScanService: ReceiveQRScanServiceStub())
        interactor.setup(with: output)
        interactor.lookingMatcher(for: code)
        XCTAssertTrue(output.errors.isEmpty)
        guard case let .qrInfo(.sora(info)) = try XCTUnwrap(output.matches.last) else {
            return XCTFail("Camera payload must reach wallet decoder")
        }
        XCTAssertEqual(info.address, address)
        XCTAssertEqual(info.amount, "42.125")
    }

    func testRawCameraPreservesPlainAddressAndStopsAfterAValidResult() throws {
        let f = try fixture()
        f.presenter.didLoad(view: f.view)
        f.presenter.close()
        let address = try XCTUnwrap(f.view.models.first?.address)
        let output = ReceiveQRScanOutputSpy()
        let interactor = ScanQRInteractor(qrService: WalletQRService(), qrScanService: ReceiveQRScanServiceStub())
        interactor.setup(with: output)
        interactor.lookingMatcher(for: address)
        XCTAssertEqual(output.matches.last?.address, address)
        XCTAssertTrue(output.errors.isEmpty)
        interactor.lookingMatcher(for: address)
        XCTAssertEqual(output.matches.count, 1, "Frames after a match must not deliver twice")
        interactor.startScanning()
        interactor.lookingMatcher(for: "ws://public-qr-fixture")
        XCTAssertEqual(output.matches.last?.uri, "ws://public-qr-fixture")
        interactor.startScanning()
        interactor.stopScanning()
        interactor.lookingMatcher(for: address)
        XCTAssertEqual(output.matches.count, 2, "Stopped capture must not deliver another frame")
    }

    func testQueuedCameraFrameCannotCrossStopAndRestart() async throws {
        let output = ReceiveQRScanOutputSpy()
        let interactor = ScanQRInteractor(qrService: WalletQRService(), qrScanService: ReceiveQRScanServiceStub())
        interactor.setup(with: output)
        let stale = expectation(description: "A queued frame from the prior capture must not be delivered")
        stale.isInverted = true
        output.onMatch = { _ in stale.fulfill() }
        // Hold the main actor while a capture queue schedules its result, then
        // retire that capture and start the next one before draining main.
        let queued = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            interactor.lookingMatcher(for: "ws://public-obsolete-capture")
            queued.signal()
        }
        XCTAssertEqual(queued.wait(timeout: .now() + 2), .success)
        interactor.stopScanning()
        interactor.startScanning()
        await fulfillment(of: [stale], timeout: 0.3)
        XCTAssertTrue(output.matches.isEmpty)
        output.onMatch = nil
        interactor.lookingMatcher(for: "ws://public-current-capture")
        XCTAssertEqual(output.matches.count, 1)
        XCTAssertEqual(output.matches.last?.uri, "ws://public-current-capture")
    }

    private struct Fixture {
        let presenter: ReceiveAndRequestAssetPresenter
        let qr: ReceiveControlledQRService
        let view: ReceiveQRViewSpy
        let router: ReceiveQRRouterSpy
        let asset: ChainAsset
    }

    private func fixture(qrService: QRService? = nil, walletName: String = "Public QR fixture") throws -> Fixture {
        let asset = AssetModel(id: "fixture-xor", name: "Public XOR", symbol: "XOR", precision: 18, currencyId: "fixture-xor", isUtility: true, isNative: true)
        let chain = ChainModel(rank: nil, disabled: false, chainId: String(repeating: "12", count: 32), parentId: nil, paraId: nil, name: "Sora Test", assets: [asset], xcm: nil, nodes: [], addressPrefix: 69, types: nil, icon: nil, options: nil, externalApi: nil, selectedNode: nil, customNodes: nil, iosMinAppVersion: nil, identityChain: nil)
        let wallet = MetaAccountModel(metaId: "public-receive-fixture", name: walletName, substrateAccountId: Data(repeating: 0x22, count: 32), substrateCryptoType: 0, substratePublicKey: Data(repeating: 0x22, count: 32), ethereumAddress: Data(repeating: 0x33, count: 20), ethereumPublicKey: Data(repeating: 0x33, count: 33), chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: false, unusedChainIds: nil, selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: nil, assetsVisibility: [], hasBackup: true, favouriteChainIds: [])
        let qr = ReceiveControlledQRService()
        let view = ReceiveQRViewSpy()
        let router = ReceiveQRRouterSpy()
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let presenter = ReceiveAndRequestAssetPresenter(wallet: wallet, chainAsset: chainAsset, qrService: qrService ?? qr, sharingFactory: AccountShareFactory(), interactor: ReceiveQRInteractorStub(), router: router, localizationManager: try XCTUnwrap(LocalizationManager(localization: "en")))
        return Fixture(presenter: presenter, qr: qr, view: view, router: router, asset: chainAsset)
    }
}

private enum ReceiveQRFixtureError: Error { case failed, missingRequest }

private final class ReceiveControlledQRService: QRService {
    private let lock = NSLock()
    private var nextIndex = 0
    private var requests: [Int: QRType] = [:]
    private var pending: [Int: CheckedContinuation<UIImage, Error>] = [:]
    var started: ((Int) -> Void)?

    func extractQrCode(from _: UIImage) throws -> QRMatcherType { throw ReceiveQRFixtureError.failed }
    func generate(with type: QRType, qrSize _: CGSize) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            let index = nextIndex
            nextIndex += 1
            pending[index] = continuation
            requests[index] = type
            lock.unlock()
            started?(index)
        }
    }

    func request(_ index: Int) throws -> QRType {
        lock.lock(); defer { lock.unlock() }
        guard let request = requests[index] else { throw ReceiveQRFixtureError.missingRequest }
        return request
    }

    func finish(_ index: Int, result: Result<UIImage, Error>) throws {
        lock.lock()
        let continuation = pending.removeValue(forKey: index)
        lock.unlock()
        guard let continuation else { throw ReceiveQRFixtureError.missingRequest }
        continuation.resume(with: result)
    }
}

private final class ReceiveQRViewSpy: ReceiveAndRequestAssetViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }
    var images: [UIImage] = []
    var currentImage: UIImage?
    var input: IAmountInputViewModel?
    func didStartQRGeneration() { currentImage = nil }
    var models: [ReceiveAssetViewModel] = []
    var onImage: ((UIImage) -> Void)?
    func didReceive(viewModel: ReceiveAssetViewModel) { models.append(viewModel) }
    func didReceive(image: UIImage) { currentImage = image; images.append(image); onImage?(image) }
    func didReceive(assetBalanceViewModel _: AssetBalanceViewModelProtocol?) {}
    func didReceive(amountInputViewModel: IAmountInputViewModel?) { input = amountInputViewModel }
}

private final class ReceiveQRRouterSpy: ReceiveAndRequestAssetRouterInput {
    var errors: [Error] = []
    var dismissCount = 0
    var shares: [[Any]] = []
    func share(sources: [Any], from _: ControllerBackedProtocol?, with _: SharingCompletionHandler?) { shares.append(sources) }
    var onError: ((Error) -> Void)?
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error); onError?(error); return true
    }

    func dismiss(view _: ControllerBackedProtocol?) { dismissCount += 1 }
    func showSelectAsset(from _: ControllerBackedProtocol?, wallet _: MetaAccountModel, selectedAssetId _: AssetModel.Id?, chainAssets _: [ChainAsset]?, output _: SelectAssetModuleOutput) {}
}

private final class ReceiveQRInteractorStub: ReceiveAndRequestAssetInteractorInput {
    func setup(with _: ReceiveAndRequestAssetInteractorOutput) {}
}

private final class ReceiveQRScanOutputSpy: ScanQRInteractorOutput, QRCaptureServiceDelegate {
    var errors: [Error] = []
    var matches: [QRMatcherType] = []
    var onMatch: ((QRMatcherType) -> Void)?
    func handleQRService(error: Error) { errors.append(error) }
    func didReceive(matcher: QRMatcherType) { matches.append(matcher); onMatch?(matcher) }
    func qrCapture(service _: QRCaptureServiceProtocol, didSetup _: AVCaptureSession) {}
    func qrCapture(service _: QRCaptureServiceProtocol, didMatch _: String) {}
    func qrCapture(service _: QRCaptureServiceProtocol, didReceive _: Error) {}
}

private final class ReceiveQRScanServiceStub: QRCaptureServiceProtocol {
    var delegate: QRCaptureServiceDelegate?
    var delegateQueue = DispatchQueue.main
    func start() {}
    func stop() {}
}
