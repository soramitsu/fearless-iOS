import UIKit

final class ApplicationStatusView: TriangularedView {
    private enum Constants {
        static let imageViewWidth: CGFloat = 22
    }

    private let imageView = UIImageView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textAlignment = .center
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        shadowOpacity = 0
        strokeWidth = 0
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: ApplicationStatusAlertEvent) {
        fillColor = viewModel.backgroundColor
        highlightedFillColor = viewModel.backgroundColor
        imageView.image = viewModel.image
        titleLabel.text = viewModel.titleText
        descriptionLabel.text = viewModel.descriptionText
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        snp.makeConstraints { make in
            make.height.equalTo(UIConstants.statusViewHeight)
        }

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(Constants.imageViewWidth)
            make.centerY.equalToSuperview()
            make.leading.equalTo(UIConstants.horizontalInset)
        }

        let textVStackView = UIFactory.default.createVerticalStackView(spacing: 2)
        addSubview(textVStackView)
        textVStackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(Constants.imageViewWidth)
            make.leading.greaterThanOrEqualTo(imageView.snp.trailing).offset(UIConstants.horizontalInset)
            make.trailing.greaterThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        textVStackView.addArrangedSubview(titleLabel)
        textVStackView.addArrangedSubview(descriptionLabel)
    }
}
