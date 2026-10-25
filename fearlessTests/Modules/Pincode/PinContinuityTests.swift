@testable import fearless
import SoraFoundation
import SoraKeystore
import SoraUI
import struct SSFModels.Currency
import SSFUtils
import UIKit
import LocalAuthentication
import XCTest

/// Presentation/input continuity only; this fixture never opens the keystore or signs.
@MainActor
final class PinContinuityTests: XCTestCase {
    private final class Presenter: PinSetupPresenterProtocol {
        var pins: [String] = []
        var cancellations = 0
        var biometrics = 0
        func didLoad(view _: PinSetupViewProtocol) {}
        func cancel() { cancellations += 1 }
        func activateBiometricAuth() { biometrics += 1 }
        func submit(pin: String) { pins.append(pin) }
    }

    @MainActor
    private struct Fixture {
        let controller: PinSetupViewController
        let presenter: Presenter
        let localization: LocalizationManager
        let window: UIWindow
        let pin: PinView
        let scroll: UIScrollView
        func close() { window.isHidden = true; window.rootViewController = nil }
    }

    func testProductionPinModesFitAllLocalesAtNormalAndMaximumType() async throws {
        for language in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                // Match production setup/change/unlock/authorization presentation.
                // unsecuredInput is additional SDK compatibility coverage only.
                let presentations: [(PinView.Mode, Bool, String)] = [
                    (.create, false, "setup"), (.create, false, "change"),
                    (.securedInput, false, "empty"), (.securedInput, true, "empty"),
                    (.unsecuredInput, true, "empty")
                ]
                for (mode, cancellable, heading) in presentations {
                    let fixture = try show(language: language, category: category, mode: mode, cancellable: cancellable, heading: heading)
                    defer { fixture.close() }
                    await Task.yield()
                    fixture.window.layoutIfNeeded()
                    try assertLayout(fixture)
                    let name = "\(language)-\(category.rawValue)-mode\(mode.rawValue)-\(heading)-cancel\(cancellable)"
                    fixture.scroll.setContentOffset(.zero, animated: false)
                    fixture.window.layoutIfNeeded()
                    capture(fixture, name: name + "-top")
                    try assertControlsReachable(fixture)
                    capture(fixture, name: name + "-bottom")
                }
            }
        }
    }

    func testCreateConfirmationBackspaceAndMismatchKeepExistingInputFlow() async throws {
        let fixture = try show(language: "ja", category: .accessibilityExtraExtraExtraLarge)
        defer { fixture.close() }
        await Task.yield()
        fixture.window.layoutIfNeeded()
        try enter("12", in: fixture)
        let backspace = try XCTUnwrap(controls(fixture).first { $0.accessibilityIdentifier == "BackspaceAccessibilityId" })
        try tap(backspace, in: fixture)
        try enter("23456", in: fixture)
        XCTAssertEqual(fixture.pin.creationState, .confirm)
        XCTAssertTrue(fixture.presenter.pins.isEmpty)
        XCTAssertTrue(fixture.pin.activeFieldsView.isEmpty)
        try await Task.sleep(nanoseconds: 500_000_000)
        try assertLayout(fixture)
        fixture.scroll.setContentOffset(.zero, animated: false)
        fixture.window.layoutIfNeeded()
        let bar = try XCTUnwrap(descendants(fixture.controller.view).compactMap { $0 as? UINavigationBar }.first)
        let back = try XCTUnwrap(descendants(bar).compactMap { $0 as? UIControl }.first { !$0.allTargets.isEmpty })
        let rect = back.convert(back.bounds, to: fixture.window)
        let hit = try XCTUnwrap(fixture.window.hitTest(CGPoint(x: rect.midX, y: rect.midY), with: nil))
        XCTAssertTrue(hit === back || hit.isDescendant(of: back))
        XCTAssertGreaterThan(back.alpha, 0.99)
        capture(fixture, name: "ja-AX5-confirm")
        try enter("654321", in: fixture)
        XCTAssertTrue(fixture.presenter.pins.isEmpty)
        XCTAssertTrue(fixture.pin.activeFieldsView.isEmpty)
        XCTAssertEqual(fixture.pin.creationState, .confirm)
        try enter("123456", in: fixture)
        XCTAssertEqual(fixture.presenter.pins, ["123456"])
    }

    func testBackFromConfirmationStartsFreshCreation() async throws {
        let fixture = try show(language: "en", category: .large)
        defer { fixture.close() }
        await Task.yield()
        try enter("123456", in: fixture)
        try await Task.sleep(nanoseconds: 500_000_000)
        fixture.window.layoutIfNeeded()
        let bar = try XCTUnwrap(descendants(fixture.controller.view).compactMap { $0 as? UINavigationBar }.first)
        let back = try XCTUnwrap(descendants(bar).compactMap { $0 as? UIControl }.first { !$0.allTargets.isEmpty })
        let rect = back.convert(back.bounds, to: fixture.window)
        let hit = try XCTUnwrap(fixture.window.hitTest(CGPoint(x: rect.midX, y: rect.midY), with: nil))
        XCTAssertTrue(hit === back || hit.isDescendant(of: back))
        back.sendActions(for: .touchUpInside)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(fixture.pin.creationState, .normal)
        XCTAssertTrue(fixture.pin.activeFieldsView.isEmpty)
        try enter("654321654321", in: fixture)
        XCTAssertEqual(fixture.presenter.pins, ["654321"])
    }

    func testExistingInputModesAndWrongPinResetRemainUsable() async throws {
        for mode in [PinView.Mode.securedInput, .unsecuredInput] {
            let fixture = try show(language: "vi", category: .accessibilityExtraExtraExtraLarge, mode: mode)
            defer { fixture.close() }
            await Task.yield()
            // Switching the legacy SDK to unused unsecuredInput creates four fields.
            // Preserve that existing contract; the production secured mode has six.
            let first = mode == .unsecuredInput ? "1234" : "123456"
            let second = mode == .unsecuredInput ? "4321" : "654321"
            try enter(first, in: fixture)
            XCTAssertEqual(fixture.presenter.pins, [first])
            fixture.controller.didReceiveWrongPincode()
            XCTAssertTrue(fixture.pin.activeFieldsView.isEmpty)
            try enter(second, in: fixture)
            XCTAssertEqual(fixture.presenter.pins, [first, second])
        }
    }

    func testCancelAndBiometricActionsRemainReachableAfterScrolling() async throws {
        let fixture = try show(language: "pt-PT", category: .accessibilityExtraExtraExtraLarge, mode: .securedInput)
        defer { fixture.close() }
        await Task.yield()
        fixture.controller.didChangeAccessoryState(enabled: true, availableBiometryType: .faceId)
        fixture.window.layoutIfNeeded()
        let accessory = try XCTUnwrap(controls(fixture).first {
            ($0.imageWithTitleView?.title ?? "").isEmpty && $0.accessibilityIdentifier != "BackspaceAccessibilityId"
        })
        try tap(accessory, in: fixture)
        XCTAssertEqual(fixture.presenter.biometrics, 1)
        let cancel = try XCTUnwrap(descendants(fixture.controller.view).compactMap { $0 as? UIButton }.first)
        try tap(cancel, in: fixture)
        XCTAssertEqual(fixture.presenter.cancellations, 1)
        XCTAssertTrue(fixture.presenter.pins.isEmpty)
    }

    func testLiveLocaleAndDynamicTypeChangesPreserveEnteredPin() async throws {
        let fixture = try show(language: "en", category: .large)
        defer { fixture.close() }
        await Task.yield()
        try enter("12", in: fixture)
        let initial = try XCTUnwrap(fixture.pin.numpadView?.titleFont).pointSize
        for language in ["ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi", "en"] {
            fixture.localization.selectedLocalization = language
            if #available(iOS 17.0, *) {
                fixture.window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
            }
            for _ in 0 ..< 3 { await Task.yield() }
            fixture.window.layoutIfNeeded()
            XCTAssertEqual(fixture.controller.topLabel.text, R.string.localizable.pincodeSetupTopTitle(preferredLanguages: fixture.localization.selectedLocale.rLanguages))
            XCTAssertGreaterThan(try XCTUnwrap(fixture.pin.numpadView?.titleFont).pointSize, initial)
            try assertLayout(fixture)
            try assertControlsReachable(fixture)
        }
        if #available(iOS 17.0, *) { fixture.window.traitOverrides.preferredContentSizeCategory = .large }
        for _ in 0 ..< 3 { await Task.yield() }
        fixture.window.layoutIfNeeded()
        XCTAssertEqual(try XCTUnwrap(fixture.pin.numpadView?.titleFont).pointSize, initial, accuracy: 0.01)
        try enter("3456123456", in: fixture)
        XCTAssertEqual(fixture.presenter.pins, ["123456"])
    }

    func testLiveBoldTextKeepsMaximumTypeKeypadAndHeadingsReachable() async throws {
        let fixture = try show(language: "en", category: .accessibilityExtraExtraExtraLarge, cancellable: false)
        defer { fixture.close() }
        await Task.yield()
        let initial = try XCTUnwrap(fixture.pin.numpadView?.titleFont)
        if #available(iOS 17.0, *) { fixture.window.traitOverrides.legibilityWeight = .bold }
        for _ in 0 ..< 3 { await Task.yield() }
        fixture.window.layoutIfNeeded()
        let bold = try XCTUnwrap(fixture.pin.numpadView?.titleFont)
        let initialTraits = try XCTUnwrap(initial.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any])
        let boldTraits = try XCTUnwrap(bold.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any])
        XCTAssertGreaterThan(try XCTUnwrap(boldTraits[.weight] as? NSNumber).doubleValue, try XCTUnwrap(initialTraits[.weight] as? NSNumber).doubleValue)
        XCTAssertTrue(fixture.controller.topLabel.font.fontName.contains("Bold"))
        try assertLayout(fixture)
        capture(fixture, name: "en-AX5-live-bold-top")
        try assertControlsReachable(fixture)
        capture(fixture, name: "en-AX5-live-bold-bottom")
        if #available(iOS 17.0, *) { fixture.window.traitOverrides.legibilityWeight = .regular }
        for _ in 0 ..< 3 { await Task.yield() }
        fixture.window.layoutIfNeeded()
        XCTAssertEqual(fixture.pin.numpadView?.titleFont, initial)
        try assertLayout(fixture)
    }

    private func show(
        language: String, category: UIContentSizeCategory, mode: PinView.Mode = .create,
        cancellable: Bool = true, heading: String = "setup"
    ) throws -> Fixture {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let presenter = Presenter()
        let localization = try XCTUnwrap(LocalizationManager(localization: language))
        let controller = PinSetupViewController(nib: R.nib.pinSetupViewController)
        controller.presenter = presenter
        controller.localizationManager = localization
        controller.mode = mode
        controller.cancellable = cancellable
        controller.localizableTopTitle = LocalizableResource { locale in
            if heading == "empty" { return "" }
            if heading == "change" { return R.string.localizable.profilePincodeChangeTitle(preferredLanguages: locale.rLanguages) }
            return R.string.localizable.pincodeSetupTopTitle(preferredLanguages: locale.rLanguages)
        }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        window.traitCollection.performAsCurrent {
            window.rootViewController = controller
            controller.loadViewIfNeeded()
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
        }
        let pin = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? PinView }.first)
        let scroll = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIScrollView }.first)
        return Fixture(controller: controller, presenter: presenter, localization: localization, window: window, pin: pin, scroll: scroll)
    }

    private func assertLayout(_ fixture: Fixture, file: StaticString = #filePath, line: UInt = #line) throws {
        fixture.window.layoutIfNeeded()
        let allLabels = try XCTUnwrap(fixture.controller.topLabel.superview).subviews.compactMap { $0 as? UILabel }
        let error = try XCTUnwrap(allLabels.first { $0.accessibilityIdentifier == "PinSaveFailure" })
        XCTAssertTrue(error.isHidden, "Untouched PIN screens must not show a persistence error", file: file, line: line)
        let labels = allLabels.filter { $0 !== error }
        XCTAssertEqual(labels.count, 2, file: file, line: line)
        for label in labels {
            let fitting = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
            XCTAssertLessThanOrEqual(fitting.height, label.bounds.height + 1, "Full localized instruction must fit", file: file, line: line)
            XCTAssertLessThanOrEqual(fitting.width, label.bounds.width + 1, file: file, line: line)
        }
        let sorted = labels.sorted { $0.frame.minY < $1.frame.minY }
        XCTAssertLessThanOrEqual(sorted[0].frame.maxY + 15, sorted[1].frame.minY, file: file, line: line)
        XCTAssertLessThanOrEqual(sorted[1].frame.maxY + 15, fixture.pin.frame.minY, file: file, line: line)
        XCTAssertGreaterThanOrEqual(fixture.pin.bounds.height + 1, fixture.pin.intrinsicContentSize.height, file: file, line: line)
        XCTAssertGreaterThanOrEqual(fixture.pin.bounds.width + 1, fixture.pin.intrinsicContentSize.width, file: file, line: line)
        XCTAssertLessThanOrEqual(fixture.scroll.contentSize.width, fixture.scroll.bounds.width + 1, file: file, line: line)
    }

    private func assertControlsReachable(_ fixture: Fixture) throws {
        XCTAssertEqual(controls(fixture).filter { Int($0.imageWithTitleView?.title ?? "") != nil }.count, 10)
        for control in controls(fixture) {
            try reveal(control, in: fixture)
            XCTAssertGreaterThanOrEqual(control.bounds.width, 48)
            XCTAssertGreaterThanOrEqual(control.bounds.height, 48)
        }
        let buttons = descendants(fixture.controller.view).compactMap { $0 as? UIButton }
        if fixture.controller.cancellable {
            let cancel = try XCTUnwrap(buttons.first)
            try reveal(cancel, in: fixture)
            XCTAssertGreaterThanOrEqual(cancel.bounds.height, 48)
        } else {
            XCTAssertTrue(buttons.isEmpty)
        }
    }

    private func enter(_ digits: String, in fixture: Fixture) throws {
        for digit in digits {
            let control = try XCTUnwrap(controls(fixture).first { $0.imageWithTitleView?.title == String(digit) })
            try tap(control, in: fixture)
        }
    }

    private func tap(_ control: UIControl, in fixture: Fixture) throws {
        try reveal(control, in: fixture)
        control.sendActions(for: .touchUpInside)
        fixture.window.layoutIfNeeded()
    }

    private func reveal(_ control: UIView, in fixture: Fixture) throws {
        fixture.scroll.scrollRectToVisible(control.convert(control.bounds, to: fixture.scroll), animated: false)
        fixture.window.layoutIfNeeded()
        let rect = control.convert(control.bounds, to: fixture.window)
        let viewport = fixture.scroll.convert(fixture.scroll.bounds, to: fixture.window)
        XCTAssertTrue(viewport.insetBy(dx: -1, dy: -1).contains(rect), "Control must be wholly reachable: \(rect); viewport: \(viewport)")
        let hit = try XCTUnwrap(fixture.window.hitTest(CGPoint(x: rect.midX, y: rect.midY), with: nil))
        XCTAssertTrue(hit === control || hit.isDescendant(of: control))
    }

    private func controls(_ fixture: Fixture) -> [RoundedButton] {
        fixture.pin.numpadView?.subviews.compactMap { $0 as? RoundedButton } ?? []
    }

    private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }

    private func capture(_ fixture: Fixture, name: String) {
        let image = UIGraphicsImageRenderer(bounds: fixture.window.bounds).image { _ in
            XCTAssertTrue(fixture.window.drawHierarchy(in: fixture.window.bounds, afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "pin-accessibility-320x568-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}


/// Actual authentication state/presenters with controlled public secret and biometric replies.
/// No device keychain or LAContext is used by these ownership tests.
@MainActor
final class LocalAuthOwnershipTests: XCTestCase {
    private final class Secrets: SecretStoreManagerProtocol {
        var loads: [(DispatchQueue, (SecretDataRepresentable?) -> Void)] = []
        func loadSecret(for _: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void) {
            loads.append((completionQueue, completionBlock))
        }
        func answer(_ index: Int, _ pin: String?) {
            let (queue, completion) = loads[index]
            queue.async { completion(pin) }
        }
        func saveSecret(_: SecretDataRepresentable, for _: String, completionQueue _: DispatchQueue, completionBlock _: @escaping (Bool) -> Void) { XCTFail("Authentication must not save a secret") }
        func removeSecret(for _: String, completionQueue _: DispatchQueue, completionBlock _: @escaping (Bool) -> Void) { XCTFail("Authentication must not remove a secret") }
        func checkSecret(for _: String, completionQueue _: DispatchQueue, completionBlock: @escaping (Bool) -> Void) { completionBlock(true) }
        func checkSecret(for _: String) -> Bool { true }
    }

    private final class Settings: SettingsManagerProtocol {
        private var values: [String: Any] = [:]
        func set(value: Bool, for key: String) { values[key] = value }
        func set(value: Int, for key: String) { values[key] = value }
        func set(value: Double, for key: String) { values[key] = value }
        func set(value: String, for key: String) { values[key] = value }
        func set(value: Data, for key: String) { values[key] = value }
        func set(anyValue: Any, for key: String) { values[key] = anyValue }
        func bool(for key: String) -> Bool? { values[key] as? Bool }
        func integer(for key: String) -> Int? { values[key] as? Int }
        func double(for key: String) -> Double? { values[key] as? Double }
        func string(for key: String) -> String? { values[key] as? String }
        func data(for key: String) -> Data? { values[key] as? Data }
        func anyValue(for key: String) -> Any? { values[key] }
        func removeValue(for key: String) { values.removeValue(forKey: key) }
        func removeAll() { values.removeAll() }
    }

    private final class Biometry: BiometryAuthProtocol {
        var availableBiometryType = AvailableBiometryType.faceId
        var replies: [(DispatchQueue, (Bool) -> Void)] = []
        func authenticate(localizedReason _: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
            replies.append((completionQueue, completionBlock))
        }
        func answer(_ index: Int, _ result: Bool) {
            let (queue, completion) = replies[index]
            queue.async { completion(result) }
        }
    }

    private final class View: UIViewController, PinSetupViewProtocol {
        func didFailSavingPin() {}
        var wrongPins = 0
        var resets = 0
        func resetAuthenticationInput() { resets += 1 }
        func didRequestBiometryUsage(biometryType _: AvailableBiometryType, completionBlock _: @escaping (Bool) -> Void) {}
        func didChangeAccessoryState(enabled _: Bool, availableBiometryType _: AvailableBiometryType) {}
        func didReceiveWrongPincode() { wrongPins += 1 }
    }

    private final class Wireframe: ScreenAuthorizationWireframeProtocol {
        var results: [Bool] = []
        func showAuthorizationCompletion(with result: Bool) { results.append(result) }
    }

    private final class CheckOutput: CheckPincodeModuleOutput {
        var checks = 0
        var closes = 0
        func didCheck() { checks += 1 }
        func close(view _: ControllerBackedProtocol?) { closes += 1 }
    }

    private final class Output: LocalAuthInteractorOutputProtocol {
        var completions = 0
        var wrongPins = 0
        var states: [LocalAuthInteractor.LocalAuthState] = []
        func didEnterWrongPincode() { wrongPins += 1 }
        func didChangeState(to state: LocalAuthInteractor.LocalAuthState) { XCTAssertTrue(Thread.isMainThread); states.append(state) }
        func didCompleteAuth() { XCTAssertTrue(Thread.isMainThread); completions += 1 }
        func didUnexpectedFail() { XCTFail("Unexpected authentication failure") }
    }

    private final class MainWireframe: PinSetupWireframeProtocol {
        var main = 0
        var signup = 0
        func showMain(from _: PinSetupViewProtocol?) { main += 1 }
        func showSignup(from _: PinSetupViewProtocol?) { signup += 1 }
    }

    private struct Fixture {
        let secrets = Secrets()
        let settings = Settings()
        let biometry = Biometry()
        let interactor: LocalAuthInteractor
        init(biometric: Bool = false) {
            settings.biometryEnabled = biometric
            interactor = LocalAuthInteractor(secretManager: secrets, settingsManager: settings, biometryAuth: biometry, locale: Locale(identifier: "en"))
        }
    }

    private func settle() async throws {
        // Allow actual production global callback -> main presentation delivery.
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    func testQueuedSuccessCannotAuthorizeAfterDepartureWasCancelled() async throws {
        let f = Fixture(biometric: true)
        let wireframe = Wireframe()
        let presenter = ScreenAuthorizationPresenter(wireframe: wireframe, interactor: f.interactor)
        let view = View()
        presenter.didLoad(view: view)
        presenter.didCompleteAuth()
        presenter.willLeaveView()
        presenter.didCancelLeavingView()
        try await settle()
        XCTAssertTrue(wireframe.results.isEmpty, "A queued success from the retired attempt cannot authorize the restarted screen")
        f.biometry.answer(1, true)
        try await settle()
        XCTAssertEqual(wireframe.results, [true])
    }

    func testCancelledDepartureRestartsInputWithoutAcceptingOldBiometry() async throws {
        let f = Fixture(biometric: true)
        let wireframe = Wireframe()
        let presenter = ScreenAuthorizationPresenter(wireframe: wireframe, interactor: f.interactor)
        let view = View()
        presenter.didLoad(view: view)
        presenter.willLeaveView()
        presenter.didCompleteAuth()
        f.biometry.answer(0, true)
        try await settle()
        XCTAssertTrue(wireframe.results.isEmpty)
        presenter.didCancelLeavingView()
        XCTAssertEqual(view.resets, 1)
        XCTAssertEqual(f.biometry.replies.count, 2)
        f.biometry.answer(0, true)
        try await settle()
        XCTAssertTrue(wireframe.results.isEmpty)
        f.biometry.answer(1, true)
        try await settle()
        XCTAssertEqual(wireframe.results, [true])
    }

    func testCancelledScreenIgnoresLateCorrectPin() async throws {
        let f = Fixture()
        let wireframe = Wireframe()
        let presenter = ScreenAuthorizationPresenter(wireframe: wireframe, interactor: f.interactor)
        let view = View()
        presenter.didLoad(view: view)
        presenter.submit(pin: "123456")
        presenter.cancel()
        f.secrets.answer(0, "123456")
        try await settle()
        XCTAssertEqual(wireframe.results, [false])
    }

    func testCancelledScreenIgnoresLateSuccessfulBiometry() async throws {
        let f = Fixture(biometric: true)
        let wireframe = Wireframe()
        let presenter = ScreenAuthorizationPresenter(wireframe: wireframe, interactor: f.interactor)
        let view = View()
        presenter.didLoad(view: view)
        presenter.cancel()
        f.biometry.answer(0, true)
        try await settle()
        XCTAssertEqual(wireframe.results, [false])
    }

    func testCancellationWinsBeforeQueuedPresenterCompletionAndIsTerminal() async throws {
        let f = Fixture()
        let wireframe = Wireframe()
        let presenter = ScreenAuthorizationPresenter(wireframe: wireframe, interactor: f.interactor)
        let view = View()
        presenter.didLoad(view: view)
        presenter.didCompleteAuth()
        presenter.cancel()
        presenter.cancel()
        try await settle()
        XCTAssertEqual(wireframe.results, [false])
        presenter.submit(pin: "123456")
        presenter.activateBiometricAuth()
        XCTAssertTrue(f.secrets.loads.isEmpty)
    }

    func testCancelledPincodeCheckCannotAuthorizeLatePinOrQueuedCompletion() async throws {
        let f = Fixture()
        let output = CheckOutput()
        let presenter = CheckPincodePresenter(interactor: f.interactor, moduleOutput: output)
        let view = View()
        presenter.didLoad(view: view)
        presenter.submit(pin: "123456")
        presenter.cancel()
        f.secrets.answer(0, "123456")
        presenter.didCompleteAuth()
        try await settle()
        XCTAssertEqual(output.closes, 1)
        XCTAssertEqual(output.checks, 0)
    }

    func testObsoleteBiometryCannotCompleteANewerRetry() async throws {
        let f = Fixture(biometric: true)
        let output = Output()
        f.interactor.startAuth(with: output)
        f.interactor.process(pin: "000000")
        f.secrets.answer(0, "123456")
        try await settle()
        XCTAssertEqual(output.wrongPins, 1)
        f.interactor.startAuth(with: output)
        XCTAssertEqual(f.biometry.replies.count, 2)
        f.biometry.answer(0, true)
        try await settle()
        XCTAssertEqual(output.completions, 0)
        f.biometry.answer(1, false)
        try await settle()
        f.interactor.process(pin: "123456")
        XCTAssertEqual(f.secrets.loads.count, 2)
        if f.secrets.loads.count == 2 { f.secrets.answer(1, "123456") }
        try await settle()
        XCTAssertEqual(output.completions, 1)
    }

    func testRebindingOutputDoesNotDeliverAnOldPinToTheNewOwner() async throws {
        let f = Fixture()
        let old = Output()
        let current = Output()
        f.interactor.startAuth(with: old)
        f.interactor.process(pin: "123456")
        f.interactor.startAuth(with: current)
        f.secrets.answer(0, "123456")
        try await settle()
        XCTAssertEqual(old.completions, 0)
        XCTAssertEqual(current.completions, 0)
        f.interactor.process(pin: "654321")
        XCTAssertEqual(f.secrets.loads.count, 2)
        if f.secrets.loads.count == 2 { f.secrets.answer(1, "654321") }
        try await settle()
        XCTAssertEqual(current.completions, 1)
    }

    func testWrongPinThenValidPinCompletesCurrentScreenOnce() async throws {
        let f = Fixture()
        let wireframe = Wireframe()
        let presenter = ScreenAuthorizationPresenter(wireframe: wireframe, interactor: f.interactor)
        let view = View()
        presenter.didLoad(view: view)
        presenter.submit(pin: "000000")
        f.secrets.answer(0, "123456")
        try await settle()
        XCTAssertEqual(view.wrongPins, 1)
        XCTAssertTrue(wireframe.results.isEmpty)
        presenter.submit(pin: "123456")
        f.secrets.answer(1, "123456")
        try await settle()
        XCTAssertEqual(wireframe.results, [true])
        presenter.didCompleteAuth()
        try await settle()
        XCTAssertEqual(wireframe.results, [true])
    }

    func testDirectCancellationClearsPinAndFencesTheSameOwnerOnRestart() async throws {
        let f = Fixture()
        let output = Output()
        f.interactor.startAuth(with: output)
        f.interactor.process(pin: "123456")
        f.interactor.cancelAuth()
        XCTAssertNil(f.interactor.pincode)
        f.interactor.startAuth(with: output)
        f.interactor.process(pin: "654321")
        f.secrets.answer(0, "123456")
        try await settle()
        XCTAssertEqual(output.completions, 0)
        f.secrets.answer(1, "654321")
        try await settle()
        XCTAssertEqual(output.completions, 1)
        XCTAssertNil(f.interactor.pincode)
    }

    func testCurrentBiometryCompletesOnceAndMissingStoredPinDoesNotAuthenticate() async throws {
        let biometric = Fixture(biometric: true)
        let output = Output()
        biometric.interactor.startAuth(with: output)
        biometric.biometry.answer(0, true)
        try await settle()
        biometric.biometry.answer(0, true)
        biometric.interactor.startAuth(with: output)
        try await settle()
        XCTAssertEqual(output.completions, 1)
        XCTAssertEqual(biometric.biometry.replies.count, 1)

        let pin = Fixture()
        let pinOutput = Output()
        pin.interactor.startAuth(with: pinOutput)
        pin.interactor.process(pin: "123456")
        pin.secrets.answer(0, nil)
        try await settle()
        XCTAssertEqual(pinOutput.completions, 0)
        XCTAssertEqual(pinOutput.wrongPins, 1)
    }

    func testCurrentCheckAndUnlockPresentersStillCompleteAfterBiometricFallback() async throws {
        let f = Fixture(biometric: true)
        let wireframe = MainWireframe()
        let presenter = LocalAuthPresenter(wireframe: wireframe, interactor: f.interactor)
        let view = View()
        presenter.didLoad(view: view)
        f.biometry.answer(0, false)
        try await settle()
        presenter.submit(pin: "123456")
        f.secrets.answer(0, "123456")
        try await settle()
        XCTAssertEqual(wireframe.main, 1)
        XCTAssertEqual(wireframe.signup, 0)
        let check = Fixture()
        let output = CheckOutput()
        let checkPresenter = CheckPincodePresenter(interactor: check.interactor, moduleOutput: output)
        checkPresenter.didLoad(view: view)
        checkPresenter.submit(pin: "123456")
        check.secrets.answer(0, "123456")
        try await settle()
        checkPresenter.didCompleteAuth()
        checkPresenter.cancel()
        try await settle()
        XCTAssertEqual(output.checks, 1)
        XCTAssertEqual(output.closes, 0)
    }

    func testActualPinControlsCancelBeforeLateReplyAndAuthorizeOnlyTheNextScreen() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for language in ["en", "ru"] {
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
            window.overrideUserInterfaceStyle = .dark
            if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
            defer { window.isHidden = true; window.rootViewController = nil }
            let wireframe = Wireframe()
            let first = Fixture()
            let firstPresenter = ScreenAuthorizationPresenter(wireframe: wireframe, interactor: first.interactor)
            let firstController = try show(firstPresenter, language: language, in: window)
            try await settle()
            try tapDigits("123456", controller: firstController, window: window)
            XCTAssertEqual(first.secrets.loads.count, 1)
            let cancel = try XCTUnwrap(descendants(firstController.view).compactMap { $0 as? UIButton }.first)
            try tap(cancel, controller: firstController, window: window)
            XCTAssertEqual(wireframe.results, [false])
            capture(window, name: "actual-auth-cancel-" + language + "-AX5")

            let second = Fixture()
            let secondPresenter = ScreenAuthorizationPresenter(wireframe: wireframe, interactor: second.interactor)
            let secondController = try show(secondPresenter, language: language, in: window)
            try await settle()
            try tapDigits("654321", controller: secondController, window: window)
            XCTAssertEqual(second.secrets.loads.count, 1)
            first.secrets.answer(0, "123456")
            try await settle()
            XCTAssertEqual(wireframe.results, [false])
            second.secrets.answer(0, "654321")
            try await settle()
            XCTAssertEqual(wireframe.results, [false, true])
            capture(window, name: "actual-auth-next-screen-" + language + "-AX5")
        }
    }

    private func show(_ presenter: PinSetupPresenterProtocol, language: String, in window: UIWindow) throws -> PinSetupViewController {
        let controller = PinSetupViewController(nib: R.nib.pinSetupViewController)
        controller.presenter = presenter
        controller.mode = .securedInput
        controller.cancellable = true
        controller.localizationManager = try XCTUnwrap(LocalizationManager(localization: language))
        window.traitCollection.performAsCurrent {
            window.rootViewController = controller
            controller.loadViewIfNeeded()
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
        }
        return controller
    }

    private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }

    private func tapDigits(_ pin: String, controller: PinSetupViewController, window: UIWindow) throws {
        let pinView = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? PinView }.first)
        for digit in pin {
            let control = try XCTUnwrap(pinView.numpadView?.subviews.compactMap { $0 as? RoundedButton }.first { $0.imageWithTitleView?.title == String(digit) })
            try tap(control, controller: controller, window: window)
        }
    }

    private func tap(_ control: UIControl, controller: PinSetupViewController, window: UIWindow) throws {
        let scroll = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIScrollView }.first)
        scroll.scrollRectToVisible(control.convert(control.bounds, to: scroll), animated: false)
        window.layoutIfNeeded()
        let rect = control.convert(control.bounds, to: window)
        let hit = try XCTUnwrap(window.hitTest(CGPoint(x: rect.midX, y: rect.midY), with: nil))
        XCTAssertTrue(hit === control || hit.isDescendant(of: control))
        control.sendActions(for: .touchUpInside)
        window.layoutIfNeeded()
    }

    private func capture(_ window: UIWindow, name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// Actual PIN persistence with controlled public in-memory acknowledgements.
@MainActor
final class PinPersistenceTests: XCTestCase {
    private final class Secrets: SecretStoreManagerProtocol {
        var saves: [(String, DispatchQueue, (Bool) -> Void)] = []
        var savedPin: String? = "111111"
        func saveSecret(_ secret: SecretDataRepresentable, for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
            XCTAssertEqual(identifier, KeystoreTag.pincode.rawValue)
            let pin = secret.asSecretData().flatMap { String(data: $0, encoding: .utf8) } ?? ""
            saves.append((pin, completionQueue, completionBlock))
        }
        func answer(_ index: Int, _ success: Bool) {
            let (pin, queue, completion) = saves[index]
            if success { savedPin = pin }
            queue.async { completion(success) }
        }
        func loadSecret(for _: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void) { completionQueue.async { completionBlock(self.savedPin) } }
        func removeSecret(for _: String, completionQueue _: DispatchQueue, completionBlock _: @escaping (Bool) -> Void) { XCTFail("PIN persistence must not remove secrets") }
        func checkSecret(for _: String, completionQueue _: DispatchQueue, completionBlock: @escaping (Bool) -> Void) { completionBlock(savedPin != nil) }
        func checkSecret(for _: String) -> Bool { savedPin != nil }
    }
    private final class Settings: SettingsManagerProtocol {
        private var values: [String: Any] = [:]
        func set(value: Bool, for key: String) { values[key] = value }
        func set(value: Int, for key: String) { values[key] = value }
        func set(value: Double, for key: String) { values[key] = value }
        func set(value: String, for key: String) { values[key] = value }
        func set(value: Data, for key: String) { values[key] = value }
        func set(anyValue: Any, for key: String) { values[key] = anyValue }
        func bool(for key: String) -> Bool? { values[key] as? Bool }
        func integer(for key: String) -> Int? { values[key] as? Int }
        func double(for key: String) -> Double? { values[key] as? Double }
        func string(for key: String) -> String? { values[key] as? String }
        func data(for key: String) -> Data? { values[key] as? Data }
        func anyValue(for key: String) -> Any? { values[key] }
        func removeValue(for key: String) { values.removeValue(forKey: key) }
        func removeAll() { values.removeAll() }
    }
    private final class Biometry: BiometryAuthProtocol {
        var availableBiometryType = AvailableBiometryType.none
        var replies: [(DispatchQueue, (Bool) -> Void)] = []
        func authenticate(localizedReason _: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) { replies.append((completionQueue, completionBlock)) }
        func answer(_ index: Int, _ result: Bool) { let (queue, completion) = replies[index]; queue.async { completion(result) } }
    }
    private final class Output: PinSetupInteractorOutputProtocol {
        var saved = 0
        var decisions: [(Bool) -> Void] = []
        var states: [PinSetupInteractor.PinSetupState] = []
        func didSavePin() { XCTAssertTrue(Thread.isMainThread); saved += 1 }
        func didStartWaitingBiometryDecision(type _: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void) { decisions.append(completionBlock) }
        func didChangeState(to state: PinSetupInteractor.PinSetupState) { states.append(state) }
    }
    private final class View: UIViewController, PinSetupViewProtocol {
        func didFailSavingPin() {}
        func didRequestBiometryUsage(biometryType _: AvailableBiometryType, completionBlock _: @escaping (Bool) -> Void) {}
        func didChangeAccessoryState(enabled _: Bool, availableBiometryType _: AvailableBiometryType) {}
        func didReceiveWrongPincode() {}
    }
    private final class Wireframe: PinSetupWireframeProtocol {
        var main = 0
        func showMain(from _: PinSetupViewProtocol?) { main += 1 }
        func showSignup(from _: PinSetupViewProtocol?) {}
    }
    private func settle() async throws { try await Task.sleep(nanoseconds: 100_000_000) }

    func testFailedSetupDoesNotCompleteAndCanRetry() async throws {
        let secrets = Secrets(); secrets.savedPin = nil
        let settings = Settings(); let biometry = Biometry(); let output = Output()
        let interactor = PinSetupInteractor(secretManager: secrets, settingsManager: settings, biometryAuth: biometry, locale: Locale(identifier: "en"))
        interactor.presenter = output
        interactor.process(pin: "123456")
        secrets.answer(0, false)
        try await settle()
        XCTAssertEqual(output.saved, 0)
        XCTAssertNil(secrets.savedPin)
        XCTAssertNil(interactor.pincode)
        interactor.process(pin: "654321")
        XCTAssertEqual(secrets.saves.count, 2)
        if secrets.saves.count == 2 { secrets.answer(1, true) }
        try await settle()
        XCTAssertEqual(output.saved, 1)
        XCTAssertEqual(secrets.savedPin, "654321")
    }

    func testBiometryPreferenceChangesOnlyAfterSuccessfulPinWrite() async throws {
        let secrets = Secrets(); let settings = Settings(); settings.biometryEnabled = false
        let biometry = Biometry(); biometry.availableBiometryType = .faceId
        let output = Output()
        let interactor = PinSetupInteractor(secretManager: secrets, settingsManager: settings, biometryAuth: biometry, locale: Locale(identifier: "en"))
        interactor.presenter = output
        interactor.process(pin: "123456")
        biometry.answer(0, true)
        try await settle()
        XCTAssertEqual(settings.biometryEnabled, false)
        secrets.answer(0, false)
        try await settle()
        XCTAssertEqual(settings.biometryEnabled, false)
        XCTAssertEqual(output.saved, 0)
    }

    func testFailedChangeRetainsPriorPinAndDoesNotNavigateThenRetrySucceeds() async throws {
        let secrets = Secrets(); let interactor = PinChangeInteractor(secretManager: secrets)
        let wireframe = Wireframe(); let view = View()
        let presenter = PinSetupPresenter(interactor: interactor, wireframe: wireframe)
        interactor.presenter = presenter; presenter.didLoad(view: view)
        presenter.submit(pin: "123456")
        secrets.answer(0, false)
        try await settle()
        XCTAssertEqual(secrets.savedPin, "111111")
        XCTAssertEqual(wireframe.main, 0)
        presenter.submit(pin: "654321")
        secrets.answer(1, true)
        try await settle()
        XCTAssertEqual(secrets.savedPin, "654321")
        XCTAssertEqual(wireframe.main, 1)
    }

    func testChangeRejectsDuplicateSubmissionAndDuplicateAcknowledgement() async throws {
        let secrets = Secrets(); let interactor = PinChangeInteractor(secretManager: secrets); let output = Output()
        interactor.presenter = output
        interactor.process(pin: "123456")
        interactor.process(pin: "654321")
        XCTAssertEqual(secrets.saves.count, 1)
        secrets.answer(0, true)
        try await settle()
        secrets.answer(0, true)
        try await settle()
        XCTAssertEqual(output.saved, 1)
    }

    func testCancelledPresenterDoesNotNavigateOnLateWriteAcknowledgement() async throws {
        let secrets = Secrets(); let interactor = PinChangeInteractor(secretManager: secrets)
        let wireframe = Wireframe(); let view = View()
        let presenter = PinSetupPresenter(interactor: interactor, wireframe: wireframe)
        interactor.presenter = presenter; presenter.didLoad(view: view)
        presenter.submit(pin: "123456")
        presenter.cancel()
        secrets.answer(0, true)
        try await settle()
        XCTAssertEqual(wireframe.main, 0)
        presenter.submit(pin: "654321")
        XCTAssertEqual(secrets.saves.count, 1)
    }

    func testSetupRetryRejectsObsoleteBiometryAndSaveCallbacks() async throws {
        let secrets = Secrets(); let settings = Settings(); settings.biometryEnabled = false
        let biometry = Biometry(); biometry.availableBiometryType = .faceId; let output = Output()
        let interactor = PinSetupInteractor(secretManager: secrets, settingsManager: settings, biometryAuth: biometry, locale: Locale(identifier: "en"))
        interactor.presenter = output
        interactor.process(pin: "123456"); biometry.answer(0, true)
        try await settle(); secrets.answer(0, false); try await settle()
        interactor.process(pin: "654321")
        biometry.answer(0, true); secrets.answer(0, false)
        try await settle()
        XCTAssertEqual(secrets.saves.count, 1)
        XCTAssertEqual(output.saved, 0)
        biometry.answer(1, true); try await settle()
        XCTAssertEqual(secrets.saves.count, 2)
        XCTAssertEqual(settings.biometryEnabled, false)
        secrets.answer(1, true); try await settle()
        XCTAssertEqual(settings.biometryEnabled, true)
        XCTAssertEqual(output.saved, 1)
        XCTAssertEqual(secrets.savedPin, "654321")
        secrets.answer(1, true); try await settle()
        XCTAssertEqual(output.saved, 1)
    }

    func testTouchDecisionAcceptAndSkipWaitForPersistence() async throws {
        for enable in [true, false] {
            let secrets = Secrets(); let settings = Settings(); settings.biometryEnabled = !enable
            let biometry = Biometry(); biometry.availableBiometryType = .touchId; let output = Output()
            let interactor = PinSetupInteractor(secretManager: secrets, settingsManager: settings, biometryAuth: biometry, locale: Locale(identifier: "en"))
            interactor.presenter = output; interactor.process(pin: "123456")
            XCTAssertEqual(output.decisions.count, 1); XCTAssertTrue(secrets.saves.isEmpty)
            output.decisions[0](enable)
            XCTAssertEqual(settings.biometryEnabled, !enable)
            secrets.answer(0, true); try await settle()
            XCTAssertEqual(settings.biometryEnabled, enable)
            XCTAssertEqual(output.saved, 1)
            XCTAssertNil(interactor.pincode)
        }
    }

    func testCancellationAndRebindingCannotSaveFromLateBiometricDecision() async throws {
        for type in [AvailableBiometryType.faceId, .touchId] {
            for cancel in [true, false] {
                let secrets = Secrets(); let settings = Settings(); settings.biometryEnabled = false
                let biometry = Biometry(); biometry.availableBiometryType = type
                let output = Output(); let replacement = Output()
                let interactor = PinSetupInteractor(secretManager: secrets, settingsManager: settings, biometryAuth: biometry, locale: Locale(identifier: "en"))
                interactor.presenter = output; interactor.process(pin: "123456")
                if cancel { interactor.cancel(); XCTAssertNil(interactor.pincode) } else { interactor.presenter = replacement }
                if type == .faceId { biometry.answer(0, true) } else { output.decisions[0](true) }
                try await settle()
                XCTAssertTrue(secrets.saves.isEmpty)
                XCTAssertEqual(settings.biometryEnabled, false)
                XCTAssertEqual(output.saved + replacement.saved, 0)
            }
        }
    }

    func testCancelledSetupDoesNotApplyBiometryOnLateAcknowledgement() async throws {
        let secrets = Secrets(); let settings = Settings(); settings.biometryEnabled = false
        let biometry = Biometry(); biometry.availableBiometryType = .faceId; let output = Output()
        let interactor = PinSetupInteractor(secretManager: secrets, settingsManager: settings, biometryAuth: biometry, locale: Locale(identifier: "en"))
        interactor.presenter = output; interactor.process(pin: "123456")
        biometry.answer(0, true); try await settle()
        interactor.cancel(); secrets.answer(0, true); try await settle()
        // A submitted provider write cannot be cancelled. Only stale app publication is suppressed.
        XCTAssertEqual(secrets.savedPin, "123456")
        XCTAssertEqual(settings.biometryEnabled, false)
        XCTAssertEqual(output.saved, 0)
        XCTAssertNil(interactor.pincode)
    }

    func testChangeRetryAndOutputReplacementIgnoreEarlierAcknowledgements() async throws {
        let secrets = Secrets(); let interactor = PinChangeInteractor(secretManager: secrets)
        let output = Output(); let replacement = Output(); interactor.presenter = output
        interactor.process(pin: "123456"); secrets.answer(0, false); try await settle()
        interactor.process(pin: "654321"); secrets.answer(0, false); try await settle()
        XCTAssertEqual(output.saved, 0)
        interactor.presenter = replacement; secrets.answer(1, true); try await settle()
        XCTAssertEqual(output.saved + replacement.saved, 0)
    }

    func testCancellationWinsQueuedSuccessNavigation() async throws {
        let secrets = Secrets(); let interactor = PinChangeInteractor(secretManager: secrets)
        let wireframe = Wireframe(); let view = View()
        let presenter = PinSetupPresenter(interactor: interactor, wireframe: wireframe)
        interactor.presenter = presenter; presenter.didLoad(view: view)
        presenter.didSavePin(); presenter.cancel(); presenter.didSavePin()
        try await settle()
        XCTAssertEqual(wireframe.main, 0)
    }

    func testActualCreateAndChangeControlsShowFailureAndRetryInAllBundledLocales() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for language in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            for setup in [true, false] {
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
                window.overrideUserInterfaceStyle = .dark
                if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
                defer { window.isHidden = true; window.rootViewController = nil }
                let secrets = Secrets(); if setup { secrets.savedPin = nil }
                let wireframe = Wireframe()
                let interactor: PinSetupInteractorInputProtocol
                let presenter: PinSetupPresenter
                if setup {
                    let actual = PinSetupInteractor(secretManager: secrets, settingsManager: Settings(), biometryAuth: Biometry(), locale: Locale(identifier: language))
                    interactor = actual; presenter = PinSetupPresenter(interactor: actual, wireframe: wireframe); actual.presenter = presenter
                } else {
                    let actual = PinChangeInteractor(secretManager: secrets)
                    interactor = actual; presenter = PinSetupPresenter(interactor: actual, wireframe: wireframe); actual.presenter = presenter
                }
                let controller = try show(presenter, language: language, setup: setup, in: window)
                try tapDigits("123456123456", controller: controller, window: window)
                XCTAssertEqual(secrets.saves.count, 1)
                XCTAssertFalse(controller.view.isUserInteractionEnabled)
                secrets.answer(0, false); try await settle()
                // LoadableViewProtocol fades its overlay for350ms after enabling interaction.
                try await Task.sleep(nanoseconds: 450_000_000)
                XCTAssertFalse(controller.view.subviews.contains { $0 is LoadingView })
                XCTAssertEqual(wireframe.main, 0)
                XCTAssertEqual(secrets.savedPin, setup ? nil : "111111")
                XCTAssertTrue(controller.view.isUserInteractionEnabled)
                let label = try XCTUnwrap(descendants(controller.view).first { $0.accessibilityIdentifier == "PinSaveFailure" } as? UILabel)
                XCTAssertFalse(label.isHidden)
                XCTAssertEqual(label.numberOfLines, 0)
                XCTAssertFalse(label.text?.contains("pincode.save.failed") ?? true)
                let scroll = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIScrollView }.first)
                scroll.scrollRectToVisible(label.convert(label.bounds, to: scroll), animated: false)
                window.layoutIfNeeded()
                XCTAssertLessThanOrEqual(label.intrinsicContentSize.height, label.bounds.height + 1)
                capture(window, name: "pin-save-failure-" + language + (setup ? "-setup" : "-change") + "-AX5")
                scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height)), animated: false)
                window.layoutIfNeeded()
                capture(window, name: "pin-save-failure-controls-" + language + (setup ? "-setup" : "-change") + "-AX5")
                try tapDigits("654321654321", controller: controller, window: window)
                XCTAssertEqual(secrets.saves.count, 2)
                secrets.answer(1, true); try await settle()
                try await Task.sleep(nanoseconds: 450_000_000)
                XCTAssertFalse(controller.view.subviews.contains { $0 is LoadingView })
                XCTAssertEqual(secrets.savedPin, "654321")
                XCTAssertEqual(wireframe.main, 1)
                XCTAssertTrue(controller.view.isUserInteractionEnabled)
                capture(window, name: "pin-save-retry-" + language + (setup ? "-setup" : "-change") + "-AX5")
                withExtendedLifetime(interactor) {}
            }
        }
    }

    private func show(_ presenter: PinSetupPresenterProtocol, language: String, setup: Bool, in window: UIWindow) throws -> PinSetupViewController {
        let controller = PinSetupViewController(nib: R.nib.pinSetupViewController)
        controller.presenter = presenter; controller.mode = .create
        controller.localizableTopTitle = LocalizableResource { locale in
            setup ? R.string.localizable.pincodeSetupTopTitle(preferredLanguages: locale.rLanguages) : R.string.localizable.profilePincodeChangeTitle(preferredLanguages: locale.rLanguages)
        }
        controller.localizationManager = try XCTUnwrap(LocalizationManager(localization: language))
        window.traitCollection.performAsCurrent {
            window.rootViewController = controller; controller.loadViewIfNeeded(); window.makeKeyAndVisible(); window.layoutIfNeeded()
        }
        return controller
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }
    private func tapDigits(_ pin: String, controller: PinSetupViewController, window: UIWindow) throws {
        let pinView = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? PinView }.first)
        for digit in pin {
            let control = try XCTUnwrap(pinView.numpadView?.subviews.compactMap { $0 as? RoundedButton }.first { $0.imageWithTitleView?.title == String(digit) })
            let scroll = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIScrollView }.first)
            scroll.scrollRectToVisible(control.convert(control.bounds, to: scroll), animated: false); window.layoutIfNeeded()
            let rect = control.convert(control.bounds, to: window)
            let hit = try XCTUnwrap(window.hitTest(CGPoint(x: rect.midX, y: rect.midY), with: nil))
            XCTAssertTrue(hit === control || hit.isDescendant(of: control))
            control.sendActions(for: .touchUpInside); window.layoutIfNeeded()
        }
    }
    private func capture(_ window: UIWindow, name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)) }
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testSeparatePinScreensSerializeIssuedWritesAndSkipCancelledQueuedWrites() async throws {
        let secrets = Secrets()
        let first = PinChangeInteractor(secretManager: secrets); let firstOutput = Output(); first.presenter = firstOutput
        let second = PinChangeInteractor(secretManager: secrets); let secondOutput = Output(); second.presenter = secondOutput
        let third = PinSetupInteractor(secretManager: secrets, settingsManager: Settings(), biometryAuth: Biometry(), locale: Locale(identifier: "en"))
        let thirdOutput = Output(); third.presenter = thirdOutput
        first.process(pin: "123456")
        second.process(pin: "654321")
        third.process(pin: "999999")
        XCTAssertEqual(secrets.saves.count, 1)
        first.cancel(); third.cancel()
        secrets.answer(0, true); try await settle()
        XCTAssertEqual(secrets.savedPin, "123456") // Issued persistence is real even after cancellation.
        XCTAssertEqual(firstOutput.saved, 0)
        XCTAssertEqual(secrets.saves.count, 2)
        XCTAssertEqual(secrets.saves[1].0, "654321")
        secrets.answer(1, true); try await settle()
        XCTAssertEqual(secrets.savedPin, "654321")
        XCTAssertEqual(secondOutput.saved, 1)
        XCTAssertEqual(thirdOutput.saved, 0)
        XCTAssertEqual(secrets.saves.count, 2)
    }

    func testActualNavigationPopFencesPendingPinChangeCompletion() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene); window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        defer { window.isHidden = true; window.rootViewController = nil }
        let secrets = Secrets(); let interactor = PinChangeInteractor(secretManager: secrets); let wireframe = Wireframe()
        let presenter = PinSetupPresenter(interactor: interactor, wireframe: wireframe); interactor.presenter = presenter
        let controller = PinSetupViewController(nib: R.nib.pinSetupViewController)
        controller.presenter = presenter; controller.mode = .create
        controller.localizationManager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let root = UIViewController(); let navigation = UINavigationController(rootViewController: root)
        window.rootViewController = navigation; window.makeKeyAndVisible(); window.layoutIfNeeded()
        navigation.pushViewController(controller, animated: false); window.layoutIfNeeded()
        try tapDigits("123456123456", controller: controller, window: window)
        XCTAssertEqual(secrets.saves.count, 1)
        navigation.popViewController(animated: false)
        secrets.answer(0, true); try await settle()
        XCTAssertTrue(navigation.topViewController === root)
        XCTAssertEqual(wireframe.main, 0)
        XCTAssertEqual(secrets.savedPin, "123456")
        presenter.submit(pin: "654321")
        XCTAssertEqual(secrets.saves.count, 1)
    }

    func testAcknowledgedChangedPinAuthenticatesAndOldPinDoesNot() async throws {
        let secrets = Secrets(); let interactor = PinChangeInteractor(secretManager: secrets); let output = Output()
        interactor.presenter = output; interactor.process(pin: "123456"); secrets.answer(0, true); try await settle()
        let auth = LocalAuthInteractor(secretManager: secrets, settingsManager: Settings(), biometryAuth: Biometry(), locale: Locale(identifier: "en"))
        final class AuthOutput: LocalAuthInteractorOutputProtocol {
            var complete = 0; var wrong = 0
            func didCompleteAuth() { complete += 1 }
            func didEnterWrongPincode() { wrong += 1 }
            func didChangeState(to _: LocalAuthInteractor.LocalAuthState) {}
            func didUnexpectedFail() { XCTFail("Unexpected authentication failure") }
        }
        let result = AuthOutput(); auth.startAuth(with: result); auth.process(pin: "111111"); try await settle()
        XCTAssertEqual(result.wrong, 1); XCTAssertEqual(result.complete, 0)
        auth.process(pin: "123456"); try await settle()
        XCTAssertEqual(result.complete, 1)
    }
}

