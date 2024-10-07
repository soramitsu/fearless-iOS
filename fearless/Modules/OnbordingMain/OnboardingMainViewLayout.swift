import Foundation
import UIKit

final class OnboardingMainViewLayout: UIView {

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.backgroundImage()
        return imageView
    }()
    
    let backButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconBack(), for: .normal)
        button.backgroundColor = .clear
        button.isHidden = true
        return button
    }()
    
    let logoView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.logo()
        imageView.tintColor = R.color.colorWhite()
        return imageView
    }()
    
    let termsLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isUserInteractionEnabled = true
        return label
    }()
    
    let buttonContainer = UIFactory.default.createVerticalStackView(spacing: 8)
    
    let signUpButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()
    
    let restoreButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyAccessoryStyle()
        return button
    }()
    
    let preInstalledButton: TriangularedButton = {
        let button = TriangularedButton()
        return button
    }()
    
    let bannerContainer = UIFactory.default.createVerticalStackView(spacing: 12)
    let selectRegularBannerView = SelectEcosystemBannerView(ecosystem: .regular)
    let selectTonBannerView = SelectEcosystemBannerView(ecosystem: .ton)

    lazy var termDecorator = CompoundAttributedStringDecorator.legal(for: locale)
    
    var locale: Locale = .current {
        didSet {
            applyLocale()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        buttonContainer.isHidden = true
        buttonContainer.alpha = 0
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private methods
    
    private func configureTermsLabel() {
        if let attributedText = termsLabel.attributedText {
            termsLabel.attributedText = termDecorator.decorate(attributedString: attributedText)
        }
    }

    private func applyLocale() {
        signUpButton.imageWithTitleView?.title = R.string.localizable
            .usernameSetupTitle20(preferredLanguages: locale.rLanguages)
        restoreButton.imageWithTitleView?.title = R.string.localizable
            .onboardingRestoreWallet(preferredLanguages: locale.rLanguages)
        preInstalledButton.imageWithTitleView?.title = R.string.localizable.onboardingPreinstalledWalletButtonText(preferredLanguages: locale.rLanguages)
        preInstalledButton.imageWithTitleView?.iconImage = R.image.iconPreinstalledWallet()
        let text = NSAttributedString(string: R.string.localizable
            .onboardingTermsAndConditions1(preferredLanguages: locale.rLanguages))
        termsLabel.attributedText = text
        
        selectRegularBannerView.titleLabel.text = "Create or import Substrate or EVM accounts"
        selectRegularBannerView.actionButton.imageWithTitleView?.title = "Join EVM or Substrate"
        selectTonBannerView.titleLabel.text = "Connect to the fastest growing ecosystem ever"
        selectTonBannerView.actionButton.imageWithTitleView?.title = "Join TON"

        configureTermsLabel()
    }

    private func setupLayout() {
        addSubview(backgroundImageView)
        addSubview(backButton)
        addSubview(logoView)
        addSubview(termsLabel)
        addSubview(buttonContainer)
        addSubview(bannerContainer)
        buttonContainer.addArrangedSubview(signUpButton)
        buttonContainer.addArrangedSubview(restoreButton)
        buttonContainer.addArrangedSubview(preInstalledButton)
        bannerContainer.addArrangedSubview(selectRegularBannerView)
        bannerContainer.addArrangedSubview(selectTonBannerView)
        
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        backButton.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(10)
            make.leading.equalToSuperview().offset(16)
            make.size.equalTo(44)
        }
        logoView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(149).priority(.low)
            make.centerX.equalToSuperview()
        }
        buttonContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.greaterThanOrEqualTo(logoView.snp.bottom)
        }
        bannerContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.greaterThanOrEqualTo(logoView.snp.bottom)
        }
        termsLabel.snp.makeConstraints { make in
            make.top.equalTo(bannerContainer.snp.bottom).offset(24)
            make.top.equalTo(buttonContainer.snp.bottom).offset(24)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        [signUpButton, restoreButton, preInstalledButton].forEach { view in
            view.snp.makeConstraints { make in
                make.height.equalTo(UIConstants.actionHeight)
            }
        }
    }
}
