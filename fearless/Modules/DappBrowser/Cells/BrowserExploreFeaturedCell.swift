import UIKit

final class DappBrowserFeaturedCell: UICollectionViewCell {
    let posterImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    let iconViewImage: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        return label
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite50()
        label.numberOfLines = 2
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        iconViewImage.layer.cornerRadius = 8
        posterImageView.layer.cornerRadius = 15
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        posterImageView.kf.cancelDownloadTask()
        posterImageView.image = nil
    }

    func configure(model: DappBrowserFeaturedViewModel) {
        model.poster.loadImage(
            on: posterImageView,
            placholder: R.image.featuredBanner(),
            targetSize: bounds.size,
            animated: true
        )
        model.icon.loadImage(
            on: iconViewImage,
            placholder: R.image.iconFearlessSmall(),
            targetSize: CGSize(width: 40, height: 40),
            animated: true
        )
        titleLabel.text = model.dappName
        descriptionLabel.text = model.dappDescription
    }

    private func setup() {
        contentView.addSubview(posterImageView)
        posterImageView.addSubview(iconViewImage)
        let vStackView = UIFactory.default.createVerticalStackView(spacing: 8)
        posterImageView.addSubview(vStackView)
        vStackView.addArrangedSubview(titleLabel)
        vStackView.addArrangedSubview(descriptionLabel)

        posterImageView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        iconViewImage.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview().inset(16)
            make.size.equalTo(40)
        }
        vStackView.snp.makeConstraints { make in
            make.leading.equalTo(iconViewImage.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(8)
            make.centerY.equalTo(iconViewImage.snp.centerY)
        }
    }
}
