import XCTest
@testable import fearless
import SoraKeystore
import IrohaCrypto
import RobinHood
import Cuckoo
import SoraFoundation
import UIKit

class AccountCreateTests: XCTestCase {

    func testSuccessfullAccountCreation() {
        // given

        let view = MockAccountCreateViewProtocol()
        let wireframe = MockAccountCreateWireframeProtocol()

        let mnemonicCreator = IRMnemonicCreator()
        let interactor = AccountCreateInteractor(mnemonicCreator: mnemonicCreator)

        let usernameSetup = UsernameSetupModel(username: "myname")
        let presenter = AccountCreatePresenter(usernameSetup: usernameSetup,
                                               wireframe: wireframe,
                                               interactor: interactor,
                                               flow: .wallet)
        interactor.presenter = presenter
        presenter.view = view

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didCompleteCryptoTypeSelection()).thenDoNothing()
            when(stub.didValidateSubstrateDerivationPath(any(FieldStatus.self))).thenDoNothing()
            when(stub.didValidateEthereumDerivationPath(any(FieldStatus.self))).thenDoNothing()
            when(stub.isSetup.get).thenReturn(false, true)
            when(stub.set(chainType: any(AccountCreateChainType.self))).thenDoNothing()
            when(stub.bind(substrateViewModel: any(InputViewModelProtocol.self))).thenDoNothing()
            when(stub.setEthereumCrypto(model: any(TitleWithSubtitleViewModel.self))).thenDoNothing()
            when(stub.bind(ethereumViewModel: any(InputViewModelProtocol.self))).thenDoNothing()

            when(stub.set(mnemonic: any([String].self))).then { _ in
                setupExpectation.fulfill()
            }

            when(stub.setSelectedSubstrateCrypto(model: any(SelectableViewModel<TitleWithSubtitleViewModel>.self))).thenDoNothing()
        }

        let expectation = XCTestExpectation()

        var receivedRequest: MetaAccountImportMnemonicRequest?

        stub(wireframe) { stub in
            when(stub.confirm(from: any(AccountCreateViewProtocol?.self), flow: any(AccountConfirmFlow.self))).then { (_, flow) in
                if case .wallet(let request) = flow {
                    receivedRequest = request
                    expectation.fulfill()
                }
            }
        }

        // when

        presenter.setup()

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        presenter.proceed(withReplaced: nil)

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(receivedRequest?.username, usernameSetup.username)
    }

    func testSetupGeneratesTwentyFourWordMnemonic() {
        let presenter = MockAccountCreateInteractorOutputProtocol()
        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator())
        interactor.presenter = presenter

        let expectation = XCTestExpectation()

        stub(presenter) { stub in
            when(stub.didReceive(mnemonic: any([String].self))).then { mnemonic in
                XCTAssertEqual(mnemonic.count, 24)
                expectation.fulfill()
            }
            when(stub.didReceiveMnemonicGeneration(error: any(Error.self))).thenDoNothing()
        }

        interactor.setup()

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}

@MainActor
final class AccountCreatePresentationTests: XCTestCase {
    private let languages = ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"]
    private let categories: [UIContentSizeCategory] = [.large, .accessibilityExtraExtraExtraLarge]

    private final class Presenter: AccountCreatePresenterProtocol {
        let flow: AccountCreateFlow
        var actions: [String] = []

        init(flow: AccountCreateFlow) { self.flow = flow }
        func setup() { actions.append("setup") }
        func selectSubstrateCryptoType() { actions.append("crypto") }
        func activateInfo() { actions.append("info") }
        func validateSubstrate() { actions.append("substrate") }
        func validateEthereum() { actions.append("ethereum") }
        func proceed(withReplaced _: AccountCreateFlow?) { actions.append("proceed") }
        func didTapBackupButton() { actions.append("backup") }
    }

    func testMnemonicWordCountRebindingRemovesStaleLabels() throws {
        let controller = UIViewController()
        let window = try show(controller, category: .large)
        defer { close(window) }
        let grid = MnemonicDisplayView(frame: CGRect(x: 16, y: 100, width: 288, height: 420))
        controller.view.addSubview(grid)
        for (prefix, count) in [("old", 24), ("new", 12), ("next", 24), ("empty", 0)] {
            let words = fixtures(prefix, count: count)
            grid.bind(words: words, columnsCount: 2)
            window.layoutIfNeeded()
            capture(window, name: "rebind-words-" + prefix)
            assertDisplayedWords(grid, equal: words)
            XCTAssertGreaterThanOrEqual(grid.intrinsicContentSize.height, 0)
        }
    }