@MainActor
final class ProfileAuthorizationLifecycleTests: XCTestCase {
    private final class Secrets: SecretStoreManagerProtocol {
        var loads: [(DispatchQueue, (SecretDataRepresentable?) -> Void)] = []
        func loadSecret(for _: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void) {
            loads.append((completionQueue, completionBlock))
        }
        func answer(_ index: Int, _ pin: String?) {
            let (queue, completion) = loads[index]
            queue.async { completion(pin) }
        }
        func saveSecret(_: SecretDataRepresentable, for _: String, completionQueue _: DispatchQueue, completionBlock _: @escaping (Bool) -> Void) { XCTFail("Authentication must not save a secret") }
        func removeSecret(for _: String, completionQueue _: DispatchQueue, completionBlock _: @escaping (Bool) -> Void) { XCTFail("Authentication must not remove a secret") }
        func checkSecret(for _: String, completionQueue _: DispatchQueue, completionBlock: @escaping (Bool) -> Void) { completionBlock(true) }
        func checkSecret(for _: String) -> Bool { true }
    }

    private final class Settings: SettingsManagerProtocol {
        private var values: [String: Any] = [:]
        func set(value: Bool, for key: String) { values[key] = value }
        func set(value: Int, for key: String) { values[key] = value }
        func set(value: Double, for key: String) { values[key] = value }
        func set(value: String, for key: String) { values[key] = value }
        func set(value: Data, for key: String) { values[key] = value }
        func set(anyValue: Any, for key: String) { values[key] = anyValue }
        func bool(for key: String) -> Bool? { values[key] as? Bool }
        func integer(for key: String) -> Int? { values[key] as? Int }
        func double(for key: String) -> Double? { values[key] as? Double }
        func string(for key: String) -> String? { values[key] as? String }
        func data(for key: String) -> Data? { values[key] as? Data }
        func anyValue(for key: String) -> Any? { values[key] }
        func removeValue(for key: String) { values.removeValue(forKey: key) }
        func removeAll() { values.removeAll() }
    }

