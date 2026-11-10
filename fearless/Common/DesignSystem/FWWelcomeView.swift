import UIKit

/// The welcome (Yatagarasu brand, 2026-11-10), as on the design's Welcome board: the animated crow full-bleed behind
/// the top of the page, and the stacked lockup with the actions over the dark lower part. Tapping the crow plays its
/// call. The introduction keeps its existing gateway; wallet choices appear only on the login route.
final class FWWelcomeView: UIView {
    enum Mode { case introduction, walletChoice }

    /// The share of the page the crow keeps clear above the content; longer content scrolls instead.
    static let heroShare: CGFloat = 0.34
    /// The fade from the footage into the ink behind the content.
    static let fadeHeight: CGFloat = 72
    /// The lockup's tallest share of the window, so the actions keep their room on short phones.
    static let lockupHeightFraction: CGFloat = 0.2

    let scrollView = UIScrollView()
    let hero: FWWelcomeHeroView
    /// The crow: a labelled button over the footage that plays the crow's call.
    let callButton = UIButton(type: .custom)
    let lockup: FWLockupView
    let titleLabel = UILabel()
    let bodyLabel = UILabel()
    let primaryButton: FWWelcomeActionButton
    let restoreButton: FWWelcomeActionButton
    let preinstalledButton: FWWelcomeActionButton
    let recoveryButton: FWWelcomeActionButton
    let termsButton: FWWelcomeActionButton
    let privacyButton: FWWelcomeActionButton
    private let mode: Mode
    private let backing = FWWelcomeBackingView()
    private let foot = UIView()

    var locale: Locale = .current { didSet { applyLocalization() } }

    init(mode: Mode, effects: FWEffects = .shared, media: FWWelcomeHeroView.Media = .bundled) {
        self.mode = mode
        hero = FWWelcomeHeroView(media: media, effects: effects)
        // The crow's footage is this page's light, so the lockup carries no glow of its own.
        lockup = FWLockupView(effects: effects, glows: false)
        primaryButton = FWWelcomeActionButton(style: .primary, effects: effects)
        restoreButton = FWWelcomeActionButton(style: .secondary, effects: effects)
        preinstalledButton = FWWelcomeActionButton(style: .secondary, effects: effects)
        recoveryButton = FWWelcomeActionButton(style: .link, effects: effects)
        termsButton = FWWelcomeActionButton(style: .link, effects: effects)
        privacyButton = FWWelcomeActionButton(style: .link, effects: effects)
        super.init(frame: .zero)
        setupLayout()
        applyLocalization()
    }

    private func setupLayout() {
        backgroundColor = FWSunlit.Palette.background
        addSubview(hero)
        hero.snp.makeConstraints { $0.edges.equalToSuperview() }
        // Ink under the home indicator, continuing the content's backing below the scroll view.
        foot.backgroundColor = FWSunlit.Palette.background
        foot.isUserInteractionEnabled = false
        addSubview(foot)
        foot.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        scrollView.alwaysBounceVertical = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalTo(safeAreaLayoutGuide) }
        let stack = setupPage()
        setupContent(in: stack)
    }

    /// The page is at least as tall as the scroll view and its content sits at the bottom, below the crow, on a backing
    /// that scrolls with it so text never sits on the bright footage. Returns the content stack.
    private func setupPage() -> UIStackView {
        let page = UIView()
        scrollView.addSubview(page)
        page.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.greaterThanOrEqualTo(scrollView.frameLayoutGuide)
            make.height.equalTo(scrollView.frameLayoutGuide).priority(.low)
        }
        let heroGuide = UILayoutGuide()
        page.addLayoutGuide(heroGuide)
        heroGuide.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(scrollView.frameLayoutGuide).multipliedBy(Self.heroShare)
        }
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        page.addSubview(backing)
        page.addSubview(callButton)
        page.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(heroGuide.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().inset(24)
        }
        backing.snp.makeConstraints { make in
            make.top.equalTo(stack.snp.top).offset(-Self.fadeHeight)
            make.leading.trailing.bottom.equalToSuperview()
        }
        callButton.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(stack.snp.top)
        }
        callButton.accessibilityIdentifier = "welcomeCrowCall"
        callButton.accessibilityTraits = [.button, .playsSound]
        callButton.addAction(UIAction { [weak self] _ in self?.hero.playCall() }, for: .touchUpInside)
        return stack
    }

    private func setupContent(in stack: UIStackView) {
        let lockupRow = UIView()
        lockupRow.addSubview(lockup)
        lockup.maximumHeightFraction = Self.lockupHeightFraction
        lockup.snp.makeConstraints { make in
            lockup.makePageConstraints(make)
            make.top.bottom.equalToSuperview()
        }
        for label in [titleLabel, bodyLabel] {
            label.numberOfLines = 0
            label.textAlignment = .center
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        titleLabel.accessibilityTraits = .header
        titleLabel.textColor = FWSunlit.Palette.textPrimary
        bodyLabel.textColor = FWSunlit.Palette.textSecondary
        [lockupRow, titleLabel, bodyLabel, primaryButton, restoreButton,
         preinstalledButton, recoveryButton, termsButton, privacyButton].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(24, after: lockupRow)
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
        callButton.accessibilityLabel = R.string.localizable.welcomeCrowCall(preferredLanguages: languages)
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

/// Ink behind the welcome's content: a fade from clear over `FWWelcomeView.fadeHeight` points, then solid.
private final class FWWelcomeBackingView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        let ink = FWSunlit.Palette.background
        gradient.colors = [ink.withAlphaComponent(0), ink.withAlphaComponent(0.82), ink].map(\.cgColor)
        layer.addSublayer(gradient)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        let fade = bounds.height > 0 ? min(1, FWWelcomeView.fadeHeight / bounds.height) : 1
        gradient.locations = [0, NSNumber(value: Double(fade * 0.6)), NSNumber(value: Double(fade))]
        CATransaction.commit()
    }
}
