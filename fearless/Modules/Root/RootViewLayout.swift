import UIKit

class RootViewLayout: UIView {
    let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    let fearlessLogoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.logo()
        return imageView
    }()

    let statusLabel: UILabel = {
        let label = UILabel()
        label.accessibilityIdentifier = "fearless.root.setup-status"
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    func applyLocalization() {
        guard FWAppearance.startupRecoveryRestyled else { return }
        statusLabel.font = .fw(.bodyL, locale: locale, compatibleWith: traitCollection)
        statusLabel.textColor = R.color.fwTextPrimary()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory ||
            previousTraitCollection?.legibilityWeight != traitCollection.legibilityWeight {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundImageView)

        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        if FWAppearance.startupRecoveryRestyled {
            setupAdaptiveContent()
            return
        }
        addSubview(fearlessLogoImageView)
        addSubview(statusLabel)
        fearlessLogoImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(fearlessLogoImageView.snp.bottom).offset(32)
            make.leading.greaterThanOrEqualToSuperview().offset(32)
            make.trailing.lessThanOrEqualToSuperview().inset(32)
            make.centerX.equalToSuperview()
        }
    }

    private func setupAdaptiveContent() {
        let scroll = UIScrollView()
        let stack = UIStackView()
        let topSpace = UIView()
        let bottomSpace = UIView()
        scroll.alwaysBounceVertical = false
        addSubview(scroll)
        scroll.snp.makeConstraints { $0.edges.equalTo(safeAreaLayoutGuide) }
        scroll.addSubview(stack)
        stack.axis = .vertical
        stack.spacing = 32
        stack.alignment = .fill
        stack.snp.makeConstraints { make in
            make.edges.equalTo(scroll.contentLayoutGuide).inset(24)
            make.width.equalTo(scroll.frameLayoutGuide).offset(-48)
            make.height.equalTo(scroll.frameLayoutGuide).offset(-48).priority(999)
        }
        [topSpace, fearlessLogoImageView, statusLabel, bottomSpace].forEach(stack.addArrangedSubview)
        topSpace.snp.makeConstraints { make in
            make.height.equalTo(bottomSpace)
            make.height.greaterThanOrEqualTo(0)
        }
        bottomSpace.snp.makeConstraints { $0.height.greaterThanOrEqualTo(0) }
        fearlessLogoImageView.contentMode = .scaleAspectFit
        fearlessLogoImageView.isAccessibilityElement = false
        fearlessLogoImageView.snp.makeConstraints { $0.height.equalTo(120) }
        statusLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    }
}