    private final class Biometry: BiometryAuthProtocol {
        var availableBiometryType = AvailableBiometryType.faceId
        var replies: [(DispatchQueue, (Bool) -> Void)] = []
        var cancellations = 0
        func cancelAuthentication() { cancellations += 1 }
        func authenticate(localizedReason _: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
            replies.append((completionQueue, completionBlock))
        }
        func answer(_ index: Int, _ result: Bool) {
            let (queue, completion) = replies[index]
            queue.async { completion(result) }
        }
    }


    private final class ProfileData: ProfileInteractorInputProtocol {
        func setup(with _: ProfileInteractorOutputProtocol) {}
        func updateWallet(_: MetaAccountModel) {}
        func logout(completion: @escaping () -> Void) { XCTFail("Fixture must not log out"); completion() }
        func update(currency _: Currency) {}
    }

    private final class ViewModels: ProfileViewModelFactoryProtocol {
        let model = ProfileViewModel(
            profileUserViewModel: WalletsManagmentCellViewModel(isSelected: true, walletName: "Public fixture", fiatBalance: nil, dayChange: nil, accountScoreViewModel: nil),
            profileOptionViewModel: [ProfileOptionViewModel(title: "Change PIN", icon: nil, accessoryTitle: nil, accessoryImage: nil, accessoryType: .arrow, option: .changePincode)],
            logoutViewModel: ProfileOptionViewModel(title: "Logout", icon: nil, accessoryTitle: nil, accessoryImage: nil, accessoryType: .arrow, option: nil)
        )
        func createProfileViewModel(from _: MetaAccountModel, locale _: Locale, language _: Language, currency _: Currency, balance _: WalletBalanceInfo?, missingAccountIssue _: [ChainIssue]) -> ProfileViewModelProtocol { model }
    }

