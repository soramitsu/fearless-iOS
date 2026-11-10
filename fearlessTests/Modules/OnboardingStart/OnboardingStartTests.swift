@testable import fearless
import AVFoundation
import CoreText
import SoraFoundation
import UIKit
import XCTest

@MainActor
final class OnboardingStartTests: XCTestCase {
    private final class Presenter: OnboardingMainPresenterProtocol {
        var actions: [String] = []
        func setup() { actions.append("setup") }
        func activateSignup() { actions.append("create") }
        func activateAccountRestore() { actions.append("restore") }
        func activateTerms() { actions.append("terms") }
        func activatePrivacy() { actions.append("privacy") }
        func didTapGetPreinstalled() { actions.append("preinstalled") }
    }

    private final class Output: OnboardingStartViewOutput {
        var starts = 0
        var loads = 0
        func didLoad(view _: OnboardingStartViewInput) { loads += 1 }
        func didTapStartButton() { starts += 1 }
    }

    @MainActor
    private struct Fixture {
        let window: UIWindow
        let view: FWWelcomeView
        let controller: UIViewController
        let localization: LocalizationManager
        let presenter: Presenter?
        let output: Output?
        func close() { window.isHidden = true; window.rootViewController = nil }
    }

    func testDefaultControllersFollowTheCompiledAppearanceFlag() throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let output = Output()
        let intro = OnboardingStartViewController(output: output, localizationManager: localization)
        XCTAssertFalse(intro.isViewLoaded, "Assigning localization must not load the intro early")
        intro.loadViewIfNeeded()
        XCTAssertEqual(intro.welcomeView != nil, FWAppearance.welcomeRestyled)
        let main = OnboardingMainViewController(nib: R.nib.onbordingMain)
        let presenter = Presenter()
        main.presenter = presenter
        main.localizationManager = localization
        main.loadViewIfNeeded()
        XCTAssertEqual(main.welcomeView != nil, FWAppearance.welcomeRestyled)
        XCTAssertEqual(main.navigationItem.rightBarButtonItem == nil, FWAppearance.welcomeRestyled)
        if let welcome = intro.welcomeView {
            welcome.primaryButton.sendActions(for: .touchUpInside)
        } else {
            try XCTUnwrap(intro.view as? OnboardingStartViewLayout).startButton.sendActions(for: .touchUpInside)
        }
        XCTAssertEqual(output.starts, 1)
        if let welcome = main.welcomeView {
            welcome.primaryButton.sendActions(for: .touchUpInside)
            welcome.restoreButton.sendActions(for: .touchUpInside)
        } else {
            let controls = descendants(main.view).compactMap { $0 as? UIControl }
            for action in ["actionSignupWithSender:", "actionRestoreAccessWithSender:"] {
                let control = try XCTUnwrap(controls.first { $0.actions(forTarget: main, forControlEvent: .touchUpInside)?.contains(action) == true })
                control.sendActions(for: .touchUpInside)
            }
        }
        XCTAssertEqual(presenter.actions, ["setup", "create", "restore"])
    }

    func testWelcomeActionsFitAndKeepTheirExistingRoutesInAllLocales() async throws {
        XCTAssertTrue(FWAppearance.welcomeRestyled, "The qualified build must enable the Welcome presentation")
        for language in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                for mode in [FWWelcomeView.Mode.introduction, .walletChoice] {
                    let fixture = try show(mode: mode, language: language, category: category)
                    defer { fixture.close() }
                    await Task.yield()
                    fixture.window.layoutIfNeeded()
                    assertLayout(fixture)
                    let name = "\(mode)-\(language)-\(category.rawValue)"
                    capture(fixture, name: name + "-top")
                    if let controller = fixture.controller as? OnboardingMainViewController {
                        XCTAssertNil(controller.navigationItem.rightBarButtonItem)
                        XCTAssertEqual(fixture.view.recoveryButton.actions(forTarget: controller, forControlEvent: .touchUpInside), ["showRecoveryData"])
                        XCTAssertEqual(fixture.view.recoveryButton.accessibilityLabel, RecoveryText.string("previous_data", locale: language))
                        XCTAssertTrue(fixture.view.preinstalledButton.isHidden)
                        for button in buttons(fixture.view) {
                            if button === fixture.view.recoveryButton {
                                // Route target is checked above; opening real authentication is outside this layout fixture.
                                try reveal(button, in: fixture)
                            } else {
                                try tap(button, in: fixture)
                            }
                            capture(fixture, name: name + "-" + (button.accessibilityIdentifier ?? "action"))
                        }
                        XCTAssertEqual(fixture.presenter?.actions, ["setup", "create", "restore", "terms", "privacy"])
                        controller.didReceive(preinstalledWalletEnabled: true)
                        if language == "ru" {
                            XCTAssertEqual(fixture.view.preinstalledButton.accessibilityLabel, "Получить предустановленный кошелёк")
                        }
                        fixture.window.layoutIfNeeded()
                        assertLayout(fixture)
                        try tap(fixture.view.preinstalledButton, in: fixture)
                        XCTAssertEqual(fixture.presenter?.actions.last, "preinstalled")
                        capture(fixture, name: name + "-preinstalled")
                        controller.didReceive(preinstalledWalletEnabled: false)
                        XCTAssertTrue(fixture.view.preinstalledButton.isHidden)
                    } else {
                        XCTAssertTrue(fixture.view.restoreButton.isHidden)
                        XCTAssertTrue(fixture.view.termsButton.isHidden)
                        XCTAssertTrue(fixture.view.privacyButton.isHidden)
                        XCTAssertTrue(fixture.view.recoveryButton.isHidden)
                        XCTAssertEqual(fixture.output?.loads, 1)
                        try tap(fixture.view.primaryButton, in: fixture)
                        XCTAssertEqual(fixture.output?.starts, 1, "Continue must invoke the existing onboarding gateway")
                        capture(fixture, name: name + "-continue")
                    }
                }
            }
        }
    }

    func testLiveLanguageDynamicTypeAndBoldTextReflowWithoutActivatingRoutes() async throws {
        let fixture = try show(mode: .walletChoice, language: "en", category: .large)
        defer { fixture.close() }
        await Task.yield()
        let initial = fixture.view.titleLabel.font.pointSize
        if #available(iOS 17.0, *) { fixture.window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
        for language in ["ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi", "en"] {
            fixture.localization.selectedLocalization = language
            for _ in 0 ..< 3 { await Task.yield() }
            fixture.window.layoutIfNeeded()
            XCTAssertEqual(fixture.view.titleLabel.text, R.string.localizable.welcomeTitle(preferredLanguages: [language]))
            XCTAssertGreaterThan(fixture.view.titleLabel.font.pointSize, initial)
            XCTAssertEqual(
                fixture.view.recoveryButton.accessibilityLabel,
                RecoveryText.string("previous_data", locale: language)
            )
            assertLayout(fixture)
            for button in buttons(fixture.view) { try reveal(button, in: fixture) }
        }
        let regular = fixture.view.titleLabel.font
        if #available(iOS 17.0, *) { fixture.window.traitOverrides.legibilityWeight = .bold }
        for _ in 0 ..< 3 { await Task.yield() }
        fixture.window.layoutIfNeeded()
        XCTAssertNotEqual(fixture.view.titleLabel.font, regular)
        assertLayout(fixture)
        fixture.view.scrollView.setContentOffset(.zero, animated: false)
        capture(fixture, name: "live-en-AX5-bold-top")
        for button in buttons(fixture.view) { try reveal(button, in: fixture) }
        capture(fixture, name: "live-en-AX5-bold-bottom")
        if #available(iOS 17.0, *) {
            fixture.window.traitOverrides.preferredContentSizeCategory = .large
            fixture.window.traitOverrides.legibilityWeight = .regular
        }
        for _ in 0 ..< 3 { await Task.yield() }
        fixture.window.layoutIfNeeded()
        XCTAssertEqual(fixture.view.titleLabel.font.pointSize, initial, accuracy: 0.01)
        XCTAssertEqual(fixture.presenter?.actions, ["setup"])
    }

    func testEffectsRemainStaticAndReducedPaintRemovesGlowWithoutChangingContent() async throws {
        let suite = "WelcomeEffects-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var system = FWEffects.SystemState()
        let effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { system }
        let view = FWWelcomeView(mode: .walletChoice, effects: effects)
        view.locale = Locale(identifier: "en")
        let controller = UIViewController()
        controller.view = view
        let window = try showWindow(controller, category: .accessibilityExtraExtraExtraLarge)
        defer { window.isHidden = true; window.rootViewController = nil }
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let fixture = Fixture(window: window, view: view, controller: controller, localization: localization, presenter: nil, output: nil)
        for choice in [FWEffectsChoice.automatic, .lite, .reduced] {
            effects.userChoice = choice
            await Task.yield()
            window.layoutIfNeeded()
            assertLayout(fixture)
            XCTAssertEqual(view.primaryButton.layer.shadowOpacity == 0, choice == .reduced)
            XCTAssertTrue(descendants(view).allSatisfy { $0.layer.animationKeys()?.isEmpty ?? true })
            view.scrollView.setContentOffset(.zero, animated: false)
            capture(fixture, name: "effects-\(choice)-AX5-top")
            try reveal(view.primaryButton, in: fixture)
            capture(fixture, name: "effects-\(choice)-AX5-primary")
        }
        effects.userChoice = .automatic
        system.reduceMotion = true
        effects.refresh()
        window.layoutIfNeeded()
        XCTAssertTrue(descendants(view).allSatisfy { $0.layer.animationKeys()?.isEmpty ?? true })
        capture(fixture, name: "effects-reduce-motion-AX5")
        system.reduceTransparency = true
        effects.refresh()
        window.layoutIfNeeded()
        XCTAssertEqual(view.primaryButton.layer.shadowOpacity, 0)
        capture(fixture, name: "effects-reduce-transparency-AX5")
        system = .init(highContrast: true)
        effects.refresh()
        if #available(iOS 17.0, *) { window.traitOverrides.accessibilityContrast = .high }
        await Task.yield()
        window.layoutIfNeeded()
        XCTAssertEqual(view.primaryButton.layer.shadowOpacity, 0)
        assertLayout(fixture)
        capture(fixture, name: "effects-high-contrast-AX5")
        view.primaryButton.isHighlighted = true
        window.layoutIfNeeded()
        XCTAssertEqual(view.primaryButton.layer.shadowOpacity, 0)
        capture(fixture, name: "effects-high-contrast-highlighted-AX5")
    }

    private func show(mode: FWWelcomeView.Mode, language: String, category: UIContentSizeCategory) throws -> Fixture {
        let localization = try XCTUnwrap(LocalizationManager(localization: language))
        if mode == .introduction {
            let output = Output()
            let controller = OnboardingStartViewController(output: output, localizationManager: localization, welcomeAppearanceEnabled: true)
            let window = try showWindow(controller, category: category)
            return try Fixture(
                window: window,
                view: XCTUnwrap(controller.welcomeView),
                controller: controller,
                localization: localization,
                presenter: nil,
                output: output
            )
        }
        let presenter = Presenter()
        let controller = OnboardingMainViewController(nib: R.nib.onbordingMain)
        controller.welcomeAppearanceEnabled = true
        controller.presenter = presenter
        controller.localizationManager = localization
        let navigation = FearlessNavigationController(rootViewController: controller)
        let window = try showWindow(navigation, category: category)
        return try Fixture(
            window: window,
            view: XCTUnwrap(controller.welcomeView),
            controller: controller,
            localization: localization,
            presenter: presenter,
            output: nil
        )
    }

    private func showWindow(_ controller: UIViewController, category: UIContentSizeCategory) throws -> UIWindow {
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
        return window
    }

    private func buttons(_ view: FWWelcomeView) -> [FWWelcomeActionButton] {
        [view.primaryButton, view.restoreButton, view.preinstalledButton, view.recoveryButton, view.termsButton, view.privacyButton].filter { !$0.isHidden }
    }

    private func assertLayout(_ fixture: Fixture) {
        let view = fixture.view
        XCTAssertLessThanOrEqual(view.scrollView.contentSize.width, view.scrollView.bounds.width + 1)
        let labels = [view.titleLabel, view.bodyLabel] + buttons(view).map(\.label)
        for label in labels {
            XCTAssertEqual(
                label.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont,
                label.font,
                "The attributed text must use the assigned role font"
            )
            if view.locale.languageCode == "ja", let text = label.attributedText {
                let names = glyphFontNames(text)
                XCTAssertTrue(names.contains { $0.contains("HiraKakuInterface") || $0.contains("HiraginoSans") }, "\(names)")
                XCTAssertFalse(names.contains { $0.contains("HiraMin") }, "Japanese UI text must retain system sans glyphs")
            }
            let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
            XCTAssertGreaterThan(label.bounds.width, 0)
            XCTAssertLessThanOrEqual(needed.height, label.bounds.height + 1, label.text ?? "")
            XCTAssertFalse(label.hasAmbiguousLayout, label.text ?? "")
        }
        XCTAssertLessThanOrEqual(view.titleLabel.frame.maxY, view.bodyLabel.frame.minY)
        XCTAssertLessThanOrEqual(view.bodyLabel.frame.maxY, view.primaryButton.frame.minY)
        for button in buttons(view) {
            let role: FWFontStyle = button === view.termsButton || button === view.privacyButton || button === view.recoveryButton ? .bodyS : .labelL
            XCTAssertEqual(button.label.font.pointSize, UIFont.fw(role, locale: view.locale, compatibleWith: view.traitCollection).pointSize, accuracy: 0.01)
            XCTAssertGreaterThanOrEqual(button.bounds.height, 48)
            XCTAssertEqual(button.accessibilityLabel, button.label.text)
            XCTAssertTrue(button.isAccessibilityElement)
            XCTAssertTrue(button.accessibilityTraits.contains(.button))
        }
    }

    private func reveal(_ button: FWWelcomeActionButton, in fixture: Fixture) throws {
        let scroll = fixture.view.scrollView
        scroll.scrollRectToVisible(button.convert(button.bounds, to: scroll).insetBy(dx: 0, dy: -4), animated: false)
        fixture.window.layoutIfNeeded()
        let rect = button.convert(button.bounds, to: fixture.window)
        let viewport = scroll.convert(scroll.bounds, to: fixture.window)
        XCTAssertTrue(viewport.insetBy(dx: -1, dy: -1).contains(rect), "\(button.accessibilityLabel ?? "") \(rect) outside \(viewport)")
        let hit = try XCTUnwrap(fixture.window.hitTest(CGPoint(x: rect.midX, y: rect.midY), with: nil))
        XCTAssertTrue(hit === button || hit.isDescendant(of: button))
    }

    private func tap(_ button: FWWelcomeActionButton, in fixture: Fixture) throws {
        try reveal(button, in: fixture)
        button.sendActions(for: .touchUpInside)
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }

    private func capture(_ fixture: Fixture, name: String) {
        let window = fixture.window
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "welcome-320x568-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
        let metrics = descendants(fixture.view).compactMap { $0 as? UILabel }.map {
            "\($0.text ?? ""): \($0.font.fontName) \($0.font.pointSize) \($0.convert($0.bounds, to: window)); glyphs \($0.attributedText.map(glyphFontNames) ?? [])"
        }.joined(separator: "\n")
        let data = XCTAttachment(string: metrics)
        data.name = "welcome-metrics-" + name
        data.lifetime = .keepAlways
        add(data)
    }

    private func glyphFontNames(_ text: NSAttributedString) -> [String] {
        let line = CTLineCreateWithAttributedString(text)
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        return runs.map { run in
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let font = attributes[kCTFontAttributeName] else { return "missing font" }
            // CoreText guarantees that this attribute contains a CTFont.
            return CTFontCopyPostScriptName(font as! CTFont) as String
        }
    }

    func testJapaneseSystemGlyphsMatchSansRatherThanSerifReference() throws {
        let controller = UIViewController()
        controller.view.backgroundColor = .black
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        controller.view.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalTo(controller.view.safeAreaLayoutGuide).offset(12)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        let fonts = [
            UIFont.systemFont(ofSize: 30, weight: .semibold),
            UIFont.systemFont(ofSize: 30, weight: .regular),
            try XCTUnwrap(UIFont(name: "HiraginoSans-W6", size: 30)),
            try XCTUnwrap(UIFont(name: "HiraMinProN-W6", size: 30))
        ]
        var details: [String] = []
        for (index, font) in fonts.enumerated() {
            let caption = UILabel()
            caption.font = .systemFont(ofSize: 12)
            caption.textColor = .gray
            caption.text = "\(index): \(font.fontName)"
            stack.addArrangedSubview(caption)
            let label = UILabel()
            label.font = font
            label.textColor = .white
            label.numberOfLines = 0
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.minimumLineHeight = 40
            let text = NSAttributedString(string: "新しいウォレットを作成", attributes: [.font: font, .paragraphStyle: paragraph])
            label.attributedText = text
            let names = glyphFontNames(text)
            if index < 2 {
                XCTAssertTrue(names.allSatisfy { $0.contains("HiraKakuInterface") || $0.contains("HiraginoSans") })
            } else {
                XCTAssertEqual(names, [font.fontName])
            }
            details.append("reference \(index): \(names), descriptor \(font.fontDescriptor.fontAttributes)")
            stack.addArrangedSubview(label)
        }
        let window = try showWindow(controller, category: .large)
        defer { window.isHidden = true }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        let screenshot = XCTAttachment(image: image)
        screenshot.name = "welcome-japanese-system-sans-serif-reference"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let attachment = XCTAttachment(string: details.joined(separator: "\n"))
        attachment.name = "welcome-japanese-coretext-reference"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWelcomeBaselineNormalAndMaximumType() async throws {
        for language in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let controller = OnboardingMainViewController(nib: R.nib.onbordingMain)
                controller.welcomeAppearanceEnabled = false
                controller.presenter = Presenter()
                let localization = try XCTUnwrap(LocalizationManager(localization: language))
                controller.localizationManager = localization
                controller.termDecorator = CompoundAttributedStringDecorator.legal(for: localization.selectedLocale)
                let navigation = FearlessNavigationController(rootViewController: controller)
                let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
                window.overrideUserInterfaceStyle = .dark
                if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
                window.traitCollection.performAsCurrent {
                    window.rootViewController = navigation
                    window.makeKeyAndVisible()
                    window.layoutIfNeeded()
                }
                defer { window.isHidden = true; window.rootViewController = nil }
                await Task.yield()
                window.layoutIfNeeded()
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "welcome-before-\(language)-\(category.rawValue)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}

/// The welcome's animated crow and its call (Yatagarasu brand, 2026-11-10).
@MainActor
final class FWWelcomeHeroTests: XCTestCase {
    private final class SystemBox {
        var state = FWEffects.SystemState()
    }

    private let system = SystemBox()

    private func effects(reduceMotion: Bool) throws -> FWEffects {
        let suite = "fw-hero-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        system.state.reduceMotion = reduceMotion
        let box = system
        return FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { box.state }
    }

    private func host(_ view: UIView, size: CGSize = CGSize(width: 393, height: 852)) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        let controller = UIViewController()
        controller.view = view
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        addTeardownBlock { window.isHidden = true; window.rootViewController = nil }
        return window
    }

    private func spin(until condition: () -> Bool, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    func testBundleCarriesTheKitsHeroMedia() throws {
        let media = FWWelcomeHeroView.Media.bundled
        for url in [media.loop, media.call, media.sound, media.poster] {
            let url = try XCTUnwrap(url)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), url.lastPathComponent)
        }
        let poster = try XCTUnwrap(media.poster.flatMap { UIImage(contentsOfFile: $0.path) })
        XCTAssertEqual(poster.size.width / poster.size.height, 720.0 / 1560.0, accuracy: 0.001)
    }

    func testTheCallHasSoundAndTheLoopHasNone() async throws {
        let media = FWWelcomeHeroView.Media.bundled
        let call = AVURLAsset(url: try XCTUnwrap(media.call))
        let loop = AVURLAsset(url: try XCTUnwrap(media.loop))
        let callAudio = try await call.loadTracks(withMediaType: .audio)
        let loopAudio = try await loop.loadTracks(withMediaType: .audio)
        XCTAssertFalse(callAudio.isEmpty, "The call plays with sound")
        XCTAssertTrue(loopAudio.isEmpty, "The muted loop never needs the audio session")
        let loopDuration = try await loop.load(.duration).seconds
        let callDuration = try await call.load(.duration).seconds
        XCTAssertEqual(loopDuration, 12, accuracy: 0.05)
        XCTAssertEqual(callDuration, 3, accuracy: 0.05)
    }

    func testFootageFillsThePageAnchoredToTheTop() {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 320, height: 568), CGSize(width: 834, height: 1194),
                     CGSize(width: 390, height: 700), CGSize(width: 360, height: 900)] {
            let bounds = CGRect(origin: .zero, size: size)
            let frame = FWWelcomeHeroView.footageFrame(in: bounds)
            XCTAssertEqual(frame.minY, 0, "\(size)")
            XCTAssertEqual(frame.midX, bounds.midX, accuracy: 0.01, "\(size)")
            XCTAssertEqual(frame.width / frame.height, 720.0 / 1560.0, accuracy: 0.0001, "\(size)")
            XCTAssertTrue(frame.insetBy(dx: -0.01, dy: -0.01).contains(bounds), "aspect-fill covers \(size)")
            XCTAssertTrue(abs(frame.width - size.width) < 0.01 || abs(frame.height - size.height) < 0.01, "\(size)")
        }
    }

    func testLoopPlaysMutedOnScreenAndPausesOffScreenAndInTheBackground() throws {
        let lifecycle = NotificationCenter()
        let hero = FWWelcomeHeroView(effects: try effects(reduceMotion: false), lifecycle: lifecycle)
        XCTAssertFalse(hero.isLooping, "Nothing plays before the hero is on screen")
        let page = UIView()
        let window = try host(page)
        hero.frame = page.bounds
        page.addSubview(hero)
        hero.layoutIfNeeded()
        XCTAssertTrue(hero.isLooping)
        XCTAssertEqual(hero.loopLayer.player?.isMuted, true)
        XCTAssertTrue(hero.accessibilityElementsHidden, "The footage is decorative")
        XCTAssertNotNil(hero.posterView.image, "The poster stays under the video as its fallback")
        XCTAssertEqual(hero.loopLayer.frame, FWWelcomeHeroView.footageFrame(in: hero.bounds))
        lifecycle.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertFalse(hero.isLooping)
        lifecycle.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertTrue(hero.isLooping)
        hero.removeFromSuperview()
        XCTAssertFalse(hero.isLooping, "Off screen the loop pauses")
        page.addSubview(hero)
        XCTAssertNotNil(hero.window ?? window)
        XCTAssertTrue(hero.isLooping)
    }

    func testReduceMotionShowsThePosterAndNeverAutoplays() throws {
        let settings = try effects(reduceMotion: true)
        let hero = FWWelcomeHeroView(effects: settings)
        _ = try host(hero)
        XCTAssertTrue(hero.showsPosterOnly)
        XCTAssertFalse(hero.isLooping)
        XCTAssertNil(hero.loopLayer.player)
        XCTAssertNotNil(hero.posterView.image)
        system.state.reduceMotion = false
        settings.refresh()
        XCTAssertTrue(hero.isLooping, "Turning Reduce Motion off starts the loop")
        system.state.reduceMotion = true
        settings.refresh()
        XCTAssertFalse(hero.isLooping)
        XCTAssertNil(hero.loopLayer.player)
    }

    func testTheCallPlaysOnceWithSoundAndIgnoresTapsWhileItPlays() throws {
        let hero = FWWelcomeHeroView(effects: try effects(reduceMotion: false))
        _ = try host(hero)
        let before = AVAudioSession.sharedInstance().category
        hero.playCall()
        XCTAssertTrue(hero.isPlayingCall)
        let player = try XCTUnwrap(hero.callLayer.player)
        XCTAssertFalse(player.isMuted)
        XCTAssertEqual(player.volume, 1)
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .ambient, "The silent switch mutes the call")
        hero.playCall()
        XCTAssertTrue(hero.callLayer.player === player, "A second tap during the call is ignored")
        spin { hero.loopLayer.opacity == 0 && hero.callLayer.presentation()?.opacity == 1 }
        XCTAssertEqual(hero.callLayer.opacity, 1, "Crossfaded into the call")
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        spin { !hero.isPlayingCall }
        XCTAssertFalse(hero.isPlayingCall)
        XCTAssertEqual(hero.loopLayer.opacity, 1, "Crossfaded back to the loop")
        XCTAssertNil(hero.callLayer.player)
        XCTAssertTrue(hero.isLooping)
        XCTAssertEqual(AVAudioSession.sharedInstance().category, before, "The previous audio category is back")
    }

    func testTheCallStopsWhenTheAppGoesToTheBackground() throws {
        let lifecycle = NotificationCenter()
        let hero = FWWelcomeHeroView(effects: try effects(reduceMotion: false), lifecycle: lifecycle)
        _ = try host(hero)
        hero.playCall()
        XCTAssertTrue(hero.isPlayingCall)
        lifecycle.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertFalse(hero.isPlayingCall)
        XCTAssertNil(hero.callLayer.player)
        XCTAssertEqual(hero.callLayer.opacity, 0)
        XCTAssertEqual(hero.loopLayer.opacity, 1)
        XCTAssertFalse(hero.isLooping)
    }

    func testReduceMotionPlaysTheCallsSoundAloneOverThePoster() throws {
        let hero = FWWelcomeHeroView(effects: try effects(reduceMotion: true))
        _ = try host(hero)
        hero.playCall()
        XCTAssertTrue(hero.isPlayingCall)
        XCTAssertNil(hero.callLayer.player, "No footage moves")
        XCTAssertNil(hero.loopLayer.player)
        hero.playCall()
        XCTAssertNil(hero.callLayer.player)
        spin(until: { !hero.isPlayingCall }, timeout: 8)
        XCTAssertFalse(hero.isPlayingCall, "The sound ends on its own")
    }

    func testWelcomeOffersTheCallAsALabelledButtonOverTheCrow() throws {
        let view = FWWelcomeView(mode: .walletChoice, effects: try effects(reduceMotion: false))
        view.locale = Locale(identifier: "en")
        _ = try host(view)
        XCTAssertEqual(view.callButton.accessibilityLabel, "Play the crow's call")
        XCTAssertTrue(view.callButton.accessibilityTraits.contains(.button))
        XCTAssertTrue(view.callButton.accessibilityTraits.contains(.playsSound))
        XCTAssertTrue(view.hero.accessibilityElementsHidden)
        XCTAssertEqual(view.lockup.accessibilityLabel, "Fearless")
        let button = view.callButton.convert(view.callButton.bounds, to: view)
        XCTAssertGreaterThanOrEqual(button.height, view.bounds.height * 0.3, "The crow is the tap target")
        let lockup = view.lockup.convert(view.lockup.bounds, to: view)
        XCTAssertGreaterThanOrEqual(lockup.minY, button.maxY - 0.5, "The lockup sits below the crow")
        view.callButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(view.hero.isPlayingCall)
    }
}
