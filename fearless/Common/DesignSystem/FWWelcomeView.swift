import UIKit

/// The introduction keeps its existing gateway; wallet choices appear only on the login route.
final class FWWelcomeView: UIView {
    enum Mode { case introduction, walletChoice }

    let scrollView = UIScrollView()
    let titleLabel = UILabel()
    let bodyLabel = UILabel()
    let primaryButton: FWWelcomeActionButton
    let restoreButton: FWWelcomeActionButton
    let preinstalledButton: FWWelcomeActionButton
    let recoveryButton: FWWelcomeActionButton
    let termsButton: FWWelcomeActionButton
    let privacyButton: FWWelcomeActionButton
    private let mode: Mode

    var locale: Locale = .current { didSet { applyLocalization() } }

    init(mode: Mode, effects: FWEffects = .shared) {
        self.mode = mode
        primaryButton = FWWelcomeActionButton(style: .primary, effects: effects)
        restoreButton = FWWelcomeActionButton(style: .secondary, effects: effects)
        preinstalledButton = FWWelcomeActionButton(style: .secondary, effects: effects)
        recoveryButton = FWWelcomeActionButton(style: .link, effects: effects)
        termsButton = FWWelcomeActionButton(style: .link, effects: effects)
        privacyButton = FWWelcomeActionButton(style: .link, effects: effects)
        super.init(frame: .zero)
        setupLayout(effects: effects)
        applyLocalization()
    }

    private func setupLayout(effects: FWEffects) {
        backgroundColor = R.color.fwBgBase()
        let background = FWWelcomeBackgroundView(effects: effects)
        addSubview(background)
        background.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalTo(safeAreaLayoutGuide) }
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        scrollView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide).inset(24)
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-48)
        }
        let logoContainer = makeLogo(effects: effects)
        for label in [titleLabel, bodyLabel] {
            label.numberOfLines = 0
            label.textAlignment = .center
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        titleLabel.accessibilityTraits = .header
        titleLabel.textColor = R.color.fwTextPrimary()
        bodyLabel.textColor = R.color.fwTextSecondary()
        [logoContainer, titleLabel, bodyLabel, primaryButton, restoreButton,
         preinstalledButton, recoveryButton, termsButton, privacyButton].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(24, after: logoContainer)
        stack.setCustomSpacing(32, after: bodyLabel)
        primaryButton.accessibilityIdentifier = "welcomePrimary"
        restoreButton.accessibilityIdentifier = "welcomeRestore"
        preinstalledButton.accessibilityIdentifier = "welcomePreinstalled"
        recoveryButton.accessibilityIdentifier = "welcomeRecovery"
        termsButton.accessibilityIdentifier = "welcomeTerms"
        privacyButton.accessibilityIdentifier = "welcomePrivacy"
        restoreButton.isHidden = mode == .introduction
        preinstalledButton.isHidden = true
        recoveryButton.isHidden = mode == .introduction
        termsButton.isHidden = mode == .introduction
        privacyButton.isHidden = mode == .introduction
    }

    private func makeLogo(effects: FWEffects) -> UIView {
        let logoContainer = UIView()
        let logoWell = FWNeuView(effects: effects)
        logoWell.style = .inset
        logoContainer.addSubview(logoWell)
        logoWell.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.size.equalTo(120)
        }
        let logo = UIImageView(image: R.image.iconFearlessBig()?.withRenderingMode(.alwaysTemplate))
        logo.contentMode = .scaleAspectFit
        logo.tintColor = R.color.fwTextPrimary()
        logo.isAccessibilityElement = true
        logo.accessibilityLabel = "Fearless Wallet"
        logoWell.addSubview(logo)
        logo.snp.makeConstraints { $0.edges.equalToSuperview().inset(20) }
        return logoContainer
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory ||
            previousTraitCollection?.legibilityWeight != traitCollection.legibilityWeight {
            applyLocalization()
        }
    }

    private func applyLocalization() {
        let languages = locale.rLanguages
        configure(titleLabel, text: R.string.localizable.welcomeTitle(preferredLanguages: languages), role: .titleL)
        configure(bodyLabel, text: R.string.localizable.welcomeBody(preferredLanguages: languages), role: .bodyL)
        primaryButton.configure(
            title: mode == .introduction
                ? R.string.localizable.commonContinue(preferredLanguages: languages)
                : R.string.localizable.welcomeCreate(preferredLanguages: languages),
            locale: locale
        )
        restoreButton.configure(
            title: R.string.localizable.welcomeRestore(preferredLanguages: languages),
            locale: locale
        )
        preinstalledButton.configure(
            title: R.string.localizable.onboardingPreinstalledWalletButtonText(preferredLanguages: languages),
            locale: locale
        )
        recoveryButton.configure(title: RecoveryText.string("previous_data", locale: locale.identifier), locale: locale)
        termsButton.configure(
            title: R.string.localizable.aboutTermsAndConditions(preferredLanguages: languages),
            locale: locale
        )
        privacyButton.configure(
            title: R.string.localizable.aboutPrivacyPolicy(preferredLanguages: languages),
            locale: locale
        )
    }

    private func configure(_ label: UILabel, text: String, role: FWFontStyle) {
        let font = UIFont.fw(role, locale: locale, compatibleWith: traitCollection)
        label.font = font
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.minimumLineHeight = UIFont.fwLineHeight(role, locale: locale, compatibleWith: traitCollection)
        label.attributedText = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: paragraph])
    }
}