    private final class Attempt {
        let secrets = Secrets()
        let biometry = Biometry()
        var controller: PinSetupViewController!
    }

    private final class Factory {
        var attempts: [Attempt] = []
        let settings = Settings()
        let localization: LocalizationManager
        init(biometric: Bool, language: String) throws {
            localization = try XCTUnwrap(LocalizationManager(localization: language))
            settings.biometryEnabled = biometric
        }
        func make(wireframe: ScreenAuthorizationWireframeProtocol, cancellable: Bool) -> PinSetupViewProtocol? {
            let attempt = Attempt()
            let interactor = LocalAuthInteractor(secretManager: attempt.secrets, settingsManager: settings, biometryAuth: attempt.biometry, locale: localization.selectedLocale)
            let result = PinViewFactory.createScreenAuthorizationView(with: wireframe, cancellable: cancellable, interactor: interactor, localizationManager: localization)
            attempt.controller = result as? PinSetupViewController
            attempts.append(attempt)
            return result
        }
    }

    private final class SceneNavigation: UINavigationController {
        var hasAppeared = false
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hasAppeared = true
        }
    }

    private struct Fixture {
        let factory: Factory
        let profile: ProfileViewController
        let navigation: SceneNavigation
        let window: UIWindow
    }

    private func show(biometric: Bool = false, language: String = "en", enlarged: Bool = false) async throws -> Fixture {
        let factory = try Factory(biometric: biometric, language: language)
        let wireframe = ProfileWireframe(authorizationViewFactory: factory.make)
        let models = ViewModels()
        let presenter = ProfilePresenter(viewModelFactory: models, interactor: ProfileData(), wireframe: wireframe, logger: Logger.shared, settings: factory.settings, eventCenter: EventCenter(), localizationManager: factory.localization)
        let profile = ProfileViewController(presenter: presenter, iconGenerating: UniversalIconGenerator(), localizationManager: factory.localization)
        let navigation = SceneNavigation(rootViewController: profile)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: enlarged ? 320 : 390, height: enlarged ? 568 : 844)
        if #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = enlarged ? .accessibilityExtraExtraExtraLarge : .large
        }
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        profile.loadViewIfNeeded()
        profile.didReceive(state: .loaded(models.model))
        window.layoutIfNeeded()
        try await waitUntil("Actual Profile root appearance must finish before presenting") { navigation.hasAppeared }
        return Fixture(factory: factory, profile: profile, navigation: navigation, window: window)
    }

    private func waitUntil(_ description: String, _ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail(description)
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }

    private func open(_ fixture: Fixture, settled: Bool = true) async throws -> Attempt {
        let table = fixture.profile.rootView.tableView
        var selected: IndexPath?
        for section in 0..<table.numberOfSections {
            for row in 0..<table.numberOfRows(inSection: section) {
                let index = IndexPath(row: row, section: section)
                let cell = fixture.profile.tableView(table, cellForRowAt: index)
                if descendants(cell).compactMap({ ($0 as? UILabel)?.text }).contains("Change PIN") { selected = index }
            }
        }
        let index = try XCTUnwrap(selected)
        table.scrollToRow(at: index, at: .middle, animated: false)
        fixture.window.layoutIfNeeded()
        let cell = try XCTUnwrap(table.cellForRow(at: index))
        let rect = cell.convert(cell.bounds, to: fixture.window)
        let hit = try XCTUnwrap(fixture.window.hitTest(CGPoint(x: rect.midX, y: rect.midY), with: nil))
        XCTAssertTrue(hit === cell || hit.isDescendant(of: cell))
        // Deliver the table's public selection callback after validating the real cell's hit ownership.
        fixture.profile.tableView(table, didSelectRowAt: index)
        let attempt = try XCTUnwrap(fixture.factory.attempts.last)
        if settled {
            try await waitUntil("Authorization must settle in the real scene") { attempt.controller.view.window != nil && attempt.controller.transitionCoordinator == nil }
            capture(fixture, name: "authorization-attempt-\(fixture.factory.attempts.count)")
        }
        return attempt
    }

    private func capture(_ fixture: Fixture, name: String) {
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: fixture.window.bounds).image { _ in
            XCTAssertTrue(fixture.window.drawHierarchy(in: fixture.window.bounds, afterScreenUpdates: true))
        })
        attachment.name = "profile-auth-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func enter(_ digits: String, attempt: Attempt, fixture: Fixture) throws {
        let controls = descendants(attempt.controller.view).compactMap { $0 as? RoundedButton }
        let scroll = try XCTUnwrap(descendants(attempt.controller.view).compactMap { $0 as? UIScrollView }.first)
        for digit in digits {
            let key = try XCTUnwrap(controls.first { $0.imageWithTitleView?.title == String(digit) })
            scroll.scrollRectToVisible(key.convert(key.bounds, to: scroll), animated: false)
            fixture.window.layoutIfNeeded()
            let rect = key.convert(key.bounds, to: fixture.window)
            let hit = try XCTUnwrap(fixture.window.hitTest(CGPoint(x: rect.midX, y: rect.midY), with: nil))
            XCTAssertTrue(hit === key || hit.isDescendant(of: key))
            key.sendActions(for: .touchUpInside)
        }
    }

    private func close(_ fixture: Fixture) async throws {
        fixture.navigation.dismiss(animated: false)
        try await waitUntil("Fixture modal teardown") { fixture.navigation.presentedViewController == nil && fixture.navigation.transitionCoordinator == nil }
        fixture.window.isHidden = true
        fixture.window.rootViewController = nil
        fixture.factory.attempts.removeAll()
    }

    func testActualProfileExternalDismissalReleasesAuthorizationForNextTap() async throws {
        let fixture = try await show()
        let first = try await open(fixture)
        try enter("123456", attempt: first, fixture: fixture)
        XCTAssertEqual(first.secrets.loads.count, 1)
        fixture.navigation.dismiss(animated: false)
        try await waitUntil("External dismissal must finish") { first.controller.presentingViewController == nil }
        let next = try await open(fixture)
        XCTAssertEqual(fixture.factory.attempts.count, 2, "A dismissed authorization cannot strand Profile's next Change PIN action")
        XCTAssertFalse(next === first)
        first.secrets.answer(0, "123456")
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(fixture.navigation.topViewController === fixture.profile)
        try await close(fixture)
    }

    func testActualProfileBackgroundRejectsHeldCorrectPin() async throws {
        let fixture = try await show()
        let attempt = try await open(fixture)
        try enter("123456", attempt: attempt, fixture: fixture)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared)
        attempt.secrets.answer(0, "123456")
        try await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertTrue(fixture.navigation.topViewController === fixture.profile, "A request retired by background must not open PIN change")
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: UIApplication.shared)
        try await close(fixture)
    }

    func testActualProfileBackgroundRejectsHeldSuccessfulBiometry() async throws {
        let fixture = try await show(biometric: true)
        let attempt = try await open(fixture)
        XCTAssertEqual(attempt.biometry.replies.count, 1)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared)
        attempt.biometry.answer(0, true)
        try await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertTrue(fixture.navigation.topViewController === fixture.profile, "Background must retire the owned biometric request")
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: UIApplication.shared)
        try await close(fixture)
    }

    func testActualProfileForegroundStartsFreshAuthorizationAfterBackground() async throws {
        let fixture = try await show()
        let first = try await open(fixture)
        try enter("123456", attempt: first, fixture: fixture)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared)
        try await waitUntil("Background must dismiss the retired authorization") { fixture.navigation.presentedViewController == nil && fixture.navigation.transitionCoordinator == nil }
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: UIApplication.shared)
        let next = try await open(fixture)
        XCTAssertEqual(fixture.factory.attempts.count, 2)
        first.secrets.answer(0, "123456")
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertTrue(fixture.navigation.topViewController === fixture.profile)
        try enter("123456", attempt: next, fixture: fixture)
        next.secrets.answer(0, "123456")
        try await waitUntil("Fresh foreground authorization remains usable") { (fixture.navigation.topViewController as? PinSetupViewController)?.mode == .create && fixture.navigation.transitionCoordinator == nil }
        capture(fixture, name: "foreground-fresh-pin-change")
        try await close(fixture)
    }

    private func tapCancel(_ attempt: Attempt, fixture: Fixture) throws {
        let cancel = try XCTUnwrap(descendants(attempt.controller.view).compactMap { $0 as? UIButton }.first { $0.currentTitle == R.string.localizable.commonCancel(preferredLanguages: fixture.factory.localization.selectedLocale.rLanguages) })
        let scroll = try XCTUnwrap(descendants(attempt.controller.view).compactMap { $0 as? UIScrollView }.first)
        scroll.scrollRectToVisible(cancel.convert(cancel.bounds, to: scroll), animated: false)
        fixture.window.layoutIfNeeded()
        let rect = cancel.convert(cancel.bounds, to: fixture.window)
        let hit = try XCTUnwrap(fixture.window.hitTest(CGPoint(x: rect.midX, y: rect.midY), with: nil))
        XCTAssertTrue(hit === cancel || hit.isDescendant(of: cancel))
        capture(fixture, name: "cancel-visible-" + fixture.factory.localization.selectedLocale.identifier)
        cancel.sendActions(for: .touchUpInside)
    }

    func testActualProfileLocalizedEnlargedCancelAndReentry() async throws {
        for language in ["ru", "zh-Hans"] {
            let fixture = try await show(language: language, enlarged: true)
            let first = try await open(fixture)
            try enter("123456", attempt: first, fixture: fixture)
            try tapCancel(first, fixture: fixture)
            try await waitUntil("Localized Cancel completes dismissal") { fixture.navigation.presentedViewController == nil && fixture.navigation.transitionCoordinator == nil }
            let next = try await open(fixture)
            XCTAssertEqual(fixture.factory.attempts.count, 2)
            first.secrets.answer(0, "123456")
            try await Task.sleep(nanoseconds: 150_000_000)
            XCTAssertTrue(fixture.navigation.topViewController === fixture.profile)
            try tapCancel(next, fixture: fixture)
            try await waitUntil("Fresh localized authorization remains cancellable") { fixture.navigation.presentedViewController == nil && fixture.navigation.transitionCoordinator == nil }
            try await close(fixture)
        }
    }

    func testActualProfileCancelButtonRetiresBiometryAndAllowsFreshSuccess() async throws {
        let fixture = try await show(biometric: true)
        let first = try await open(fixture)
        let cancellationsBefore = first.biometry.cancellations
        try tapCancel(first, fixture: fixture)
        XCTAssertGreaterThan(first.biometry.cancellations, cancellationsBefore)
        try await waitUntil("Actual Cancel dismisses authorization") { fixture.navigation.presentedViewController == nil && fixture.navigation.transitionCoordinator == nil }
        let next = try await open(fixture)
        first.biometry.answer(0, true)
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertTrue(fixture.navigation.topViewController === fixture.profile)
        next.biometry.answer(0, true)
        try await waitUntil("Fresh biometric success opens PIN change") { (fixture.navigation.topViewController as? PinSetupViewController)?.mode == .create && fixture.navigation.transitionCoordinator == nil }
        capture(fixture, name: "cancel-then-fresh-biometry")
        try await close(fixture)
    }

    func testActualProfileBackgroundDuringPresentationRetiresAttempt() async throws {
        let fixture = try await show(biometric: true)
        let attempt = try await open(fixture, settled: false)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared)
        if !attempt.biometry.replies.isEmpty { attempt.biometry.answer(0, true) }
        try await waitUntil("Background during presentation must release the modal") { fixture.navigation.presentedViewController == nil && fixture.navigation.transitionCoordinator == nil }
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: UIApplication.shared)
        let next = try await open(fixture)
        XCTAssertEqual(fixture.factory.attempts.count, 2)
        XCTAssertFalse(next === attempt)
        XCTAssertTrue(fixture.navigation.topViewController === fixture.profile)
        try await close(fixture)
    }

    func testActualProfileExternalAnimatedDismissalRejectsReplyDuringTransition() async throws {
        let fixture = try await show()
        let attempt = try await open(fixture)
        try enter("123456", attempt: attempt, fixture: fixture)
        fixture.navigation.dismiss(animated: true)
        attempt.secrets.answer(0, "123456")
        try await waitUntil("External animated dismissal finishes") { fixture.navigation.presentedViewController == nil && fixture.navigation.transitionCoordinator == nil }
        XCTAssertTrue(fixture.navigation.topViewController === fixture.profile)
        _ = try await open(fixture)
        XCTAssertEqual(fixture.factory.attempts.count, 2)
        try await close(fixture)
    }

    func testActualProfileCorrectPinOpensChangeAfterAuthorizationDismissal() async throws {
        let fixture = try await show()
        let attempt = try await open(fixture)
        try enter("123456", attempt: attempt, fixture: fixture)
        attempt.secrets.answer(0, "123456")
        try await waitUntil("Current successful authorization opens PIN change") { (fixture.navigation.topViewController as? PinSetupViewController)?.mode == .create && fixture.navigation.transitionCoordinator == nil }
        XCTAssertNil(fixture.navigation.presentedViewController)
        capture(fixture, name: "acknowledged-pin-change")
        try await close(fixture)
    }
}