    func testInvalidMnemonicBindingsClearPreviousWords() throws {
        let controller = UIViewController()
        let window = try show(controller, category: .large)
        defer { close(window) }
        let grid = MnemonicDisplayView(frame: CGRect(x: 16, y: 100, width: 288, height: 420))
        controller.view.addSubview(grid)
        for (name, count, columns) in [("uneven", 15, 2), ("zero", 24, 0), ("negative", 24, -2)] {
            grid.bind(words: fixtures("prior", count: 24), columnsCount: 2)
            window.layoutIfNeeded()
            assertDisplayedWords(grid, equal: fixtures("prior", count: 24))
            let supplied = fixtures(name, count: count)
            grid.bind(words: supplied, columnsCount: columns)
            window.layoutIfNeeded()
            capture(window, name: "invalid-" + name)
            assertDisplayedWords(grid, equal: [])
            XCTAssertEqual(supplied, fixtures(name, count: count))
            grid.bind(words: fixtures("restored", count: 24), columnsCount: 3)
            window.layoutIfNeeded()
            assertDisplayedWords(grid, equal: fixtures("restored", count: 24))
        }
    }

    func testMnemonicColumnCountRebindingRemovesStaleLabels() throws {
        let controller = UIViewController()
        let window = try show(controller, category: .large)
        defer { close(window) }
        let grid = MnemonicDisplayView(frame: CGRect(x: 16, y: 100, width: 288, height: 420))
        controller.view.addSubview(grid)
        for (prefix, columns) in [("first", 3), ("second", 2), ("third", 1), ("fourth", 3)] {
            let words = fixtures(prefix, count: 24)
            grid.bind(words: words, columnsCount: columns)
            window.layoutIfNeeded()
            capture(window, name: "rebind-columns-" + prefix)
            assertDisplayedWords(grid, equal: words)
            XCTAssertEqual(grid.subviews.count, columns)
        }
    }

