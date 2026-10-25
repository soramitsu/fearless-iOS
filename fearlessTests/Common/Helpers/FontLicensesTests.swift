@testable import fearless
import SoraFoundation
import UIKit
import XCTest

@MainActor
final class FontLicensesTests: XCTestCase {
    private final class Actions: AboutPresenterProtocol {
        var opened: [String] = []
        func didLoad(view: AboutViewProtocol) {
            guard let url = URL(string: "https://example.invalid") else { return XCTFail("Invalid fixture URL") }
            view.didReceive(state: .loaded([
                AboutViewModel(title: "Website", subtitle: nil, icon: nil, action: .website(url)),
                AboutViewModel(title: "Email", subtitle: nil, icon: nil, action: .email),
                AboutViewModel(title: "Font licences", subtitle: nil, icon: nil, action: .fontLicenses)
            ]))
        }

        func activateWriteUs() {
            opened.append("email")
        }

        func activate(url _: URL) {
            opened.append("website")
        }

        func activateFontLicenses() {
            opened.append("licences")
        }
    }

    func testAboutActionsKeepFontLicensesSeparateFromEmailAndExternalURLs() {
        let actions = Actions()
        let controller = AboutViewController(locale: Locale(identifier: "en"), presenter: actions)
        controller.loadViewIfNeeded()
        for row in 0 ..< 3 {
            controller.tableView(controller.rootView.tableView, didSelectRowAt: IndexPath(row: row, section: 0))
        }
        XCTAssertEqual(actions.opened, ["website", "email", "licences"])
    }

