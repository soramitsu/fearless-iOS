@testable import fearless
import UIKit
import XCTest

@MainActor
final class FWDesignSystemViewTests: XCTestCase {
    private struct Gallery {
        let window: UIWindow
        let scroll: UIScrollView
        let surfaces: [UIView]
        let labels: [UILabel]
        let button: UIButton
    }

    func testEffectsGalleryKeepsGeometryAndControlsAtNormalAndMaximumType() async throws {
        let suite = "fw-gallery-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            var referenceFrames: [CGRect]?
            for mode in ["full", "lite", "reduced", "high-contrast", "calm"] {
                defaults.removeObject(forKey: FWEffects.preferenceKey)
                let effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) {
                    .init(highContrast: mode == "high-contrast")
                }
                if mode == "lite" {
                    effects.userChoice = .lite
                }
                if mode == "reduced" {
                    effects.userChoice = .reduced
                }
                let gallery = try makeGallery(effects: effects, category: category, calm: mode == "calm")
                defer { gallery.window.isHidden = true; gallery.window.rootViewController = nil }
                await Task.yield()
                gallery.window.layoutIfNeeded()
                let frames = gallery.surfaces.map { $0.convert($0.bounds, to: gallery.scroll) }
                if let referenceFrames {
                    XCTAssertEqual(frames, referenceFrames, "Effects must change paint only")
                } else {
                    referenceFrames = frames
                }
                assertLabelsFit(gallery.labels)
                capture(gallery, "\(mode)-\(category.rawValue)-top")
                let buttonFrame = gallery.button.convert(gallery.button.bounds, to: gallery.scroll)
                gallery.scroll.scrollRectToVisible(buttonFrame, animated: false)
                gallery.window.layoutIfNeeded()
                let center = gallery.button.convert(
                    CGPoint(x: gallery.button.bounds.midX, y: gallery.button.bounds.midY), to: gallery.window
                )
                let hit = try XCTUnwrap(gallery.window.hitTest(center, with: nil))
                XCTAssertTrue(
                    hit === gallery.button || hit.isDescendant(of: gallery.button),
                    "Chrome and decorative layers must not consume the control's touch"
                )
                assertButtonVisible(gallery)
                if category.isAccessibilityCategory {
                    capture(gallery, "\(mode)-AX5-actions")
                }
            }
        }
    }

    func testMixedScriptFontGalleryRetainsReadableBodyAndCurrencyAtBothSizes() async throws {
        let suite = "fw-font-gallery-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init() }
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            let gallery = try makeGallery(effects: effects, category: category, mixedScript: true)
            defer { gallery.window.isHidden = true; gallery.window.rootViewController = nil }
            await Task.yield()
            gallery.window.layoutIfNeeded()
            assertLabelsFit(gallery.labels)
            capture(gallery, "mixed-script-\(category.rawValue)-top")
            if category.isAccessibilityCategory {
                gallery.scroll.setContentOffset(CGPoint(x: 0, y: max(0, (gallery.scroll.contentSize.height - gallery.scroll.bounds.height) / 2)), animated: false)
                capture(gallery, "mixed-script-AX5-middle")
                gallery.scroll.scrollRectToVisible(gallery.button.convert(gallery.button.bounds, to: gallery.scroll), animated: false)
                gallery.window.layoutIfNeeded()
                assertButtonVisible(gallery)
                capture(gallery, "mixed-script-AX5-actions")
            }
        }
    }

    private func makeGallery(
        effects: FWEffects, category: UIContentSizeCategory, calm: Bool = false, mixedScript: Bool = false
    ) throws -> Gallery {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = category
            window.traitOverrides.accessibilityContrast = effects.highContrast ? .high : .normal
        }
        let root = UIViewController()
        window.rootViewController = root
        root.view.backgroundColor = R.color.fwBgBase()
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        root.view.addSubview(scroll)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: root.view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: root.view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: root.view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        window.makeKeyAndVisible()
        let traits = window.traitCollection
        func label(_ text: String, _ style: FWFontStyle, locale: String = "en") -> UILabel {
            let label = UILabel()
            label.text = text
            label.font = .fw(style, locale: Locale(identifier: locale), compatibleWith: traits)
            label.numberOfLines = 0
            label.textColor = R.color.fwTextPrimary()
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            return label
        }
        let title = label(mixedScript ? "Баланс · 残高" : "Total balance", .titleL, locale: mixedScript ? "ru" : "en")
        let amount = label("₹12,345.67", .displayL)
        amount.lineBreakMode = .byCharWrapping
        let description = label(mixedScript ? "Доступно · Có sẵn\n利用可能 · 可用余额\n₽ ₫ ₺ ₩ ≈ ₹" : "Available across your visible networks", .bodyM)
        description.textColor = R.color.fwTextSecondary()
        let glass = FWGlassPanelView(effects: effects)
        glass.accent = true
        glass.calm = calm
        glass.shape = { FWChamferPath.path(in: $0, cut: FWTokens.Chamfer.lCut, radius: FWTokens.Chamfer.lRadius) }
        embed([title, amount, description], in: glass)
        stack.addArrangedSubview(glass)
        let address = label("0x71C7656EC7ab88b098defB751B7401B5f6d8976F", .monoM)
        address.lineBreakMode = .byCharWrapping
        let network = label(mixedScript ? "ネットワーク · Сеть" : "Ethereum", .bodyM)
        let well = FWNeuView(effects: effects)
        well.style = .inset
        well.controlFocused = true
        well.calm = calm
        embed([network, address], in: well)
        stack.addArrangedSubview(well)
        let host = UIView()
        let chrome = FWChromeBackgroundView(effects: effects)
        chrome.calm = calm
        chrome.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(chrome)
        NSLayoutConstraint.activate([
            chrome.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            chrome.topAnchor.constraint(equalTo: host.topAnchor),
            chrome.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        let button = UIButton(type: .custom)
        var configuration = UIButton.Configuration.plain()
        configuration.title = mixedScript ? "続ける · Continue" : "Continue"
        configuration.baseForegroundColor = R.color.fwTextOnAccent()
        configuration.background.backgroundColor = R.color.fwFillTop()
        configuration.background.cornerRadius = 0
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        configuration.titleLineBreakMode = .byWordWrapping
        configuration.titleAlignment = .center
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.fw(.labelL, compatibleWith: traits)
            return attributes
        }
        button.configuration = configuration
        button.titleLabel?.numberOfLines = 0
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        embed([button], in: host)
        stack.addArrangedSubview(host)
        root.view.layoutIfNeeded()
        return Gallery(
            window: window,
            scroll: scroll,
            surfaces: [glass, well, host],
            labels: [title, amount, description, network, address] + [button.titleLabel].compactMap { $0 },
            button: button
        )
    }

    private func embed(_ children: [UIView], in parent: UIView) {
        let content = UIStackView(arrangedSubviews: children)
        content.axis = .vertical
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: parent.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -16)
        ])
    }

    private func assertLabelsFit(_ labels: [UILabel], file: StaticString = #filePath, line: UInt = #line) {
        for label in labels {
            XCTAssertGreaterThan(label.bounds.width, 0, file: file, line: line)
            XCTAssertGreaterThanOrEqual(
                label.bounds.height + 1,
                label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height,
                label.text ?? "",
                file: file,
                line: line
            )
        }
    }

    private func assertButtonVisible(_ gallery: Gallery, file: StaticString = #filePath, line: UInt = #line) {
        let button = gallery.button
        XCTAssertGreaterThanOrEqual(button.bounds.height, 48, file: file, line: line)
        if let title = button.titleLabel {
            XCTAssertTrue(button.bounds.insetBy(dx: -1, dy: -1).contains(title.frame), "The entire multiline caption belongs inside the control", file: file, line: line)
        }
        let visible = gallery.scroll.convert(gallery.scroll.bounds, to: gallery.window)
        let frame = button.convert(button.bounds, to: gallery.window)
        XCTAssertTrue(gallery.window.bounds.insetBy(dx: -1, dy: -1).contains(frame), "The complete control must fit the actual compact window", file: file, line: line)
        XCTAssertTrue(visible.insetBy(dx: -1, dy: -1).contains(frame), "The complete control must be reachable by scrolling", file: file, line: line)
    }

    private func capture(_ gallery: Gallery, _ name: String) {
        let window = gallery.window
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        if name.hasSuffix("actions") {
            assertButtonVisible(gallery)
            let geometry = "window=\(window.bounds); root=\(String(describing: window.rootViewController?.view.frame)); scroll=\(gallery.scroll.frame); offset=\(gallery.scroll.contentOffset); content=\(gallery.scroll.contentSize); button=\(gallery.button.convert(gallery.button.bounds, to: window)); title=\(String(describing: gallery.button.titleLabel?.frame))"
            let details = XCTAttachment(string: geometry)
            details.name = "fw-foundation-geometry-" + name
            details.lifetime = .keepAlways
            add(details)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "fw-foundation-320x568-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