    func testActualCreateAndBackupBaselineInAllLocalesAndTypeSizes() async throws {
        for language in languages {
            for category in categories {
                for (name, flow) in [("wallet", AccountCreateFlow.wallet), ("backup", .backup)] {
                    let localization = try XCTUnwrap(LocalizationManager(localization: language))
                    let presenter = Presenter(flow: flow)
                    let controller = AccountCreateViewController(presenter: presenter)
                    controller.localizationManager = localization
                    let window = try show(controller, category: category)
                    defer { close(window) }
                    configure(controller)
                    await settle(window)
                    XCTAssertEqual(presenter.actions, ["setup"])
                    assertDisplayedWords(try XCTUnwrap(controller.rootView.mnemonicView), equal: fixtures("fixture", count: 24))
                    let captureName = name + "-" + language + "-" + category.rawValue
                    capture(window, name: captureName + "-top")
                    let scroll = controller.rootView.contentView.scrollView
                    scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height)), animated: false)
                    window.layoutIfNeeded()
                    capture(window, name: captureName + "-bottom")
                    if name == "wallet" {
                        let expandable = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? ExpandableActionControl }.first)
                        expandable.sendActions(for: .touchUpInside)
                        await settle(window)
                        XCTAssertTrue(expandable.isActivated)
                        scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height)), animated: false)
                        window.layoutIfNeeded()
                        capture(window, name: captureName + "-advanced")
                    }
                    controller.rootView.nextButton.sendActions(for: .touchUpInside)
                    XCTAssertEqual(presenter.actions.filter { $0 == "proceed" }.count, 1)
                }
            }
        }
    }

    func testAdaptiveMnemonicResizingKeepsEveryWordAndIndex() throws {
        let controller = UIViewController()
        let window = try show(controller, category: .accessibilityExtraExtraExtraLarge)
        defer { close(window) }
        let grid = MnemonicDisplayView()
        grid.adaptsToAvailableWidth = true
        grid.wordFontInColumn = .fw(.phraseWord, compatibleWith: window.traitCollection)
        grid.indexFontInColumn = .fw(.monoS, compatibleWith: window.traitCollection)
        controller.view.addSubview(grid)
        let words = fixtures("fixture", count: 24)
        grid.bind(words: words, columnsCount: 2)
        for width in [CGFloat(640), CGFloat(288), CGFloat(640)] {
            grid.frame = CGRect(x: 0, y: 0, width: width, height: 2000)
            grid.layoutIfNeeded()
            assertDisplayedWords(grid, equal: words)
            XCTAssertLessThanOrEqual(grid.intrinsicContentSize.width, width + 1)
            for label in descendants(grid).compactMap({ $0 as? UILabel }) { assertFits(label) }
        }
        grid.adaptsToAvailableWidth = false
        grid.layoutIfNeeded()
        XCTAssertEqual(grid.subviews.count, 2)
        assertDisplayedWords(grid, equal: words)
    }

    func testBackupIconAndTitleTrackLoadingTogether() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = AccountCreateViewController(presenter: Presenter(flow: .wallet))
        controller.localizationManager = localization
        let window = try show(controller, category: .large)
        defer { close(window) }
        configure(controller)
        await settle(window)
        let button = controller.rootView.backupButton
        let visibleIcons = { self.descendants(button).compactMap { $0 as? UIImageView }.filter { self.isVisible($0) && $0.image == controller.rootView.backupButton.imageWithTitleView?.iconImage } }
        XCTAssertEqual(visibleIcons().count, 1)
        button.set(loading: true)
        XCTAssertTrue(visibleIcons().isEmpty)
        XCTAssertFalse(button.accessibilityActivate())
        button.set(loading: false)
        XCTAssertEqual(visibleIcons().count, 1)
        if FWAppearance.accountCreateRestyled { XCTAssertFalse(try XCTUnwrap(button.wrappingLabel).isHidden) }
    }

    func testCreateAndBackupLayoutFitsAllLocalesAndTypeSizes() async throws {
        for language in languages {
            for category in categories {
                for (name, flow) in [("wallet", AccountCreateFlow.wallet), ("backup", .backup)] {
                    let localization = try XCTUnwrap(LocalizationManager(localization: language))
                    let presenter = Presenter(flow: flow)
                    let controller = AccountCreateViewController(presenter: presenter)
                    controller.localizationManager = localization
                    let window = try show(controller, category: category)
                    defer { close(window) }
                    configure(controller)
                    await settle(window)
                    let grid = try XCTUnwrap(controller.rootView.mnemonicView)
                    let scroll = controller.rootView.contentView.scrollView
                    let captureName = "create-layout-" + name + "-" + language + "-" + category.rawValue
                    capture(window, name: captureName + "-top")
                    XCTAssertEqual(grid.wordFontInColumn.pointSize, UIFont.fw(.phraseWord, locale: localization.selectedLocale, compatibleWith: grid.traitCollection).pointSize, accuracy: 0.1)
                    assertDisplayedWords(grid, equal: fixtures("fixture", count: 24))
                    for label in descendants(grid).compactMap({ $0 as? UILabel }) {
                        assertInside(label, ancestor: grid)
                        assertFits(label)
                    }
                    if name == "wallet" {
                        let expandable = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? ExpandableActionControl }.first)
                        scroll.scrollRectToVisible(expandable.convert(expandable.bounds, to: scroll), animated: false)
                        await settle(window)
                        expandable.sendActions(for: .touchUpInside)
                        await settle(window)
                        for field in [controller.rootView.substrateDerivationPathField, controller.rootView.ethereumDerivationPathField] {
                            assertInside(field, ancestor: try XCTUnwrap(field.superview))
                            XCTAssertGreaterThanOrEqual(field.bounds.height, ceil(try XCTUnwrap(field.font).lineHeight))
                        }
                        for label in [controller.rootView.substrateDerivationPathLabel, controller.rootView.ethereumDerivationPathLabel] { assertFits(label) }
                        for control in [controller.rootView.substrateCryptoTypeView, controller.rootView.ethereumCryptoTypeView] {
                            for label in descendants(control).compactMap({ $0 as? UILabel }).filter({ isVisible($0) }) {
                                assertInside(label, ancestor: control)
                                assertFits(label)
                            }
                        }
                        capture(window, name: captureName + "-advanced")
                    }
                    if name == "wallet" {
                        let icons = descendants(controller.rootView.backupButton).compactMap { $0 as? UIImageView }.filter { isVisible($0) }
                        XCTAssertTrue(icons.contains { $0.image == controller.rootView.backupButton.imageWithTitleView?.iconImage }, "The existing Google backup icon remains visible")
                    }
                    let actions = name == "wallet" ? [controller.rootView.nextButton, controller.rootView.backupButton] : [controller.rootView.nextButton]
                    for (index, button) in actions.enumerated() {
                        scroll.scrollRectToVisible(button.convert(button.bounds, to: scroll), animated: false)
                        await settle(window)
                        for label in descendants(button).compactMap({ $0 as? UILabel }).filter({ isVisible($0) }) {
                            assertInside(label, ancestor: button)
                            assertFits(label)
                        }
                        let center = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: window)
                        let hit = window.hitTest(center, with: nil)
                        XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true, "Actual action hit path must reach the button")
                        capture(window, name: captureName + "-action-" + String(index))
                        button.sendActions(for: .touchUpInside)
                    }
                    XCTAssertEqual(presenter.actions.filter { $0 == "proceed" }.count, 1)
                    XCTAssertEqual(presenter.actions.filter { $0 == "backup" }.count, name == "wallet" ? 1 : 0)
                }
            }
        }
    }

    func testCreateKeyboardKeepsNativeEditorAndActionReachable() async throws {
        for category in categories {
            for ethereum in [false, true] {
                let localization = try XCTUnwrap(LocalizationManager(localization: "ja"))
                let presenter = Presenter(flow: .wallet)
                let controller = AccountCreateViewController(presenter: presenter)
                controller.localizationManager = localization
                let window = try show(controller, category: category)
                defer { close(window) }
                configure(controller)
                let expandable = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? ExpandableActionControl }.first)
                expandable.sendActions(for: .touchUpInside)
                await settle(window)
                let field = ethereum ? controller.rootView.ethereumDerivationPathField : controller.rootView.substrateDerivationPathField
                let original = field.text
                controller.clearKeyboardHandler()
                XCTAssertTrue(field.becomeFirstResponder())
                let position = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 2))
                field.selectedTextRange = field.textRange(from: position, to: position)
                let keyboard = CGRect(x: 0, y: 308, width: 320, height: 260)
                await settle(window)
                controller.apply(keyboardFrame: keyboard, keyboardHidden: false)
                let scroll = controller.rootView.contentView.scrollView
                await settleScroll(scroll, in: window)
                let fieldFrame = field.convert(field.bounds, to: window)
                XCTAssertGreaterThanOrEqual(fieldFrame.minY, scroll.convert(scroll.bounds, to: window).minY - 1, "\(category.rawValue) ethereum=\(ethereum); field=\(fieldFrame); viewport=\(scroll.convert(scroll.bounds, to: window)); contentInset=\(scroll.adjustedContentInset)")
                XCTAssertLessThanOrEqual(fieldFrame.maxY, keyboard.minY + 1, "\(category.rawValue) ethereum=\(ethereum); field=\(fieldFrame); viewport=\(scroll.convert(scroll.bounds, to: window)); contentInset=\(scroll.adjustedContentInset)")
                XCTAssertTrue(field.isFirstResponder)
                XCTAssertEqual(field.text, original)
                XCTAssertEqual(field.offset(from: field.beginningOfDocument, to: try XCTUnwrap(field.selectedTextRange).start), 2)
                let name = "create-keyboard-" + (ethereum ? "ethereum-" : "substrate-") + category.rawValue
                capture(window, name: name + "-editor")
                let button = controller.rootView.nextButton
                let rect = button.convert(button.bounds, to: scroll)
                let offset = min(max(0, rect.midY - scroll.bounds.height / 2), max(0, scroll.contentSize.height - scroll.bounds.height))
                scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                await settle(window)
                let center = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: window)
                XCTAssertLessThan(center.y, keyboard.minY)
                let hit = window.hitTest(center, with: nil)
                XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
                capture(window, name: name + "-action")
                button.sendActions(for: .touchUpInside)
                XCTAssertEqual(presenter.actions.filter { $0 == "proceed" }.count, 1)
            }
        }
    }

    func testCreateLocaleRefreshPreservesActiveDerivationEditor() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let presenter = Presenter(flow: .wallet)
        let controller = AccountCreateViewController(presenter: presenter)
        controller.localizationManager = localization
        let window = try show(controller, category: .large)
        defer { close(window) }
        configure(controller)
        let expandable = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? ExpandableActionControl }.first)
        expandable.sendActions(for: .touchUpInside)
        await settle(window)
        let field = controller.rootView.substrateDerivationPathField
        XCTAssertTrue(field.becomeFirstResponder())
        let start = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 2))
        field.selectedTextRange = field.textRange(from: start, to: start)
        let previous = field.text
        localization.selectedLocalization = "ja"
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
        await settle(window)
        capture(window, name: "create-live-ja-AX5-active-editor")
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertEqual(field.text, previous)
        XCTAssertEqual(field.offset(from: field.beginningOfDocument, to: try XCTUnwrap(field.selectedTextRange).start), 2)
        XCTAssertTrue(expandable.isActivated)
        XCTAssertEqual(presenter.actions, ["setup"])
        XCTAssertEqual(controller.rootView.substrateDerivationPathLabel.text, R.string.localizable.example("//Alice", preferredLanguages: ["ja"]))
        let caption = R.string.localizable.substrateSecretDerivationPath(preferredLanguages: ["ja"])
        XCTAssertEqual(field.accessibilityLabel, caption)
        if FWAppearance.accountCreateRestyled { XCTAssertNil(field.attributedPlaceholder) }
        else { XCTAssertEqual(field.attributedPlaceholder?.string, caption) }
        XCTAssertEqual(controller.navigationItem.rightBarButtonItem?.customView?.accessibilityLabel, R.string.localizable.commonInfo(preferredLanguages: ["ja"]))
    }

    private func settleScroll(_ scroll: UIScrollView, in window: UIWindow) async {
        var previous = scroll.contentOffset
        var stable = 0
        for _ in 0 ..< 30 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            window.layoutIfNeeded()
            if scroll.contentOffset == previous { stable += 1 } else { stable = 0 }
            previous = scroll.contentOffset
            if stable >= 3 { return }
        }
        XCTFail("Keyboard scroll did not settle within three seconds")
    }

    private func isVisible(_ view: UIView) -> Bool {
        if view.isHidden || view.alpha == 0 { return false }
        return view.superview.map { isVisible($0) } ?? true
    }

    private func assertInside(_ view: UIView, ancestor: UIView, file: StaticString = #filePath, line: UInt = #line) {
        let frame = view.convert(view.bounds, to: ancestor)
        XCTAssertGreaterThanOrEqual(frame.minX, -1, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, ancestor.bounds.width + 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minY, -1, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, ancestor.bounds.height + 1, file: file, line: line)
    }

    private func assertFits(_ label: UILabel, file: StaticString = #filePath, line: UInt = #line) {
        let fitting = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
        XCTAssertLessThanOrEqual(fitting.width, label.bounds.width + 1, file: file, line: line)
        XCTAssertLessThanOrEqual(fitting.height, label.bounds.height + 1, file: file, line: line)
    }

    func testLiveLocaleAndTypeReachCreatePresentation() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = AccountCreateViewController(presenter: Presenter(flow: .wallet))
        controller.localizationManager = localization
        let window = try show(controller, category: .large)
        defer { close(window) }
        configure(controller)
        await settle(window)
        let grid = try XCTUnwrap(controller.rootView.mnemonicView)
        let originalFont = grid.wordFontInColumn.pointSize
        capture(window, name: "live-en-large")
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
        localization.selectedLocalization = "ja"
        await settle(window)
        capture(window, name: "live-ja-AX5")
        XCTAssertEqual(controller.title, R.string.localizable.accountCreateTitle(preferredLanguages: ["ja"]))
        XCTAssertEqual(controller.rootView.nextButton.imageWithTitleView?.title, R.string.localizable.accountConfirmationTitle(preferredLanguages: ["ja"]))
        if FWAppearance.accountCreateRestyled { XCTAssertGreaterThan(grid.wordFontInColumn.pointSize, originalFont) }
        else { XCTAssertEqual(grid.wordFontInColumn.pointSize, originalFont) }
        assertDisplayedWords(grid, equal: fixtures("fixture", count: 24))
    }

    private func fixtures(_ prefix: String, count: Int) -> [String] {
        (0 ..< count).map { prefix + String(format: "%02d", $0 + 1) }
    }

    private func assertDisplayedWords(_ grid: MnemonicDisplayView, equal words: [String], file: StaticString = #filePath, line: UInt = #line) {
        let labels = descendants(grid).compactMap { $0 as? UILabel }.filter { !$0.isHidden }
        let displayed = labels.compactMap(\.text).filter { Int($0) == nil }
        XCTAssertEqual(displayed.sorted(), words.sorted(), file: file, line: line)
        let indexes = labels.compactMap(\.text).compactMap { Int($0) }.sorted()
        XCTAssertEqual(indexes, (0 ..< words.count).map { $0 + 1 }, file: file, line: line)
        if words.isEmpty { XCTAssertEqual(grid.intrinsicContentSize, .zero, file: file, line: line) }
        for column in grid.subviews {
            let columnLabels = column.subviews.compactMap { $0 as? UILabel }.filter { !$0.isHidden }
            for indexLabel in columnLabels {
                guard let text = indexLabel.text, let index = Int(text), index > 0, index <= words.count else { continue }
                let sameRow = columnLabels.filter { label in
                    label !== indexLabel && Int(label.text ?? "") == nil && abs(label.frame.midY - indexLabel.frame.midY) < 0.1
                }
                XCTAssertEqual(sameRow.count, 1, file: file, line: line)
                XCTAssertEqual(sameRow.first?.text, words[index - 1], file: file, line: line)
            }
            XCTAssertEqual(column.bounds.width, column.intrinsicContentSize.width, accuracy: 0.1, file: file, line: line)
            XCTAssertEqual(column.bounds.height, column.intrinsicContentSize.height, accuracy: 0.1, file: file, line: line)
        }
    }

    private func configure(_ controller: AccountCreateViewController) {
        // Public synthetic presentation data only; no generator, keychain, derivation or import runs.
        controller.set(mnemonic: fixtures("fixture", count: 24))
        controller.set(chainType: .both)
        controller.setSelectedSubstrateCrypto(model: SelectableViewModel(
            underlyingViewModel: TitleWithSubtitleViewModel(title: "sr25519", subtitle: "Schnorrkel"), selectable: true
        ))
        controller.setEthereumCrypto(model: TitleWithSubtitleViewModel(title: "ECDSA", subtitle: "secp256k1"))
        controller.bind(substrateViewModel: InputViewModel(inputHandler: InputHandler(value: "//Alice", required: true), placeholder: "//Alice"))
        controller.bind(ethereumViewModel: InputViewModel(inputHandler: InputHandler(value: "m/44'/60'/0'/0/0", required: true), placeholder: "m/44'/60'/0'/0/0"))
    }

    private func show(_ controller: UIViewController, category: UIContentSizeCategory) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        window.traitCollection.performAsCurrent {
            window.rootViewController = FearlessNavigationController(rootViewController: controller)
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
        }
        return window
    }

    private func settle(_ window: UIWindow) async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        for _ in 0 ..< 60 {
            window.layoutIfNeeded()
            let moving = descendants(window).contains { view in
                (view.layer.animationKeys() ?? []).contains { key in
                    key.hasPrefix("bounds") || key.hasPrefix("position") || view.layer.animation(forKey: key) is CATransition
                }
            }
            if !moving { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Create presentation animation did not settle")
    }

    private func close(_ window: UIWindow) {
        window.endEditing(true)
        window.isHidden = true
        window.rootViewController = nil
    }

    private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }

    private func capture(_ window: UIWindow, name: String) {
        XCTAssertFalse(descendants(window).contains { view in
            (view.layer.animationKeys() ?? []).contains { view.layer.animation(forKey: $0) is CATransition }
        }, "Capture must wait for the actual transition to finish: \(name)")
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        let picture = XCTAttachment(image: image)
        picture.name = "phrase-baseline-320x568-" + name
        picture.lifetime = .keepAlways
        add(picture)
        let metrics = descendants(window).compactMap { view -> String? in
            guard let label = view as? UILabel else { return nil }
            return "label=\(label.text ?? ""); font=\(label.font.fontName); size=\(label.font.pointSize); frame=\(label.convert(label.bounds, to: window)); fitting=\(label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)))"
        }.joined(separator: "\n")
        let diagnostic = XCTAttachment(string: metrics)
        diagnostic.name = "phrase-baseline-metrics-" + name
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
    }
}