    func testBundledLicensesContainBothExactTextsAndMissingBundleFailsExplicitly() throws {
        let text = try FontLicensesViewController.bundledText()
        for resource in ["Sora-OFL", "JetBrainsMono-OFL"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: resource, withExtension: "txt"))
            XCTAssertTrue(try text.contains(String(contentsOf: url, encoding: .utf8)))
        }
        XCTAssertTrue(text.contains("Sora 2.000"))
        XCTAssertTrue(text.contains("JetBrains Mono 2.304"))
        XCTAssertThrowsError(try FontLicensesViewController.bundledText(bundle: Bundle(for: FontLicensesTests.self)))
    }

    func testActualAboutRowOpensOfflineLicensesThroughPresenter() throws {
        let about = try XCTUnwrap(AboutViewFactory.createView()?.controller as? AboutViewController)
        let navigation = UINavigationController(rootViewController: about)
        about.loadViewIfNeeded()
        let table = about.rootView.tableView
        let lastRow = table.numberOfRows(inSection: 0) - 1
        XCTAssertEqual(lastRow, AboutRow.allCases.count - 1)
        UIView.performWithoutAnimation {
            about.tableView(table, didSelectRowAt: IndexPath(row: lastRow, section: 0))
        }
        XCTAssertTrue(navigation.topViewController is FontLicensesViewController)
    }

    func testActualOfflineLicenseRouteIsScrollableAtNormalAndMaximumType() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for language in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let locale = Locale(identifier: language)
                let about = try Self.localizedAbout(language)
                let navigation = UINavigationController(rootViewController: about)
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
                window.overrideUserInterfaceStyle = .dark
                if #available(iOS 17.0, *) {
                    window.traitOverrides.preferredContentSizeCategory = category
                }
                window.traitCollection.performAsCurrent {
                    window.rootViewController = navigation
                    window.makeKeyAndVisible()
                    window.layoutIfNeeded()
                }
                defer { window.isHidden = true; window.rootViewController = nil }
                await Task.yield()
                window.layoutIfNeeded()
                let table = about.rootView.tableView
                let index = IndexPath(row: table.numberOfRows(inSection: 0) - 1, section: 0)
                table.scrollToRow(at: index, at: .bottom, animated: false)
                window.layoutIfNeeded()
                let cell = try XCTUnwrap(table.cellForRow(at: index))
                let arrowAsset = try XCTUnwrap(R.image.iconSmallArrow())
                let arrow = try XCTUnwrap(cell.contentView.subviews.compactMap { $0 as? UIImageView }.first { $0.image?.size == arrowAsset.size })
                XCTAssertEqual(arrow.bounds.size, arrowAsset.size, "The disclosure arrow must preserve its intrinsic size")
                let title = try XCTUnwrap(labels(in: cell).first {
                    $0.text == R.string.localizable.aboutFontLicenses(preferredLanguages: locale.rLanguages)
                })
                let size = title.sizeThatFits(CGSize(width: title.bounds.width, height: .greatestFiniteMagnitude))
                XCTAssertLessThanOrEqual(size.height, title.bounds.height + 1, "Licence title must wrap fully: \(language); font: \(title.font.fontName) \(title.font.pointSize); bounds: \(title.bounds); preferred: \(title.preferredMaxLayoutWidth); intrinsic: \(title.intrinsicContentSize)")
                let cellBounds = cell.convert(cell.bounds, to: window)
                let tableViewport = table.convert(table.bounds.inset(by: table.adjustedContentInset), to: window)
                XCTAssertTrue(tableViewport.insetBy(dx: -1, dy: -1).contains(cellBounds), "The complete licence row must fit in the scrolling viewport: \(language); row: \(cellBounds); viewport: \(tableViewport)")
                XCTAssertGreaterThanOrEqual(cellBounds.height, 48 - 0.01)
                capture(window, name: "\(language)-\(category.rawValue)-about-row")
                about.tableView(table, didSelectRowAt: index)
                if let transition = navigation.transitionCoordinator {
                    let finished = expectation(description: "The actual licence navigation finishes")
                    transition.animate(alongsideTransition: nil) { _ in finished.fulfill() }
                    await fulfillment(of: [finished], timeout: 2)
                }
                try await Task.sleep(nanoseconds: 50_000_000)
                window.layoutIfNeeded()
                XCTAssertNil(navigation.transitionCoordinator)
                let screen = try XCTUnwrap(navigation.topViewController as? FontLicensesViewController)
                XCTAssertTrue(navigation.visibleViewController === screen)
                XCTAssertTrue(screen.view.window === window)
                XCTAssertEqual(screen.view.transform, .identity)
                let text = try XCTUnwrap(screen.view as? UITextView)
                XCTAssertFalse(text.isEditable)
                XCTAssertTrue(text.isScrollEnabled)
                XCTAssertTrue(text.text.contains("SIL OPEN FONT LICENSE"))
                XCTAssertEqual(screen.title, R.string.localizable.aboutFontLicenses(preferredLanguages: locale.rLanguages))
                XCTAssertTrue(text.text.hasPrefix(R.string.localizable.aboutFontLicenses(preferredLanguages: locale.rLanguages) + "\n\n"))
                capture(window, name: "\(language)-\(category.rawValue)-top")
                text.layoutManager.ensureLayout(for: text.textContainer)
                let lastCharacter = max(0, (text.text as NSString).length - 2)
                let glyphRange = text.layoutManager.glyphRange(forCharacterRange: NSRange(location: lastCharacter, length: 1), actualCharacterRange: nil)
                let lastGlyph = text.layoutManager.boundingRect(forGlyphRange: glyphRange, in: text.textContainer)
                    .offsetBy(dx: text.textContainerInset.left, dy: text.textContainerInset.top)
                text.setContentOffset(CGPoint(x: 0, y: max(0, text.contentSize.height - text.bounds.height + text.adjustedContentInset.bottom)), animated: false)
                window.layoutIfNeeded()
                let visibleBounds = text.bounds.inset(by: text.adjustedContentInset)
                XCTAssertTrue(visibleBounds.insetBy(dx: -2, dy: -2).contains(lastGlyph), "The final licence text must be reachable: \(lastGlyph), visible: \(visibleBounds)")
                XCTAssertTrue(window.bounds.contains(text.convert(text.bounds, to: window)))
                capture(window, name: "\(language)-\(category.rawValue)-end")
                XCTAssertTrue(navigation.popViewController(animated: false) === screen)
                window.layoutIfNeeded()
                XCTAssertTrue(navigation.visibleViewController === about)
                XCTAssertTrue(about.view.window === window)
            }
        }
    }

    func testAboutLicenceRowRemeasuresWhenDynamicTypeChangesWhileVisible() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for language in ["id", "vi"] {
            let about = try Self.localizedAbout(language)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
            window.rootViewController = about
            window.makeKeyAndVisible()
            defer { window.isHidden = true; window.rootViewController = nil }
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge, .large] {
                if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
                for _ in 0 ..< 3 { await Task.yield() }
                window.layoutIfNeeded()
                let table = about.rootView.tableView
                let index = IndexPath(row: table.numberOfRows(inSection: 0) - 1, section: 0)
                table.scrollToRow(at: index, at: .bottom, animated: false)
                window.layoutIfNeeded()
                let cell = try XCTUnwrap(table.cellForRow(at: index))
                let viewport = table.bounds.inset(by: table.adjustedContentInset)
                XCTAssertTrue(viewport.insetBy(dx: -1, dy: -1).contains(cell.convert(cell.bounds, to: table)))
                let header = try XCTUnwrap(table.tableHeaderView)
                for label in labels(in: header) {
                    let fitting = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                    XCTAssertLessThanOrEqual(fitting.height, label.bounds.height + 1)
                }
                for label in labels(in: cell) where !(label.text ?? "").isEmpty {
                    let fitting = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                    XCTAssertLessThanOrEqual(fitting.height, label.bounds.height + 1)
                }
                capture(window, name: "live-type-\(language)-\(category.rawValue)")
            }
        }
    }

    func testAboutHeaderAndRowsRemeasureForLiveLocaleChangesAtMaximumType() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let about = try Self.localizedAbout("en", localizationManager: localization)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
        window.traitCollection.performAsCurrent {
            window.rootViewController = about
            window.makeKeyAndVisible()
        }
        defer { window.isHidden = true; window.rootViewController = nil }
        for language in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi", "en"] {
            localization.selectedLocalization = language
            try await Task.sleep(nanoseconds: 50_000_000)
            window.layoutIfNeeded()
            let table = about.rootView.tableView
            let header = try XCTUnwrap(table.tableHeaderView)
            let heading = try XCTUnwrap(labels(in: header).first)
            XCTAssertEqual(heading.text, R.string.localizable.aboutTitle(preferredLanguages: [language]))
            XCTAssertLessThanOrEqual(heading.sizeThatFits(CGSize(width: heading.bounds.width, height: .greatestFiniteMagnitude)).height, heading.bounds.height + 1)
            let index = IndexPath(row: table.numberOfRows(inSection: 0) - 1, section: 0)
            table.scrollToRow(at: index, at: .bottom, animated: false)
            window.layoutIfNeeded()
            let cell = try XCTUnwrap(table.cellForRow(at: index))
            XCTAssertTrue(labels(in: cell).contains { $0.text == R.string.localizable.aboutFontLicenses(preferredLanguages: [language]) })
            XCTAssertTrue(table.bounds.inset(by: table.adjustedContentInset).insetBy(dx: -1, dy: -1).contains(cell.convert(cell.bounds, to: table)))
            capture(window, name: "live-locale-" + language + "-AX5")
        }
    }

    static func localizedAbout(_ language: String, localizationManager: LocalizationManager? = nil) throws -> AboutViewController {
        let localization = try XCTUnwrap(localizationManager ?? LocalizationManager(localization: language))
        let config = ApplicationConfig.shared
        let about = AboutData(
            websiteUrl: config.websiteURL, opensourceUrl: config.opensourceURL,
            twitter: config.twitter, youTube: config.youTube, instagram: config.instagram,
            medium: config.medium, wiki: config.wiki,
            telegram: TelegramData(fearlessWallet: config.fearlessWallet, fearlessAnnouncements: config.fearlessAnnouncements, fearlessHappiness: config.fearlessHappiness),
            writeUs: SupportData(title: "", subject: "", details: "", email: config.supportEmail),
            version: config.version, legal: LegalData(termsUrl: config.termsURL, privacyPolicyUrl: config.privacyPolicyURL)
        )
        let presenter = AboutPresenter(about: about, wireframe: AboutWireframe(), aboutViewModelFactory: AboutViewModelFactory(about: about), localizationManager: localization)
        return AboutViewController(locale: localization.selectedLocale, presenter: presenter)
    }

    private func labels(in view: UIView) -> [UILabel] {
        (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
    }

    private func capture(_ window: UIWindow, name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true), "The complete visible hierarchy must render: \(name)")
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "font-licences-320x568-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
