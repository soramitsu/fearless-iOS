import XCTest
import UIKit
@testable import fearless

final class CovJNetworkLayoutsTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    func testNetworkManagementFilterSelectionAndSearchCaptions() throws {
        let view = NetworkManagmentViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        XCTAssertEqual(view.filtersStackView.arrangedSubviews.count, 3)
        XCTAssertEqual(view.searchTextField.textField.placeholder, R.string.localizable.commonSearch(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.commonNetworkManagement(preferredLanguages: locale.rLanguages))
        let cases: [(NetworkManagmentFilter, [Bool])] = [
            (.all, [true, false, false]), (.popular, [false, true, false]),
            (.favourite, [false, false, true]), (.chain("chain"), [true, false, false])
        ]
        for (filter, selected) in cases {
            view.setSelected(filter: filter)
            XCTAssertEqual([view.allFilterButton.isSelected, view.popularFilterButton.isSelected, view.favouriteFilterButton.isSelected], selected)
        }
        XCTAssertGreaterThan(view.tableView.frame.height, 0)
        XCTAssertNotNil(view.keyboardAdoptableConstraint)
    }

    func testNetworkIssueSheetReservesSpaceForCloseAction() throws {
        let view = NetworkIssuesNotificationViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        XCTAssertEqual(view.titleLabel.text, R.string.localizable.networkIssueStub(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.bottomCloseButton.imageWithTitleView?.title, R.string.localizable.commonClose(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.tableView.separatorStyle, .none)
        XCTAssertEqual(view.tableView.contentInset.bottom, 80)
        XCTAssertEqual(view.closeButton.bounds.size, CGSize(width: 32, height: 32))
        XCTAssertEqual(view.closeButton.layer.cornerRadius, 16)
        XCTAssertGreaterThan(view.bottomCloseButton.frame.width, 0)
    }

    func testAddingNodeMovesActionAboveKeyboardAndRestoresIt() throws {
        let view = AddCustomNodeViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        XCTAssertEqual(view.nodeNameInputView.animatedInputField.title, R.string.localizable.networkInfoName(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.nodeAddressInputView.animatedInputField.title, R.string.localizable.networkInfoAddress(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.addNodeButton.imageWithTitleView?.title, R.string.localizable.addNodeButtonTitle(preferredLanguages: locale.rLanguages))
        let originalY = view.addNodeButton.frame.minY
        view.handleKeyboard(frame: CGRect(x: 0, y: 544, width: 390, height: 300))
        view.layoutIfNeeded()
        XCTAssertEqual(view.addNodeButton.frame.minY, originalY - 300, accuracy: 0.5)
        view.handleKeyboard(frame: .zero)
        view.layoutIfNeeded()
        XCTAssertEqual(view.addNodeButton.frame.minY, originalY, accuracy: 0.5)
    }

    func testMultipleNetworkSelectionSwitchesSelectAllCaption() throws {
        let view = MultiSelectNetworksViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        view.setTitle(text: "Choose networks")
        XCTAssertEqual(view.titleLabel.text, "Choose networks")
        XCTAssertEqual(view.doneButton.title(for: .normal), R.string.localizable.commonDone(preferredLanguages: locale.rLanguages))
        view.handleSelectAllButton(allSelected: true)
        XCTAssertEqual(view.selectAllButton.title(for: .normal), R.string.localizable.stakingCustomDeselectButtonTitle(preferredLanguages: locale.rLanguages))
        view.handleSelectAllButton(allSelected: false)
        XCTAssertEqual(view.selectAllButton.title(for: .normal), R.string.localizable.commonSelectAll(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.searchTextField.textField.placeholder, R.string.localizable.commonSearch(preferredLanguages: locale.rLanguages))
        XCTAssertGreaterThan(view.tableView.frame.height, 0)
    }

    func testCurrencyLayoutIncludesDoneOnlyForPushedScreen() throws {
        for modal in [true, false] {
            let view = SelectCurrencyViewLayout(isModal: modal)
            view.locale = locale
            let window = try CovJViewFixture.host(view)
            defer { window.isHidden = true }
            XCTAssertEqual(view.titleLabel.text, R.string.localizable.commonCurrency(preferredLanguages: locale.rLanguages))
            XCTAssertEqual(view.rightButton.superview == nil, modal)
            XCTAssertEqual(view.rightButton.title(for: .normal), R.string.localizable.commonDone(preferredLanguages: locale.rLanguages))
            XCTAssertEqual(view.backButton.bounds.size, CGSize(width: 32, height: 32))
            XCTAssertEqual(view.tableView.separatorStyle, .none)
        }
    }

    func testAssetNetworksProvidesRefreshableGroupedListAndTwoFilters() throws {
        let view = AssetNetworksViewLayout()
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        XCTAssertEqual(view.tableView.style, .grouped)
        XCTAssertNotNil(view.tableView.refreshControl)
        XCTAssertEqual(view.tableView.separatorStyle, .none)
        let labels = CovJViewFixture.descendants(UILabel.self, in: view.networkSwitcher).compactMap(\.text)
        XCTAssertTrue(labels.contains(R.string.localizable.commonAvailableNetworks(preferredLanguages: locale.rLanguages)))
        XCTAssertTrue(labels.contains(R.string.localizable.commonMyNetworks(preferredLanguages: locale.rLanguages)))
        XCTAssertNotNil(view.sortButton.image(for: .normal))
    }

    func testMultichainAssetContainerPinsItsChildAndNamesSelection() throws {
        let view = MultichainAssetSelectionViewLayout()
        view.locale = locale
        let child = UIView()
        view.addSelectAssetView(child)
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        XCTAssertEqual(view.topBar.titleLabel.text, "Select token")
        XCTAssertTrue(child.superview === view.selectAssetContainerView)
        XCTAssertEqual(child.frame, view.selectAssetContainerView.bounds)
        XCTAssertGreaterThan(child.bounds.height, 0)
    }

    func testScanLayoutLocalizesTitleWithoutStartingCamera() throws {
        let view = ScanQRViewLayout()
        view.locale = Locale(identifier: "de_DE")
        view.locale = locale
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.contactsScan(preferredLanguages: locale.rLanguages))
        XCTAssertNotNil(view.addButton.image(for: .normal))
        XCTAssertTrue(view.qrFrameView.isDescendant(of: view))
        XCTAssertGreaterThan(view.qrFrameView.bounds.width, 0)
    }

    func testFiltersLayoutAddsOnlyOneApplyButtonForMultipleSelection() throws {
        let view = FiltersViewLayout(screenTitle: nil)
        view.locale = locale
        view.applyLocalization()
        view.bind(viewModel: FiltersViewModel(sections: [], mode: .multiSelection))
        view.bind(viewModel: FiltersViewModel(sections: [], mode: .multiSelection))
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        XCTAssertEqual(view.navigationTitleLabel.text, R.string.localizable.walletFiltersTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(view.subviews.filter { $0 === view.applyButton }.count, 1)
        XCTAssertEqual(view.applyButton.frame.height, UIConstants.actionHeight, accuracy: 0.5)
        XCTAssertFalse(view.resetButton.isHidden)
        let single = FiltersViewLayout(screenTitle: "Sort tokens")
        single.bind(viewModel: FiltersViewModel(sections: [], mode: .singleSelection))
        XCTAssertEqual(single.navigationTitleLabel.text, "Sort tokens")
        XCTAssertTrue(single.resetButton.isHidden)
        XCTAssertNil(single.applyButton.superview)
    }
}
