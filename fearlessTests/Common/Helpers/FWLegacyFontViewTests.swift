@testable import fearless
import SoraFoundation
import UIKit
import XCTest

@MainActor
final class FWLegacyFontViewTests: XCTestCase {
    private final class OnboardingOutput: OnboardingStartViewOutput {
        func didLoad(view _: OnboardingStartViewInput) {}
        func didTapStartButton() {}
    }

    private final class PinPresenter: PinSetupPresenterProtocol {
        func didLoad(view _: PinSetupViewProtocol) {}
        func cancel() {}
        func activateBiometricAuth() {}
        func submit(pin _: String) {}
    }

    func testActualLegacyOnboardingTypographyAtNormalAndMaximumType() async throws {
        for language in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let output = OnboardingOutput()
                let localization = try XCTUnwrap(LocalizationManager(localization: language))
                let controller = OnboardingStartViewController(output: output, localizationManager: localization, welcomeAppearanceEnabled: false)
                let window = try show(controller, category: category)
                defer { window.isHidden = true; window.rootViewController = nil }
                await Task.yield()
                window.layoutIfNeeded()
                let button = try XCTUnwrap(controller.view as? OnboardingStartViewLayout).startButton
                XCTAssertEqual(button.imageWithTitleView?.title, R.string.localizable.commonStart(preferredLanguages: localization.selectedLocale.rLanguages))
                let point = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: window)
                let hit = try XCTUnwrap(window.hitTest(point, with: nil))
                XCTAssertTrue(hit === button || hit.isDescendant(of: button))
                capture(window, name: "onboarding-" + language + "-" + category.rawValue)
            }
        }
    }

    func testActualAboutTypographyAtNormalAndMaximumType() async throws {
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            let controller = try FontLicensesTests.localizedAbout("en")
            let window = try show(controller, category: category)
            defer { window.isHidden = true; window.rootViewController = nil }
            controller.didReceive(locale: Locale(identifier: "en"))
            await Task.yield()
            window.layoutIfNeeded()
            let table = controller.rootView.tableView
            XCTAssertGreaterThan(table.numberOfRows(inSection: 0), 0)
            capture(window, name: "about-" + category.rawValue + "-top")
            table.scrollToRow(at: IndexPath(row: table.numberOfRows(inSection: 0) - 1, section: 0), at: .bottom, animated: false)
            window.layoutIfNeeded()
            capture(window, name: "about-" + category.rawValue + "-bottom")
        }
    }

    func testActualPinNibTypographyAtNormalAndMaximumType() async throws {
        let nibURL = try XCTUnwrap(Bundle.main.url(forResource: "PinSetupViewController", withExtension: "nib"))
        let resource = XCTAttachment(string: "Loaded resource: \(nibURL.path); bundle languages: \(Bundle.main.preferredLocalizations)")
        resource.name = "font-migration-pin-resource-provenance"
        resource.lifetime = .keepAlways
        add(resource)
        for language in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let presenter = PinPresenter()
                let localization = try XCTUnwrap(LocalizationManager(localization: language))
                let controller = PinSetupViewController(nib: R.nib.pinSetupViewController)
                controller.presenter = presenter
                controller.localizationManager = localization
                controller.mode = .create
                controller.localizableTopTitle = LocalizableResource { locale in
                    R.string.localizable.pincodeSetupTopTitle(preferredLanguages: locale.rLanguages)
                }
                let window = try show(controller, category: category)
                defer { window.isHidden = true; window.rootViewController = nil }
                await Task.yield()
                window.layoutIfNeeded()
                let text = labels(in: controller.view).compactMap(\.text)
                XCTAssertTrue(text.contains(R.string.localizable.pincodeSetupTopTitle(preferredLanguages: localization.selectedLocale.rLanguages)))
                XCTAssertTrue(controller.topLabel.font.pointSize >= 20)
                capture(window, name: "pin-nib-" + language + "-" + category.rawValue)
            }
        }
    }

    private func show(_ controller: UIViewController, category: UIContentSizeCategory) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = category
        }
        window.traitCollection.performAsCurrent {
            window.rootViewController = controller
            controller.loadViewIfNeeded()
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
        }
        return window
    }

    private func labels(in view: UIView) -> [UILabel] {
        (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
    }

    private func capture(_ window: UIWindow, name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true), "The complete visible hierarchy must render: \(name)")
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "font-migration-legacy-320x568-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
        let metrics = labels(in: window).map { label in
            "text=\(label.text ?? ""); font=\(label.font.fontName); size=\(label.font.pointSize); frame=\(label.convert(label.bounds, to: window)); fitting=\(label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)))"
        }.joined(separator: "\n")
        let metricAttachment = XCTAttachment(string: metrics)
        metricAttachment.name = "font-migration-legacy-metrics-" + name
        metricAttachment.lifetime = .keepAlways
        add(metricAttachment)
    }
}
