import UIKit

class AssetInfoView: UIView {
    enum LayoutConstants {
        static let actionsViewHeight: CGFloat = 80
        static let chainOptionsViewHeight: CGFloat = 20
    }

    private let verticalStackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.defaultOffset)
        stackView.alignment = .center
        return stackView
    }()

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

    private let chainView = ChainOptionsView()

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
        verticalStackView.addArrangedSubview(chainView)
        verticalStackView.addArrangedSubview(priceLabel)

        assetInfoStackView.addArrangedSubview(assetIconImageView)
        assetInfoStackView.addArrangedSubview(assetNameLabel)

        assetIconImageView.snp.makeConstraints { make in
            make.size.equalTo(32)
        }

        chainView.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.chainOptionsViewHeight)
        }
    }

    func bind(to viewModel: AssetInfoViewModel) {
        assetNameLabel.text = viewModel.assetInfo?.symbol
        priceLabel.attributedText = viewModel.priceAttributedString
        priceLabel.isHidden = viewModel.priceAttributedString == nil

        if let chainViewModel = viewModel.chainViewModel {
            chainView.bind(to: chainViewModel)
        }

        viewModel.imageViewModel?.loadAssetInfoIcon(on: assetIconImageView, animated: false)
    }
}
