@testable import fearless
import SoraFoundation
import SoraKeystore
import SoraUI
import struct SSFModels.Currency
import SSFUtils
import UIKit
import LocalAuthentication
import XCTest

/// Biometric enrollment as the PIN holder last vouched for it, without LAContext or the device Keychain.
private final class EnrollmentStub: BiometryEnrollmentGuarding {
    var trusted = true
    private(set) var trustCalls = 0
    func isCurrentEnrollmentTrusted() -> Bool { trusted }
    func trustCurrentEnrollment() {
        trustCalls += 1
        trusted = true
    }
}

/// Wall and monotonic clocks that move only when a test moves them.
private final class LockoutClocks {
    var now: TimeInterval = 1_800_000_000
    var uptime: TimeInterval = 10000
    func advance(_ seconds: TimeInterval) {
        now += seconds
        uptime += seconds
    }

    func limiter(_ keystore: KeystoreProtocol) -> PincodeAttemptLimiter {
        PincodeAttemptLimiter(keystore: keystore, now: { self.now }, uptime: { self.uptime })
    }
}

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

    func testLockupHeadsThePinPageAtNormalAndMaximumType() async throws {
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            for mode in [PinView.Mode.create, .securedInput] {
                let fixture = try show(language: "en", category: category, mode: mode, cancellable: false, heading: "setup")
                defer { fixture.close() }
                await Task.yield()
                fixture.window.layoutIfNeeded()
                let lockup = try XCTUnwrap(descendants(fixture.controller.view).compactMap { $0 as? FWLockupView }.first)
                let share = lockup.bounds.width / fixture.window.bounds.width
                XCTAssertGreaterThanOrEqual(share, 0.4)
                XCTAssertLessThanOrEqual(share, FWLockupView.widthFraction + 0.01)
                XCTAssertLessThanOrEqual(
                    lockup.bounds.height, fixture.window.bounds.height * FWPinScreenSunlit.lockupHeightFraction + 1
                )
                XCTAssertEqual(lockup.bounds.width / lockup.bounds.height, FWLockupView.aspectRatio, accuracy: 0.03)
                let glow = lockup.convert(lockup.glowFrame, to: fixture.scroll)
                XCTAssertGreaterThanOrEqual(glow.minY, fixture.scroll.contentOffset.y, "The scroll view must not cut the light")
                let labels = try XCTUnwrap(fixture.controller.topLabel.superview).subviews.compactMap { $0 as? UILabel }
                    .filter { !$0.isHidden }
                for label in labels {
                    let top = label.convert(label.bounds, to: fixture.scroll).minY
                    XCTAssertLessThanOrEqual(lockup.convert(lockup.bounds, to: fixture.scroll).maxY, top, "The lockup stays above the text")
                }
            }
        }
    }

    func testNormalSizePinUsesLargeKeysAndCentersContentAcrossWindowSizes() async throws {
        let sizes = [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852),
                     CGSize(width: 852, height: 393), CGSize(width: 834, height: 1194)]
        for size in sizes {
            for mode in [PinView.Mode.create, .securedInput] {
                let fixture = try show(
                    language: "en", category: .large, mode: mode, cancellable: false,
                    heading: mode == .create ? "setup" : "empty", size: size,
                    idiom: size.width == 834 ? .pad : .phone
                )
                defer { fixture.close() }
                await Task.yield()
                fixture.window.layoutIfNeeded()
                try assertLayout(fixture)
                let numpad = try XCTUnwrap(fixture.pin.numpadView)
                XCTAssertEqual(numpad.intrinsicContentSize.width, 260, accuracy: 1)
                XCTAssertEqual(fixture.pin.verticalSpacing, 48)
                for key in controls(fixture) {
                    XCTAssertEqual(key.bounds.width, 72, accuracy: 1)
                    XCTAssertEqual(key.bounds.height, 72, accuracy: 1)
                }
                let content = try XCTUnwrap(fixture.controller.topLabel.superview)
                let rect = content.convert(content.bounds, to: fixture.scroll)
                XCTAssertEqual(rect.midY, fixture.scroll.contentSize.height / 2, accuracy: 1)
                XCTAssertGreaterThanOrEqual(rect.minY, 15)
                if size.height > 800 {
                    XCTAssertEqual(fixture.scroll.contentSize.height, fixture.scroll.bounds.height, accuracy: 1)
                }
                capture(fixture, name: "sizing-\(Int(size.width))x\(Int(size.height))-mode\(mode.rawValue)")
                try assertControlsReachable(fixture)
            }
        }
    }

    func testPinResizesWithoutLosingInputOrChangingNormalSpacing() async throws {
        let fixture = try show(
            language: "en",
            category: .large,
            cancellable: false,
            size: CGSize(width: 393, height: 852)
        )
        defer { fixture.close() }
        await Task.yield()
        try enter("12", in: fixture)
        let originalSpacing = fixture.pin.verticalSpacing
        if #available(iOS 17.0, *) {
            fixture.window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        }
        for size in [CGSize(width: 320, height: 568), CGSize(width: 852, height: 393)] {
            fixture.window.frame.size = size
            for _ in 0 ..< 3 { await Task.yield() }
            fixture.window.layoutIfNeeded()
            try assertLayout(fixture)
            try assertControlsReachable(fixture)
        }
        if #available(iOS 17.0, *) { fixture.window.traitOverrides.preferredContentSizeCategory = .large }
        fixture.window.frame.size = CGSize(width: 393, height: 852)
        for _ in 0 ..< 3 { await Task.yield() }
        fixture.window.layoutIfNeeded()
        XCTAssertEqual(fixture.pin.numpadView?.keyRadius, 36)
        XCTAssertEqual(fixture.pin.verticalSpacing, originalSpacing)
        XCTAssertEqual(originalSpacing, 48)
        try enter("3456123456", in: fixture)
        XCTAssertEqual(fixture.presenter.pins, ["123456"])
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

    func testLockoutTurnsDigitsOffShowsTimeLeftAndTurnsThemBackOn() async throws {
        let fixture = try show(language: "en", category: .large, mode: .securedInput, heading: "empty")
        defer { fixture.close() }
        await Task.yield()
        fixture.controller.didChangeAccessoryState(enabled: true, availableBiometryType: .faceId)
        fixture.controller.didReceiveLockout(remaining: 0.5)
        let digits = controls(fixture).filter { Int($0.imageWithTitleView?.title ?? "") != nil }
        XCTAssertEqual(digits.count, 10)
        XCTAssertTrue(digits.allSatisfy { !$0.isEnabled })
        let backspace = try XCTUnwrap(controls(fixture).first { $0.accessibilityIdentifier == "BackspaceAccessibilityId" })
        XCTAssertFalse(backspace.isEnabled)
        let biometry = try XCTUnwrap(controls(fixture).first {
            $0.accessibilityIdentifier == PinViewConfigurator.biometryKeyAccessibilityId
        })
        XCTAssertTrue(biometry.isEnabled, "A trusted face or finger stays available during a lockout")
        let message = R.string.localizable.pincodeLockoutMessage("0:01", preferredLanguages: ["en"])
        let labels = descendants(fixture.controller.view).compactMap { $0 as? UILabel }
        XCTAssertTrue(labels.contains { $0.text == message })
        capture(fixture, name: "en-lockout")
        for digit in "123456" {
            try XCTUnwrap(digits.first { $0.imageWithTitleView?.title == String(digit) }).sendActions(for: .touchUpInside)
        }
        XCTAssertTrue(fixture.presenter.pins.isEmpty, "Input that reaches the pad during a lockout is not submitted")

        try await Task.sleep(nanoseconds: 1_300_000_000)
        XCTAssertTrue(digits.allSatisfy(\.isEnabled))
        XCTAssertFalse(labels.contains { $0.text == message })
        try enter("123456", in: fixture)
        XCTAssertEqual(fixture.presenter.pins, ["123456"])
    }

    func testCheckPincodeScreenAlsoLocksAndCountsDown() async throws {
        let presenter = Presenter()
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = CheckPincodeViewController(presenter: presenter, localizationManager: localization)
        controller.loadViewIfNeeded()
        controller.didReceiveLockout(remaining: 61)
        XCTAssertEqual(
            controller.rootView.titleLabel.text,
            R.string.localizable.pincodeLockoutMessage("1:01", preferredLanguages: ["en"])
        )
        let keys = controller.rootView.pinView.numpadView?.subviews.compactMap { $0 as? RoundedButton } ?? []
        let digits = keys.filter { Int($0.imageWithTitleView?.title ?? "") != nil }
        XCTAssertEqual(digits.count, 10)
        XCTAssertTrue(digits.allSatisfy { !$0.isEnabled })
        for digit in "123456" {
            try XCTUnwrap(digits.first { $0.imageWithTitleView?.title == String(digit) }).sendActions(for: .touchUpInside)
        }
        XCTAssertTrue(presenter.pins.isEmpty)
    }

    func testLockoutTimeReadsInMinutesAndSecondsRoundedUp() {
        XCTAssertEqual(PinLockoutCountdown.format(0.2), "0:01")
        XCTAssertEqual(PinLockoutCountdown.format(59.01), "1:00")
        XCTAssertEqual(PinLockoutCountdown.format(298.3), "4:59")
        XCTAssertEqual(PinLockoutCountdown.format(3600), "60:00")
    }

    private func show(
        language: String, category: UIContentSizeCategory, mode: PinView.Mode = .create,
        cancellable: Bool = true, heading: String = "setup",
        size: CGSize = CGSize(width: 320, height: 568), idiom: UIUserInterfaceIdiom = .phone
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
        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = category
            window.traitOverrides.userInterfaceIdiom = idiom
            window.traitOverrides.horizontalSizeClass = idiom == .pad ? .regular : .compact
        }
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
            for label in descendants(control).compactMap({ $0 as? UILabel }) {
                let rect = label.convert(label.bounds, to: control)
                XCTAssertTrue(
                    control.bounds.insetBy(dx: -1, dy: -1).contains(rect),
                    "The full digit must fit inside its key at every text size: \(rect)"
                )
            }
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
        var lockouts: [TimeInterval] = []
        var dismissalBegan = false
        func didReceiveLockout(remaining: TimeInterval) { lockouts.append(remaining) }
        override var isBeingDismissed: Bool { dismissalBegan || super.isBeingDismissed }
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
        var lockouts: [TimeInterval] = []
        var states: [LocalAuthInteractor.LocalAuthState] = []
        func didEnterWrongPincode() { wrongPins += 1 }
        func didReceiveLockout(remaining: TimeInterval) { XCTAssertTrue(Thread.isMainThread); lockouts.append(remaining) }
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
        let enrollment = EnrollmentStub()
        let clocks = LockoutClocks()
        let keystore = InMemoryKeychain()
        let limiter: PincodeAttemptLimiter
        let interactor: LocalAuthInteractor
        init(biometric: Bool = false) {
            settings.biometryEnabled = biometric
            limiter = clocks.limiter(keystore)
            interactor = LocalAuthInteractor(
                secretManager: secrets, settingsManager: settings, biometryAuth: biometry, locale: Locale(identifier: "en"),
                attemptLimiter: limiter, enrollmentGuard: enrollment
            )
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

    func testCorrectPinLandingAfterDismissalBeganCannotAuthorize() async throws {
        let f = Fixture()
        let wireframe = Wireframe()
        let presenter = ScreenAuthorizationPresenter(wireframe: wireframe, interactor: f.interactor)
        let view = View()
        presenter.didLoad(view: view)
        presenter.submit(pin: "123456")
        // UIKit has begun an external dismissal and has not called viewWillDisappear yet.
        view.dismissalBegan = true
        f.secrets.answer(0, "123456")
        try await settle()
        XCTAssertTrue(wireframe.results.isEmpty, "A correct PIN that lands while the screen is leaving cannot authorize")
        presenter.willLeaveView()
        presenter.didLeaveView()
        XCTAssertEqual(wireframe.results, [false])
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

    // MARK: - Wrong-PIN lockout and biometric enrollment

    private func enterWrongPins(_ count: Int, into f: Fixture) async throws {
        for _ in 0 ..< count {
            let index = f.secrets.loads.count
            f.interactor.process(pin: "000000")
            f.secrets.answer(index, "123456")
            try await settle()
        }
    }

    func testSixthWrongPinLocksAndLockedGuessesAreNeverCompared() async throws {
        let f = Fixture()
        let output = Output()
        f.interactor.startAuth(with: output)
        try await enterWrongPins(5, into: f)
        XCTAssertEqual(output.wrongPins, 5)
        XCTAssertTrue(output.lockouts.isEmpty, "Five attempts are free")
        try await enterWrongPins(1, into: f)
        XCTAssertEqual(output.lockouts, [60])

        f.interactor.process(pin: "123456")
        try await settle()
        XCTAssertEqual(f.secrets.loads.count, 6, "A guess during the lockout never reads the stored PIN")
        XCTAssertEqual(output.lockouts, [60, 60])
        XCTAssertEqual(output.completions, 0)

        f.clocks.advance(60)
        f.interactor.process(pin: "123456")
        f.secrets.answer(6, "123456")
        try await settle()
        XCTAssertEqual(output.completions, 1)
        XCTAssertEqual(f.limiter.registerFailure(), 0, "A correct PIN clears the count")
        XCTAssertTrue(try f.keystore.checkKey(for: fearless.KeystoreTag.pincodeAttempts.rawValue))
        XCTAssertFalse(try f.keystore.checkKey(for: fearless.KeystoreTag.pincode.rawValue), "The limiter never touches the PIN")
    }

    func testScreenOpenedDuringLockoutShowsItAndUnreadableStoredPinIsNotCounted() async throws {
        let f = Fixture()
        for _ in 0 ..< 7 { f.limiter.registerFailure() }
        f.clocks.advance(100)
        let output = Output()
        f.interactor.startAuth(with: output)
        try await settle()
        XCTAssertEqual(output.lockouts, [200])

        let fresh = Fixture()
        let freshOutput = Output()
        fresh.interactor.startAuth(with: freshOutput)
        for index in 0 ..< 8 {
            fresh.interactor.process(pin: "123456")
            fresh.secrets.answer(index, nil)
            try await settle()
        }
        XCTAssertEqual(freshOutput.wrongPins, 8)
        XCTAssertTrue(freshOutput.lockouts.isEmpty, "A Keychain read failure is not the user's guess")
    }

    func testChangedEnrollmentAsksForThePinOnceAndThenTrustsTheNewOne() async throws {
        let f = Fixture(biometric: true)
        f.enrollment.trusted = false
        let output = Output()
        f.interactor.startAuth(with: output)
        try await settle()
        XCTAssertTrue(f.biometry.replies.isEmpty, "No prompt for an enrollment the PIN holder has not vouched for")
        XCTAssertFalse(f.interactor.allowManualBiometryAuth)
        XCTAssertEqual(f.interactor.state, .waitingPincode)
        f.interactor.process(pin: "123456")
        f.secrets.answer(0, "123456")
        try await settle()
        XCTAssertEqual(output.completions, 1)
        XCTAssertEqual(f.enrollment.trustCalls, 1)
        XCTAssertTrue(f.interactor.allowManualBiometryAuth)
    }

    func testEnrollmentChangedDuringThePromptCannotAuthorize() async throws {
        let f = Fixture(biometric: true)
        let output = Output()
        f.interactor.startAuth(with: output)
        XCTAssertEqual(f.biometry.replies.count, 1)
        f.enrollment.trusted = false
        f.biometry.answer(0, true)
        try await settle()
        XCTAssertEqual(output.completions, 0)
        XCTAssertEqual(f.interactor.state, .waitingPincode)
    }

    func testReturningToAnAppAlreadyOnTheUnlockPinDoesNotStackAnotherOne() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.rootViewController = nil }
        let unlock = PinSetupViewController(nib: R.nib.pinSetupViewController)
        unlock.presenter = LocalAuthPresenter(wireframe: MainWireframe(), interactor: Fixture().interactor)
        window.rootViewController = unlock
        XCTAssertTrue(FearlessApplication.isShowingUnlockPin(in: window))
        let authorization = PinSetupViewController(nib: R.nib.pinSetupViewController)
        authorization.presenter = ScreenAuthorizationPresenter(wireframe: Wireframe(), interactor: Fixture().interactor)
        window.rootViewController = authorization
        XCTAssertFalse(FearlessApplication.isShowingUnlockPin(in: window), "A transfer authorization is not the app lock")
        window.rootViewController = UIViewController()
        XCTAssertFalse(FearlessApplication.isShowingUnlockPin(in: window))
    }

    func testAuthorizationScreenShowsTheLockoutAndCancelStillDeclines() async throws {
        let f = Fixture()
        let wireframe = Wireframe()
        let presenter = ScreenAuthorizationPresenter(wireframe: wireframe, interactor: f.interactor)
        let view = View()
        presenter.didLoad(view: view)
        for index in 0 ..< 6 {
            presenter.submit(pin: "000000")
            f.secrets.answer(index, "123456")
            try await settle()
        }
        XCTAssertEqual(view.wrongPins, 6)
        XCTAssertEqual(view.lockouts, [60])
        presenter.submit(pin: "123456")
        try await settle()
        XCTAssertEqual(f.secrets.loads.count, 6)
        XCTAssertEqual(view.lockouts, [60, 60])
        presenter.cancel()
        XCTAssertEqual(wireframe.results, [false], "Cancel during a lockout declines the submission")
    }

    func testTrustedBiometryStillWorksDuringLockoutAndLeavesTheCountInPlace() async throws {
        let f = Fixture(biometric: true)
        let output = Output()
        f.interactor.startAuth(with: output)
        f.biometry.answer(0, false)
        try await settle()
        try await enterWrongPins(6, into: f)
        XCTAssertEqual(output.lockouts, [60])
        f.interactor.startAuth(with: output)
        try await settle()
        XCTAssertEqual(output.lockouts, [60, 60], "Retrying biometrics keeps the countdown on screen")
        f.biometry.answer(1, true)
        try await settle()
        XCTAssertEqual(output.completions, 1)
        XCTAssertEqual(f.enrollment.trustCalls, 0, "Only a correct PIN vouches for an enrollment")
        f.clocks.advance(60)
        XCTAssertEqual(f.limiter.registerFailure(), 300, "A biometric success does not clear wrong PINs")
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
        var onSaveReply: ((String) -> Void)?
        func saveSecret(_ secret: SecretDataRepresentable, for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
            XCTAssertEqual(identifier, KeystoreTag.pincode.rawValue)
            let pin = secret.asSecretData().flatMap { String(data: $0, encoding: .utf8) } ?? ""
            saves.append((pin, completionQueue, completionBlock))
        }

        func answer(_ index: Int, _ success: Bool) {
            let (pin, queue, completion) = saves[index]
            if success { savedPin = pin }
            let record = onSaveReply
            queue.async {
                record?("save.reply.beforeCompletion")
                completion(success)
                record?("save.reply.afterCompletion")
            }
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
        var onShowMain: (() -> Void)?
        func showMain(from _: PinSetupViewProtocol?) { main += 1; onShowMain?() }
        func showSignup(from _: PinSetupViewProtocol?) {}
    }

    private final class LifecycleObservedPinController: PinSetupViewController {
        var hasAppeared = false
        var removalBegan = false
        var hasDisappeared = false
        var recordEvent: ((String) -> Void)?

        override func willMove(toParent parent: UIViewController?) {
            recordEvent?("pin.willMove.toParent=\(parent != nil)")
            super.willMove(toParent: parent)
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            recordEvent?("pin.didMove.toParent=\(parent != nil)")
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hasAppeared = true
            recordEvent?("pin.didAppear")
        }

        override func viewWillDisappear(_ animated: Bool) {
            removalBegan = isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true
            recordEvent?("pin.willDisappear.beforeSuper")
            super.viewWillDisappear(animated)
            recordEvent?("pin.willDisappear.afterSuper")
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            hasDisappeared = true
            recordEvent?("pin.didDisappear")
        }
    }

    private final class LifecycleObservedNavigation: FearlessNavigationController {
        var hasAppeared = false
        private(set) weak var lastShown: UIViewController?
        var recordEvent: ((String) -> Void)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hasAppeared = true
            recordEvent?("navigation.didAppear")
        }

        override func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
            super.navigationController(navigationController, willShow: viewController, animated: animated)
            recordEvent?("navigation.willShow.\(type(of: viewController))")
        }

        func navigationController(_: UINavigationController, didShow viewController: UIViewController, animated _: Bool) {
            lastShown = viewController
            recordEvent?("navigation.didShow.\(type(of: viewController))")
        }
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
        try await assertNavigationPopFencesPendingPinChangeCompletion(animated: false)
    }

    func testActualAnimatedNavigationPopFencesPendingPinChangeCompletion() async throws {
        try await assertNavigationPopFencesPendingPinChangeCompletion(animated: true)
    }

    private func assertNavigationPopFencesPendingPinChangeCompletion(animated: Bool) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive }))
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        let secrets = Secrets(); let interactor = PinChangeInteractor(secretManager: secrets); let wireframe = Wireframe()
        let presenter = PinSetupPresenter(interactor: interactor, wireframe: wireframe); interactor.presenter = presenter
        let controller = LifecycleObservedPinController(nib: R.nib.pinSetupViewController)
        controller.presenter = presenter; controller.mode = .create
        controller.localizationManager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let root = UIViewController(); let navigation = LifecycleObservedNavigation(rootViewController: root)
        var events: [String] = []
        let started = ProcessInfo.processInfo.systemUptime
        let record: (String) -> Void = { [weak controller, weak navigation, weak interactor] event in
            let elapsed = ProcessInfo.processInfo.systemUptime - started
            let inStack = controller.map { item in navigation?.viewControllers.contains(where: { $0 === item }) == true } ?? false
            events.append(String(format: "%.6f", elapsed) + " " + event +
                " inStack=\(inStack) parent=\(controller?.parent != nil) moving=\(controller?.isMovingFromParent == true)" +
                " removalBegan=\(controller?.removalBegan == true) disappeared=\(controller?.hasDisappeared == true)" +
                " presenterAttached=\(interactor?.presenter != nil) transition=\(navigation?.transitionCoordinator != nil)")
        }
        controller.recordEvent = record
        navigation.recordEvent = record
        let saveReplyDelivered = expectation(description: "Pending PIN save callback is delivered")
        secrets.onSaveReply = { event in
            record(event)
            if event == "save.reply.afterCompletion" { saveReplyDelivered.fulfill() }
        }
        wireframe.onShowMain = { record("wireframe.showMain") }
        defer {
            record("test.cleanup")
            let attachment = XCTAttachment(string: events.joined(separator: "\n"))
            attachment.name = "pin-pop-lifecycle-" + (animated ? "animated" : "nonanimated")
            attachment.lifetime = .keepAlways
            add(attachment)
            controller.recordEvent = nil; navigation.recordEvent = nil
            secrets.onSaveReply = nil; wireframe.onShowMain = nil
            window.isHidden = true; window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        window.rootViewController = navigation; window.makeKeyAndVisible(); window.layoutIfNeeded()
        for _ in 0 ..< 100 {
            if navigation.hasAppeared, navigation.lastShown === root, navigation.transitionCoordinator == nil { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard navigation.hasAppeared, navigation.lastShown === root, navigation.transitionCoordinator == nil else {
            XCTFail("The production navigation root must finish appearing before the PIN push")
            return
        }
        navigation.pushViewController(controller, animated: true)
        for _ in 0 ..< 100 {
            if controller.hasAppeared, navigation.lastShown === controller, navigation.transitionCoordinator == nil { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard controller.hasAppeared, navigation.lastShown === controller, navigation.transitionCoordinator == nil else {
            XCTFail("The PIN push and actual appearance must finish before input")
            return
        }
        XCTAssertTrue(controller.navigationControlling === navigation)
        XCTAssertTrue(window.isKeyWindow)
        XCTAssertTrue(controller.view.window === window)
        record("input.begin")
        // Each actual control action gets its own event-loop opportunity, as on
        // the production screen; only the pending save acknowledgement is held.
        for digit in "123456123456" {
            try tapDigits(String(digit), controller: controller, window: window)
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
        XCTAssertEqual(secrets.saves.count, 1)
        guard secrets.saves.count == 1 else { return }
        XCTAssertTrue(interactor.presenter === presenter)
        XCTAssertTrue(navigation.isNavigationBarHidden)
        XCTAssertFalse(controller.view.isUserInteractionEnabled)
        record("pop.before")
        let popped = navigation.popViewController(animated: animated)
        record("pop.returned")
        // Do not wait for UIKit disappearance callbacks before delivering the
        // save. Their ordering is diagnostic; stale navigation is the contract.
        secrets.answer(0, true)
        record("save.reply.queued")
        XCTAssertTrue(popped === controller)
        XCTAssertFalse(navigation.viewControllers.contains(where: { $0 === controller }))
        await fulfillment(of: [saveReplyDelivered], timeout: 5)
        // Drain the presenter's queued delivery after the save callback, without
        // inserting a time delay that could postpone that callback until removal.
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        for _ in 0 ..< 100 {
            if controller.hasDisappeared, navigation.lastShown === root, navigation.transitionCoordinator == nil { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        record("departure.observed")
        XCTAssertTrue(controller.removalBegan, "Completed removal must run the PIN screen's departure lifecycle")
        XCTAssertTrue(controller.hasDisappeared)
        XCTAssertTrue(navigation.lastShown === root)
        XCTAssertNil(interactor.presenter, "Completed departure must cancel the pending PIN attempt")
        XCTAssertTrue(navigation.topViewController === root)
        XCTAssertEqual(wireframe.main, 0)
        XCTAssertEqual(secrets.savedPin, "123456")
        presenter.submit(pin: "654321")
        XCTAssertEqual(secrets.saves.count, 1)
    }

    func testSavedPinClearsWrongAttemptsAndTrustsEnrollmentOnlyWhenBiometryIsChosen() async throws {
        for enable in [true, false] {
            let secrets = Secrets(); secrets.savedPin = nil
            let biometry = Biometry(); biometry.availableBiometryType = .touchId
            let keystore = InMemoryKeychain()
            let limiter = PincodeAttemptLimiter(keystore: keystore)
            for _ in 0 ..< 9 { limiter.registerFailure() }
            let enrollment = EnrollmentStub(); enrollment.trusted = false
            let output = Output()
            let interactor = PinSetupInteractor(
                secretManager: secrets, settingsManager: Settings(), biometryAuth: biometry, locale: Locale(identifier: "en"),
                attemptLimiter: limiter, enrollmentGuard: enrollment
            )
            interactor.presenter = output
            interactor.process(pin: "123456")
            output.decisions[0](enable)
            XCTAssertGreaterThan(limiter.remainingLockout(), 0, "Nothing changes before the PIN is stored")
            secrets.answer(0, true); try await settle()
            XCTAssertEqual(output.saved, 1)
            XCTAssertEqual(limiter.remainingLockout(), 0)
            XCTAssertFalse(try keystore.checkKey(for: fearless.KeystoreTag.pincodeAttempts.rawValue))
            XCTAssertEqual(enrollment.trustCalls, enable ? 1 : 0)
        }

        let secrets = Secrets(); let keystore = InMemoryKeychain()
        let limiter = PincodeAttemptLimiter(keystore: keystore)
        for _ in 0 ..< 6 { limiter.registerFailure() }
        let change = PinChangeInteractor(secretManager: secrets, attemptLimiter: limiter); let output = Output()
        change.presenter = output; change.process(pin: "654321")
        XCTAssertGreaterThan(limiter.remainingLockout(), 0)
        secrets.answer(0, true); try await settle()
        XCTAssertEqual(output.saved, 1)
        XCTAssertEqual(limiter.remainingLockout(), 0)
    }

    func testAcknowledgedChangedPinAuthenticatesAndOldPinDoesNot() async throws {
        let secrets = Secrets(); let interactor = PinChangeInteractor(secretManager: secrets); let output = Output()
        interactor.presenter = output; interactor.process(pin: "123456"); secrets.answer(0, true); try await settle()
        let auth = LocalAuthInteractor(
            secretManager: secrets, settingsManager: Settings(), biometryAuth: Biometry(), locale: Locale(identifier: "en"),
            attemptLimiter: PincodeAttemptLimiter(keystore: InMemoryKeychain()), enrollmentGuard: EnrollmentStub()
        )
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

/// Profile's wireframe keeps its pending authorization where `AuthorizationAccessible` reads it.
extension ProfileWireframe: @retroactive AuthorizationAccessible {}

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
            let interactor = LocalAuthInteractor(
                secretManager: attempt.secrets, settingsManager: settings, biometryAuth: attempt.biometry, locale: localization.selectedLocale,
                attemptLimiter: PincodeAttemptLimiter(keystore: InMemoryKeychain()), enrollmentGuard: EnrollmentStub()
            )
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
        let wireframe: ProfileWireframe
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
        return Fixture(factory: factory, wireframe: wireframe, profile: profile, navigation: navigation, window: window)
    }

    private func waitUntil(_ description: String, _ condition: () -> Bool) async throws {
        for _ in 0 ..< 100 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail(description)
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }

    private func open(_ fixture: Fixture, settled: Bool = true) async throws -> Attempt {
        // A dismissed authorization releases Profile a run-loop turn after UIKit ends the transition. It must
        // release, or Change PIN would stay stuck; a tap in that one turn is ignored by design.
        try await waitUntil("A finished authorization must release Profile's next tap") { !fixture.wireframe.isAuthorizing }
        let table = fixture.profile.rootView.tableView
        var selected: IndexPath?
        for section in 0 ..< table.numberOfSections {
            for row in 0 ..< table.numberOfRows(inSection: section) {
                let index = IndexPath(row: row, section: section)
                // Ask the table for the row: calling the data source directly dequeues outside a table
                // request, and UIKit raises when a later open() dequeues the same index path again.
                table.scrollToRow(at: index, at: .none, animated: false)
                fixture.window.layoutIfNeeded()
                let cell = try XCTUnwrap(table.cellForRow(at: index))
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
        var replies: [@Sendable(Bool, Error?) -> Void] = []
        var invalidations = 0
        var available = true
        override var biometryType: LABiometryType { .faceID }
        override func canEvaluatePolicy(_: LAPolicy, error _: NSErrorPointer) -> Bool { available }
        override func evaluatePolicy(_: LAPolicy, localizedReason _: String, reply: @escaping @Sendable(Bool, Error?) -> Void) { replies.append(reply) }
        override func invalidate() { invalidations += 1 }
    }

    func testUnavailableBiometryHasNoEnrollmentState() {
        let context = Context()
        context.available = false
        XCTAssertNil(BiometryAuth.currentEnrollmentState(context: context))
        XCTAssertEqual(context.invalidations, 1)
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

/// Lockout schedule, clock handling and persistence of the wrong-PIN count with controlled clocks and an in-memory
/// Keychain.
final class PincodeLockoutPolicyTests: XCTestCase {
    func testFiveFreeAttemptsThenOneFiveFifteenAndSixtyMinutes() {
        XCTAssertEqual(
            (1 ... 10).map(PincodeLockoutPolicy.lockoutDuration(afterFailures:)),
            [0, 0, 0, 0, 0, 60, 300, 900, 3600, 3600]
        )
        let clocks = LockoutClocks()
        let limiter = clocks.limiter(InMemoryKeychain())
        for _ in 0 ..< 5 {
            XCTAssertEqual(limiter.registerFailure(), 0)
            XCTAssertEqual(limiter.remainingLockout(), 0)
        }
        XCTAssertEqual(limiter.registerFailure(), 60)
        XCTAssertEqual(limiter.remainingLockout(), 60)
        clocks.advance(59)
        XCTAssertEqual(limiter.remainingLockout(), 1)
        clocks.advance(1)
        XCTAssertEqual(limiter.remainingLockout(), 0)
        XCTAssertEqual(limiter.registerFailure(), 300)
        clocks.advance(300)
        XCTAssertEqual(limiter.registerFailure(), 900)
        clocks.advance(900)
        XCTAssertEqual(limiter.registerFailure(), 3600)
        clocks.advance(3600)
        XCTAssertEqual(limiter.registerFailure(), 3600)
    }

    func testCountSurvivesRestartsAndOnlyAResetClearsIt() throws {
        let keystore = InMemoryKeychain()
        let clocks = LockoutClocks()
        for _ in 0 ..< 6 { clocks.limiter(keystore).registerFailure() }
        clocks.advance(10)
        let restarted = clocks.limiter(keystore)
        XCTAssertEqual(restarted.remainingLockout(), 50)
        clocks.advance(50)
        XCTAssertEqual(restarted.registerFailure(), 300, "The 7th wrong PIN after a restart still escalates")
        restarted.reset()
        XCTAssertFalse(try keystore.checkKey(for: fearless.KeystoreTag.pincodeAttempts.rawValue))
        XCTAssertEqual(clocks.limiter(keystore).registerFailure(), 0)
    }

    func testSettingTheClockForwardOrBackCannotShortenALockout() {
        let clocks = LockoutClocks()
        let limiter = clocks.limiter(InMemoryKeychain())
        for _ in 0 ..< 9 { limiter.registerFailure() }
        clocks.advance(600)
        clocks.now += 7200
        XCTAssertEqual(limiter.remainingLockout(), 3000, "The monotonic clock still counts 50 minutes")
        clocks.now -= 86400
        XCTAssertEqual(limiter.remainingLockout(), 3000, "A clock set behind the last wrong PIN is ignored")
        clocks.advance(2999)
        XCTAssertEqual(limiter.remainingLockout(), 1)
        clocks.advance(1)
        XCTAssertEqual(limiter.remainingLockout(), 0)
    }

    func testRebootRestartsAnUnfinishedLockoutButNotOneSeenToEnd() {
        let keystore = InMemoryKeychain()
        let clocks = LockoutClocks()
        for _ in 0 ..< 6 { clocks.limiter(keystore).registerFailure() }
        clocks.now += 3600
        clocks.uptime = 5
        XCTAssertEqual(clocks.limiter(keystore).remainingLockout(), 60, "Nothing vouches for the time across a reboot")
        clocks.advance(60)
        XCTAssertEqual(clocks.limiter(keystore).remainingLockout(), 0)
        clocks.now += 10
        clocks.uptime = 1
        XCTAssertEqual(clocks.limiter(keystore).remainingLockout(), 0, "A lockout seen to end stays ended")
        XCTAssertEqual(clocks.limiter(keystore).registerFailure(), 300, "The count still escalates")
    }

    func testUnreadableKeychainStillCountsInThisProcess() {
        final class FailingKeystore: KeystoreProtocol {
            func addKey(_: Data, with _: String) throws { throw KeystoreError.unexpectedFail }
            func updateKey(_: Data, with _: String) throws { throw KeystoreError.unexpectedFail }
            func fetchKey(for _: String) throws -> Data { throw KeystoreError.unexpectedFail }
            func checkKey(for _: String) throws -> Bool { throw KeystoreError.unexpectedFail }
            func deleteKey(for _: String) throws { throw KeystoreError.unexpectedFail }
        }
        let clocks = LockoutClocks()
        let limiter = clocks.limiter(FailingKeystore())
        for _ in 0 ..< 5 { limiter.registerFailure() }
        XCTAssertEqual(limiter.registerFailure(), 60)
        XCTAssertEqual(limiter.remainingLockout(), 60)
    }

    func testPinComparisonMatchesOnlyTheSameDigits() {
        XCTAssertTrue(PincodeComparison.matches("123456", "123456"))
        XCTAssertFalse(PincodeComparison.matches("123457", "123456"))
        XCTAssertFalse(PincodeComparison.matches("12345", "123456"))
        XCTAssertFalse(PincodeComparison.matches("", "123456"))
    }
}

final class BiometryEnrollmentGuardTests: XCTestCase {
    private func enrollment(_ bytes: [UInt8], source: String = BiometryEnrollment.stateHashSource) -> BiometryEnrollment {
        BiometryEnrollment(source: source, state: Data(bytes))
    }

    func testAnUpgradedInstallKeepsBiometricAccessAndIsHeldToThatEnrollment() throws {
        let keystore = InMemoryKeychain()
        var state: BiometryEnrollment? = enrollment([1, 2, 3])
        let guardian = BiometryEnrollmentGuard(keystore: keystore, currentState: { state })

        XCTAssertTrue(guardian.isCurrentEnrollmentTrusted(), "An install from before the check must not be forced to a PIN it may have forgotten")
        let stored = try keystore.fetchKey(for: fearless.KeystoreTag.biometryEnrollment.rawValue)
        XCTAssertEqual(try JSONDecoder().decode(BiometryEnrollment.self, from: stored), enrollment([1, 2, 3]))

        state = enrollment([9])
        XCTAssertFalse(guardian.isCurrentEnrollmentTrusted(), "A face or finger was added or removed after the record")
        state = nil
        XCTAssertFalse(guardian.isCurrentEnrollmentTrusted(), "An unreadable state is never trusted")
        guardian.trustCurrentEnrollment()
        state = enrollment([1, 2, 3])
        XCTAssertTrue(guardian.isCurrentEnrollmentTrusted(), "An unreadable state never replaces the record")
    }

    func testOnlyAPinHolderCanAcceptAChangedEnrollment() {
        let keystore = InMemoryKeychain()
        var state: BiometryEnrollment? = enrollment([1])
        let guardian = BiometryEnrollmentGuard(keystore: keystore, currentState: { state })
        guardian.trustCurrentEnrollment()

        state = enrollment([2])
        XCTAssertFalse(guardian.isCurrentEnrollmentTrusted())
        XCTAssertFalse(guardian.isCurrentEnrollmentTrusted(), "Asking again does not wear the check down")
        guardian.trustCurrentEnrollment()
        XCTAssertTrue(guardian.isCurrentEnrollmentTrusted())
    }

    func testTheIOS18FingerprintAPIDoesNotLockOutAnExistingEnrollment() {
        let keystore = InMemoryKeychain()
        var state: BiometryEnrollment? = enrollment([7, 7], source: BiometryEnrollment.domainStateSource)
        let guardian = BiometryEnrollmentGuard(keystore: keystore, currentState: { state })
        guardian.trustCurrentEnrollment()

        state = enrollment([4, 2], source: BiometryEnrollment.stateHashSource)
        XCTAssertTrue(guardian.isCurrentEnrollmentTrusted(), "Same enrollment, new API bytes after the iOS update")
        state = enrollment([5, 5], source: BiometryEnrollment.stateHashSource)
        XCTAssertFalse(guardian.isCurrentEnrollmentTrusted(), "From then on the new bytes are what it is held to")
    }

    func testARecordFromAnUnknownFormatIsReplacedNotTrustedBlindly() throws {
        let keystore = InMemoryKeychain()
        try keystore.saveKey(Data([1, 2, 3]), with: fearless.KeystoreTag.biometryEnrollment.rawValue)
        let guardian = BiometryEnrollmentGuard(keystore: keystore, currentState: { BiometryEnrollment(source: "x", state: Data([1])) })
        XCTAssertTrue(guardian.isCurrentEnrollmentTrusted())
        let stored = try keystore.fetchKey(for: fearless.KeystoreTag.biometryEnrollment.rawValue)
        XCTAssertEqual(try JSONDecoder().decode(BiometryEnrollment.self, from: stored).state, Data([1]))
    }
}

final class BackgroundSessionLockPolicyTests: XCTestCase {
    func testFiveMinutesAwayOrAClockThatRestartedAsksForThePin() {
        XCTAssertEqual(UtilityConstants.backgroundSessionDropTimeInSeconds, 300)
        XCTAssertFalse(BackgroundSessionLockPolicy.requiresPin(enteredBackgroundAt: 100, now: 399.9))
        XCTAssertTrue(BackgroundSessionLockPolicy.requiresPin(enteredBackgroundAt: 100, now: 400))
        XCTAssertTrue(BackgroundSessionLockPolicy.requiresPin(enteredBackgroundAt: 100, now: 99), "A reboot restarted the clock")
    }

    func testMonotonicClockMovesForward() {
        let first = MonotonicClock.uptime()
        let second = MonotonicClock.uptime()
        XCTAssertGreaterThan(first, 0)
        XCTAssertGreaterThanOrEqual(second, first)
    }
}

/// The shared authorization asked right before any submission that moves funds or changes staking.
@MainActor
final class SubmissionAuthorizerTests: XCTestCase {
    private final class Host: UIViewController, ControllerBackedProtocol {
        var appeared = false
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            appeared = true
        }
    }

    private final class AuthorizationView: UIViewController, PinSetupViewProtocol {
        func didRequestBiometryUsage(biometryType _: AvailableBiometryType, completionBlock _: @escaping (Bool) -> Void) {}
        func didChangeAccessoryState(enabled _: Bool, availableBiometryType _: AvailableBiometryType) {}
        func didFailSavingPin() {}
        func didReceiveWrongPincode() {}
    }

    private func showHost() async throws -> (Host, UIWindow) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let host = Host()
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await waitUntil("The confirm screen must appear before anything is presented on it") { host.appeared }
        return (host, window)
    }

    private func close(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
    }

    private func waitUntil(_ description: String, _ condition: () -> Bool) async throws {
        for _ in 0 ..< 100 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail(description)
    }

    func testWithoutAVisibleScreenNothingIsAuthorized() {
        var results: [Bool] = []
        SubmissionAuthorizer { _ in AuthorizationView() }.authorizeSubmission(from: nil) { results.append($0) }
        SubmissionAuthorizer { _ in AuthorizationView() }.authorizeSubmission(from: Host()) { results.append($0) }
        XCTAssertEqual(results, [false, false])
    }

    func testCancelReportsFalseLeavesTheScreenAndAFreshRequestCanSucceed() async throws {
        let (host, window) = try await showHost()
        defer { close(window) }
        var created: [AuthorizationView] = []
        let authorizer = SubmissionAuthorizer { _ in
            let view = AuthorizationView()
            created.append(view)
            return view
        }
        var results: [Bool] = []
        authorizer.authorizeSubmission(from: host) { results.append($0) }
        XCTAssertTrue(host.presentedViewController === created.first)
        authorizer.authorizeSubmission(from: host) { results.append($0) }
        XCTAssertEqual(results, [false], "A second request while one is open is refused, not queued")
        try await waitUntil("Authorization finishes presenting") { host.transitionCoordinator == nil }

        authorizer.showAuthorizationCompletion(with: false)
        try await waitUntil("Cancel completes") { results.count == 2 }
        XCTAssertEqual(results, [false, false])
        XCTAssertNil(host.presentedViewController)

        authorizer.authorizeSubmission(from: host) { results.append($0) }
        XCTAssertTrue(host.presentedViewController === created.last)
        XCTAssertEqual(created.count, 2)
        try await waitUntil("Authorization finishes presenting") { host.transitionCoordinator == nil }
        authorizer.showAuthorizationCompletion(with: true)
        try await waitUntil("Success completes after dismissal") { results.count == 3 }
        XCTAssertEqual(results, [false, false, true])
        XCTAssertNil(host.presentedViewController)
    }

    func testWaitsForAPresentationAlreadyMovingInsteadOfStrandingConfirm() async throws {
        let (host, window) = try await showHost()
        defer { close(window) }
        let sheet = UIViewController()
        host.present(sheet, animated: true)
        var results: [Bool] = []
        let authorizer = SubmissionAuthorizer { _ in AuthorizationView() }
        authorizer.authorizeSubmission(from: host) { results.append($0) }
        try await waitUntil("Authorization appears once the sheet settles") {
            sheet.presentedViewController is AuthorizationView && sheet.transitionCoordinator == nil
        }
        XCTAssertTrue(results.isEmpty)
        authorizer.showAuthorizationCompletion(with: true)
        try await waitUntil("Success completes") { results == [true] }
    }

    func testPerformAuthorizedRunsTheActionOnlyOnSuccess() {
        final class Fixed: SubmissionAuthorizing {
            let result: Bool
            init(_ result: Bool) { self.result = result }
            func authorizeSubmission(from _: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
                completion(result)
            }
        }
        var runs = 0
        Fixed(false).performAuthorized(from: nil) { runs += 1 }
        XCTAssertEqual(runs, 0)
        Fixed(true).performAuthorized(from: nil) { runs += 1 }
        XCTAssertEqual(runs, 1)
    }
}
