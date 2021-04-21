import UIKit
import SoraUI

protocol ErrorStateViewDelegate: AnyObject {
    func didRetry(errorView: ErrorStateView)
}

class ErrorStateView: UIView {
    weak var delegate: ErrorStateViewDelegate?

    let iconImageView = UIImageView(image: R.image.iconLoadingError())

    let errorDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    let retryButton: UIButton = {
        let button = UIButton()
        button.setTitle("Retry", for: .normal) // TODO: localize
        button.setTitleColor(R.color.colorPink(), for: .normal)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        retryButton.addTarget(self, action: #selector(handleRetryAction), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        let stackView = UIStackView(arrangedSubviews: [iconImageView, errorDescriptionLabel, retryButton])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center

        addSubview(stackView)
        stackView.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    @objc
    func handleRetryAction() {
        delegate?.didRetry(errorView: self)
    }
}
