import UIKit

class NftHeaderCell: UICollectionViewCell {
    private enum LayoutConstants {
        static let imageSize: CGFloat = 152.0
    }

    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 8
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
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

    private func setupSubviews() {
        addSubview(imageView)
        addSubview(titleLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        imageView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.width.equalTo(imageView.snp.height)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom)
        }
    }

    func bind(cellModel: NftHeaderCellViewModel) {
        if let imageViewModel = cellModel.imageViewModel {
            imageViewModel.loadImage(on: imageView, targetSize: CGSize(width: LayoutConstants.imageSize, height: LayoutConstants.imageSize), animated: true, cornerRadius: 0)
        } else {}
    }
}
