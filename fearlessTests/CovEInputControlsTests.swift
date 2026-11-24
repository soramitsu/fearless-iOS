@testable import fearless
import UIKit
import XCTest

@MainActor
final class CovEInputControlsTests: XCTestCase {
    func testSelectableAmountCardsBindAssetsAndPreserveTheEditorWhenWrapping() throws {
        let locale = Locale(identifier: "en")
        for type in [SelectableAmountInputViewType.send, .swapSend, .swapReceive] {
            let view = SelectableAmountInputView(type: type)
            view.locale = locale
            let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 358, height: 150))
            defer { CovEHost.close(window) }
            view.bind(viewModel: nil)
            XCTAssertEqual(view.symbol, R.string.localizable.commonSelectAsset(preferredLanguages: ["en"]))
            let model = AssetBalanceViewModel(
                symbol: "dot",
                balance: "12 DOT",
                fiatBalance: "$60",
                price: "$5",
                iconViewModel: BundleImageViewModel(image: R.image.iconClose()),
                selectable: true
            )
            view.bind(viewModel: model)
            XCTAssertEqual(view.symbol, "DOT")
            XCTAssertEqual(view.priceText, "$5")
            XCTAssertEqual(view.balanceText, R.string.localizable.commonAvailableFormat("12 DOT", preferredLanguages: ["en"]))
            XCTAssertEqual(view.iconView.image, R.image.iconClose())
            var selected = 0
            view.selectHandler = { selected += 1 }
            let select = try XCTUnwrap(CovEFind.mirror(view, "selectButton", as: UIButton.self))
            select.sendActions(for: .touchUpInside)
            XCTAssertEqual(selected, 1)
            let editor = view.textField
            view.inputFieldText = "1234567890.12345678"
            view.configureSendPresentation(locale: locale, traits: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
            XCTAssertTrue(view.textField === editor)
            XCTAssertEqual(view.inputFieldText, "1234567890.12345678")
            let readout = try XCTUnwrap(CovEFind.mirror(view, "amountReadoutLabel", as: UILabel.self))
            XCTAssertEqual(readout.text, view.inputFieldText)
            XCTAssertFalse(readout.isHidden)
            view.inputFieldText = ""
            XCTAssertEqual(readout.text, "0")
            view.title = "Amount"
            view.priceText = "$7"
            view.balanceText = "Available"
            view.symbol = "KSM"
            XCTAssertEqual(view.title, "Amount")
            XCTAssertEqual(view.priceText, "$7")
            XCTAssertEqual(view.balanceText, "Available")
            XCTAssertEqual(view.symbol, "KSM")
            view.set(highlighted: true, animated: false)
            XCTAssertEqual(CovEFind.mirror(view, "triangularedBackgroundView", as: TriangularedView.self)?.isHighlighted, true)
            view.bind(viewModel: AssetBalanceViewModel(
                symbol: "eth",
                balance: nil,
                fiatBalance: nil,
                price: nil,
                iconViewModel: nil,
                selectable: false
            ))
            XCTAssertNil(view.balanceText)
            XCTAssertNil(view.priceText)
            XCTAssertEqual(CovEFind.mirror(view, "iconSelect", as: UIImageView.self)?.isHidden, true)
        }
    }

    func testSearchCardUpdatesIconsPasteClearAndAccessiblePlaceholder() throws {
        let view = SearchTriangularedView(withPasteButton: true)
        let delegate = CovETextDelegate()
        view.textField.delegate = delegate
        view.titleLabel.text = "Recipient"
        view.locale = Locale(identifier: "en")
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 358, height: 64))
        defer { CovEHost.close(window) }
        let paste = try XCTUnwrap(CovEFind.mirror(view, "pasteButton", as: TriangularedButton.self))
        let clear = try XCTUnwrap(CovEFind.mirror(view, "cleanButton", as: UIButton.self))
        let placeholder = try XCTUnwrap(CovEFind.mirror(view, "placeholderImage", as: UIImageView.self))
        var pastes = 0
        view.onPasteTapped = { pastes += 1 }
        paste.sendActions(for: .touchUpInside)
        XCTAssertEqual(pastes, 1)
        XCTAssertEqual(paste.imageWithTitleView?.title, R.string.localizable.commonPaste(preferredLanguages: ["en"]).uppercased())
        view.textField.text = "account"
        view.updateState(icon: EthereumIcon(radius: 16, squares: []))
        XCTAssertFalse(clear.isHidden)
        XCTAssertTrue(paste.isHidden)
        XCTAssertTrue(placeholder.isHidden)
        view.updateState(icon: nil, clearButtonIsHidden: true)
        XCTAssertTrue(clear.isHidden)
        XCTAssertFalse(placeholder.isHidden)
        clear.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.clears, 1)
        XCTAssertTrue(view.textField.text?.isEmpty != false)
        XCTAssertFalse(paste.isHidden)
        view.configureSendPresentation(locale: Locale(identifier: "en"), traits: UITraitCollection(preferredContentSizeCategory: .large))
        XCTAssertEqual(view.textField.accessibilityLabel, "Recipient")
        XCTAssertFalse(view.sendPlaceholderLabel.isHidden)
        XCTAssertNil(view.textField.placeholder)
        view.textField.text = "0x1234"
        view.textField.sendActions(for: .editingChanged)
        XCTAssertTrue(view.sendPlaceholderLabel.isHidden)
        view.bind(address: nil)
        XCTAssertFalse(view.sendPlaceholderLabel.isHidden)
        view.bind(address: "0x5678")
        XCTAssertEqual(view.textField.text, "0x5678")
        XCTAssertTrue(view.sendPlaceholderLabel.isHidden)
        view.bind(address: nil)
        XCTAssertFalse(view.sendPlaceholderLabel.isHidden)
        let count = view.subviews.count
        view.configureSendPresentation(locale: Locale(identifier: "ja"), traits: UITraitCollection(preferredContentSizeCategory: .large))
        XCTAssertEqual(view.subviews.count, count, "Repeated configuration does not install a second row")
        view.set(highlighted: true, animated: false)
        XCTAssertEqual(CovEFind.mirror(view, "backgroundView", as: TriangularedView.self)?.isHighlighted, true)
    }

    func testSegmentsSupportAccessibleSelectionClampedTapsAndPanVelocity() throws {
        let control = FWSegmentedControl()
        let delegate = CovESegmentDelegate()
        control.delegate = delegate
        control.setSegmentItems(["One", "Two", "Three"])
        control.configureWrapping(locale: Locale(identifier: "en"), traits: UITraitCollection(preferredContentSizeCategory: .large))
        let window = CovEHost.window(for: control, frame: CGRect(x: 16, y: 100, width: 330, height: 64))
        defer { CovEHost.close(window) }
        XCTAssertGreaterThanOrEqual(control.intrinsicContentSize.height, 44)
        let elements = try XCTUnwrap(control.accessibilityElements as? [UIAccessibilityElement])
        XCTAssertEqual(elements.map(\.accessibilityLabel), ["One", "Two", "Three"])
        XCTAssertTrue(elements[1].accessibilityActivate())
        XCTAssertEqual(control.selectedSegmentIndex, 1)
        XCTAssertEqual(delegate.selections, [1])
        control.isEnabled = false
        XCTAssertFalse(elements[2].accessibilityActivate())
        control.isEnabled = true
        let tap = CovETap()
        tap.stubLocation = CGPoint(x: -100, y: 10)
        let tapSelector = NSSelectorFromString("didTapWithTapGesture:")
        XCTAssertTrue(control.responds(to: tapSelector))
        if control.responds(to: tapSelector) {
            control.perform(tapSelector, with: tap)
        }
        XCTAssertEqual(control.selectedSegmentIndex, 0)
        let pan = CovEPan()
        let selector = NSSelectorFromString("didPanWithPanGesture:")
        XCTAssertTrue(control.responds(to: selector))
        for state in [UIGestureRecognizer.State.began, .changed, .ended] {
            pan.stubState = state
            pan.stubLocation = CGPoint(x: state == .began ? 55 : 300, y: 20)
            pan.stubVelocity = CGPoint(x: 1000, y: 0)
            if control.responds(to: selector) {
                control.perform(selector, with: pan)
            }
        }
        XCTAssertEqual(control.selectedSegmentIndex, 2)
        XCTAssertEqual(delegate.selections.last, 2)
        control.setSegmentItems(["Short", "A much longer title"])
        control.layoutIfNeeded()
        XCTAssertEqual(control.selectedSegmentIndex, 1, "Reducing the segment count clamps the selection")
        XCTAssertEqual(CovEFind.all(UILabel.self, in: control).count, 2)
        control.defaultFont = .systemFont(ofSize: 22)
        control.highlightFont = .boldSystemFont(ofSize: 22)
        XCTAssertGreaterThan(control.intrinsicContentSize.height, 44)
    }

    func testScamWarningBindsDetailsAndTogglesExpansion() throws {
        let view = ScamWarningExpandableView()
        view.locale = Locale(identifier: "en")
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 358, height: 220))
        defer { CovEHost.close(window) }
        let expanded = try XCTUnwrap(CovEFind.mirror(view, "expandableCloudView", as: UIView.self))
        let background = try XCTUnwrap(CovEFind.mirror(view, "backgroundView", as: TriangularedView.self))
        for type in [ScamInfo.ScamType.scam, .exchange] {
            view.bind(scamInfo: ScamInfo(name: "Example", address: "address", type: type, subtype: "Reported"), assetName: "DOT")
            XCTAssertTrue(CovEFind.texts(in: view).contains("Example"))
            XCTAssertTrue(CovEFind.texts(in: view).contains("Reported"))
            XCTAssertEqual(background.isHighlighted, type.isScam)
        }
        XCTAssertTrue(expanded.isHidden)
        view.perform(NSSelectorFromString("handleTapGesture"))
        XCTAssertFalse(expanded.isHidden)
        view.perform(NSSelectorFromString("handleTapGesture"))
        XCTAssertTrue(expanded.isHidden)
    }
}

final class CovETextDelegate: NSObject, UITextFieldDelegate {
    private(set) var clears = 0
    func textFieldShouldClear(_: UITextField) -> Bool {
        clears += 1; return true
    }
}

final class CovESegmentDelegate: FWSegmentedControlDelegate {
    private(set) var selections: [Int] = []
    func didSelect(_ segmentIndex: Int) {
        selections.append(segmentIndex)
    }
}
