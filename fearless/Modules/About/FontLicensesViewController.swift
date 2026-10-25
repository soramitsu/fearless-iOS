import UIKit

/// The font licence texts are bundled with the app and remain available offline.
final class FontLicensesViewController: UIViewController {
    private let locale: Locale

    init(locale: Locale) {
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
        title = R.string.localizable.aboutFontLicenses(preferredLanguages: locale.rLanguages)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func bundledText(bundle: Bundle = .main) throws -> String {
        try [("Sora 2.000", "Sora-OFL"), ("JetBrains Mono 2.304", "JetBrainsMono-OFL")].map { title, file in
            guard let url = bundle.url(forResource: file, withExtension: "txt") else {
                throw CocoaError(.fileReadNoSuchFile)
            }
            return try title + "\n\n" + String(contentsOf: url, encoding: .utf8)
        }.joined(separator: "\n\n────────────\n\n")
    }

    override func loadView() {
        let textView = UITextView()
        textView.isEditable = false
        textView.alwaysBounceVertical = true
        textView.font = .preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = R.color.fwTextPrimary()
        textView.backgroundColor = R.color.fwBgBase()
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        textView.accessibilityIdentifier = "fontLicensesText"
        let body = (try? Self.bundledText()) ?? R.string.localizable.aboutFontLicensesUnavailable(
            preferredLanguages: locale.rLanguages
        )
        textView.text = (title ?? "") + "\n\n" + body
        view = textView
    }
}
