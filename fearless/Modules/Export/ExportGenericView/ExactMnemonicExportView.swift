import UIKit

protocol ExactMnemonicExportCopying: AnyObject {
    func copyExactMnemonic(_ phrase: String) -> Bool
}

/// Verified legacy TON text whose spacing is part of the original key identity.
final class ExactMnemonicExportView: UIStackView {
    var copyRequested: ((String) -> Bool)?
    private let phrase: String
    private let locale: Locale
    private let heading = UILabel()
    private let warning = UILabel()
    private let text = UILabel()
    private let copyButton = UIFactory.default.createAccessoryButton()

    init(phrase: String, locale: Locale) {
        self.phrase = phrase
        self.locale = locale
        super.init(frame: .zero)
        axis = .vertical
        spacing = 16
        alignment = .fill
        heading.text = R.string.localizable.exportTonExactTitle(preferredLanguages: locale.rLanguages)
        heading.accessibilityTraits.insert(.header)
        warning.text = R.string.localizable.exportTonExactWarning(preferredLanguages: locale.rLanguages)
        warning.accessibilityIdentifier = "ton-export-spacing-warning"
        text.text = phrase
        text.accessibilityIdentifier = "ton-export-exact-text"
        text.lineBreakMode = .byCharWrapping
        for label in [heading, warning, text] {
            label.numberOfLines = 0
            label.textColor = R.color.colorWhite()
            addArrangedSubview(label)
        }
        copyButton.accessibilityIdentifier = "ton-export-copy-exact"
        copyButton.imageWithTitleView?.title = R.string.localizable
            .exportTonExactCopy(preferredLanguages: locale.rLanguages)
        copyButton.addTarget(self, action: #selector(copyExactPhrase), for: .touchUpInside)
        addArrangedSubview(copyButton)
        configureFonts()
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        configureFonts()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        configureFonts()
    }

    private func configureFonts() {
        heading.font = .fw(.titleM, locale: locale, compatibleWith: traitCollection)
        warning.font = .fw(.bodyS, locale: locale, compatibleWith: traitCollection)
        text.font = .fw(.monoS, locale: locale, compatibleWith: traitCollection)
        copyButton.configureWrappingTitle(locale: locale, compatibleWith: traitCollection)
    }

    @objc private func copyExactPhrase() {
        guard copyRequested?(phrase) == true else { return }
        let copied = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
        copyButton.imageWithTitleView?.title = copied
        copyButton.configureWrappingTitle(locale: locale, compatibleWith: traitCollection)
        UIAccessibility.post(notification: .announcement, argument: copied)
    }
}