@MainActor
final class BiometryContextOwnershipTests: XCTestCase {
    private final class Context: LAContext {
        var replies: [@Sendable (Bool, Error?) -> Void] = []
        var invalidations = 0
        var available = true
        override var biometryType: LABiometryType { .faceID }
        override func canEvaluatePolicy(_: LAPolicy, error _: NSErrorPointer) -> Bool { available }
        override func evaluatePolicy(_: LAPolicy, localizedReason _: String, reply: @escaping @Sendable (Bool, Error?) -> Void) { replies.append(reply) }
        override func invalidate() { invalidations += 1 }
    }

    func testUnavailableContextReturnsFalseWithoutEvaluatingAndCancellationCanRetireIt() async throws {
        for cancelled in [false, true] {
            let context = Context()
            context.available = false
            let provider = BiometryAuth(contextFactory: { context })
            XCTAssertEqual(provider.availableBiometryType, .none)
            var results: [Bool] = []
            provider.authenticate(localizedReason: "Public fixture", completionQueue: .main) { results.append($0) }
            if cancelled { provider.cancelAuthentication() }
            try await Task.sleep(nanoseconds: 100_000_000)
            XCTAssertTrue(context.replies.isEmpty)
            XCTAssertEqual(results, cancelled ? [] : [false])
            XCTAssertEqual(context.invalidations, 1)
        }
    }

