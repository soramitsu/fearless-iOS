import UIKit

class AssetInfoView: UIView {
    private let verticalStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.defaultOffset)
    private let assetInfoStackView = UIFactory.default.createHorizontalStackView(spacing: UIConstants.minimalOffset)

    private let assetIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let assetNameLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = .white
        return label
    }()

    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(verticalStackView)
        verticalStackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(UIConstants.defaultOffset)
            make.trailing.greaterThanOrEqualToSuperview().inset(UIConstants.defaultOffset)
            make.top.equalToSuperview().offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
        }

        verticalStackView.addArrangedSubview(assetInfoStackView)
        verticalStackView.addArrangedSubview(priceLabel)

        assetInfoStackView.addArrangedSubview(assetIconImageView)
        assetInfoStackView.addArrangedSubview(assetNameLabel)
    }

    func bind(to viewModel: AssetInfoViewModel) {
        assetNameLabel.text = viewModel.assetInfo?.symbol
        priceLabel.attributedText = viewModel.priceAttributedString
        priceLabel.isHidden = viewModel.priceAttributedString == nil

        viewModel.imageViewModel?.loadAmountInputIcon(on: assetIconImageView, animated: false)
    }
}
