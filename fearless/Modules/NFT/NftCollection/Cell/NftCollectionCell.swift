import UIKit

class NftCollectionCell: UICollectionViewCell {
    private enum LayoutConstants {
        static let imageSize: CGFloat = 172.0
    }

    let imageView = UIImageView()

    let nftNameLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.numberOfLines = 0
        label.textColor = R.color.colorWhite()
        return label
    }()

    let infoStackView: UIStackView = UIFactory.default.createVerticalStackView()
    let priceStackView: UIStackView = UIFactory.default.createHorizontalStackView(spacing: UIConstants.minimalOffset)

    let priceTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorGray()
        return label
    }()

    let priceValueLabel: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        label.textColor = R.color.colorWhite()
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView.layer.cornerRadius = 12.0
        contentView.layer.borderWidth = 1.0
        contentView.layer.borderColor = R.color.colorWhite8()?.cgColor
    }

    private func setupSubviews() {
        contentView.addSubview(imageView)
        addSubview(infoStackView)
        infoStackView.addArrangedSubview(nftNameLabel)
        infoStackView.addArrangedSubview(priceStackView)
        priceStackView.addArrangedSubview(priceTitleLabel)
        priceStackView.addArrangedSubview(priceValueLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        imageView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.size.equalTo(LayoutConstants.imageSize)
        }

        infoStackView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.top.equalTo(imageView.snp.bottom).offset(UIConstants.defaultOffset)
        }
    }

    func bind(cellModel: NftCollectionCellViewModel) {
        cellModel.imageViewModel?.loadImage(on: imageView, targetSize: CGSize(width: LayoutConstants.imageSize, height: LayoutConstants.imageSize), animated: true, cornerRadius: 0)
        nftNameLabel.text = cellModel.name
    }
}
