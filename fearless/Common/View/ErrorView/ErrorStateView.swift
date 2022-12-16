import UIKit
import SoraUI

protocol ErrorStateViewDelegate: AnyObject {
    func didRetry(errorView: ErrorStateView)
}

class ErrorStateView: UIView {
    weak var delegate: ErrorStateViewDelegate?

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        let image = R.image.iconAttentionRounded()
        imageView.image = image
        imageView.tintColor = R.color.colorWhite16()!
        return imageView
    }()

    let errorTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    let errorDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.textColor = R.color.colorLightGray()
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    let retryButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(R.color.colorPink(), for: .normal)
        return button
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        applyLocalization()
        retryButton.addTarget(self, action: #selector(handleRetryAction), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let stackView = UIStackView(arrangedSubviews: [iconImageView, errorTitleLabel, errorDescriptionLabel, retryButton])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center

        addSubview(stackView)
        stackView.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    private func applyLocalization() {
        let title = R.string.localizable.commonRetry(preferredLanguages: locale.rLanguages)
        retryButton.setTitle(title, for: .normal)
    }

    @objc
    func handleRetryAction() {
        delegate?.didRetry(errorView: self)
    }

    public func setRetryEnabled(_ enabled: Bool) {
        retryButton.isHidden = !enabled
    }

    public func setTitle(_ title: String?) {
        errorTitleLabel.text = title
        errorTitleLabel.isHidden = title == nil
    }
}
