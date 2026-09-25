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

    func applyLocalization() {}

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
        addSubview(fearlessLogoImageView)
        addSubview(statusLabel)

        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

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
}