    func testProviderReleaseInvalidatesHeldContextAndCannotDeliverItsReply() async throws {
        let context = Context()
        var provider: BiometryAuth? = BiometryAuth(contextFactory: { context })
        var results: [Bool] = []
        provider?.authenticate(localizedReason: "Public fixture", completionQueue: .main) { results.append($0) }
        weak var retired = provider
        provider = nil
        XCTAssertNil(retired)
        XCTAssertEqual(context.invalidations, 1)
        context.replies.first?(true, nil)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(results.isEmpty)
    }

    func testFailedContextCanRetryWithFreshSuccessfulEvaluation() async throws {
        let first = Context()
        let second = Context()
        var created = 0
        let provider = BiometryAuth(contextFactory: { defer { created += 1 }; return created == 0 ? first : second })
        var results: [Bool] = []
        provider.authenticate(localizedReason: "Public fixture", completionQueue: .main) { results.append($0) }
        first.replies.first?(false, nil)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(results, [false])
        XCTAssertEqual(first.invalidations, 1)
        provider.authenticate(localizedReason: "Retry", completionQueue: .main) { results.append($0) }
        first.replies.first?(true, nil)
        second.replies.first?(true, nil)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(results, [false, true])
        XCTAssertEqual(created, 2)
        XCTAssertEqual(second.invalidations, 1)
    }

    func testCancellationInvalidatesActualContextAndFencesLateOrQueuedReply() async throws {
        for queuedBeforeCancel in [false, true] {
            let context = Context()
            let provider = BiometryAuth(contextFactory: { context })
            var results: [Bool] = []
            provider.authenticate(localizedReason: "Public fixture", completionQueue: .main) { results.append($0) }
            XCTAssertEqual(context.replies.count, 1)
            if queuedBeforeCancel { context.replies[0](true, nil) }
            provider.cancelAuthentication()
            if !queuedBeforeCancel { context.replies[0](true, nil) }
            try await Task.sleep(nanoseconds: 100_000_000)
            XCTAssertEqual(context.invalidations, 1, "Cancel must invalidate the owned LAContext")
            XCTAssertTrue(results.isEmpty, "Cancellation must retire late and already queued context replies")
        }
    }

    func testReplacementGetsFreshContextAndOldReplyCannotRetireCurrentOne() async throws {
        let first = Context()
        let second = Context()
        var created = 0
        let provider = BiometryAuth(contextFactory: {
            defer { created += 1 }
            return created == 0 ? first : second
        })
        var firstResults: [Bool] = []
        var secondResults: [Bool] = []
        provider.authenticate(localizedReason: "First public fixture", completionQueue: .main) { firstResults.append($0) }
        provider.authenticate(localizedReason: "Second public fixture", completionQueue: .main) { secondResults.append($0) }
        XCTAssertEqual(created, 2, "Every evaluation must own a fresh context")
        XCTAssertEqual(first.invalidations, 1)
        XCTAssertEqual(second.invalidations, 0)
        first.replies.first?(true, nil)
        second.replies.first?(true, nil)
        second.replies.first?(false, nil)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(firstResults.isEmpty)
        XCTAssertEqual(secondResults, [true], "The current context succeeds once, regardless of old or duplicate replies")
    }
}
