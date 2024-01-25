import UIKit
import SoraUI

protocol NftCellDelegate: AnyObject {
    func handle(cellModel: NftCellViewModel)
}

class NftCell: UICollectionViewCell {
    private enum LayoutConstants {
        static let imageSize: CGFloat = 152.0
        static let nameLabelMinHeight: CGFloat = 18.0
        static let descriptionLabelMinHeight: CGFloat = 15.0
        static let buttonHeight: CGFloat = 36.0
    }

    let imageView = UIImageView()

    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.numberOfLines = 0
        label.textColor = R.color.colorWhite()
        return label
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.numberOfLines = 0
        label.textColor = R.color.colorWhite50()
        return label
    }()

    let infoStackView: UIStackView = UIFactory.default.createVerticalStackView()

    let button: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    private var skeletonView: SkrullableView?
    private var cellModel: NftCellViewModel?
    weak var delegate: NftCellDelegate?

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
        infoStackView.addArrangedSubview(nameLabel)
        infoStackView.addArrangedSubview(descriptionLabel)
        addSubview(button)

        setupConstraints()
    }

    private func setupConstraints() {
        imageView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.size.equalTo(LayoutConstants.imageSize)
        }
        nameLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(LayoutConstants.nameLabelMinHeight)
        }
        descriptionLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(LayoutConstants.descriptionLabelMinHeight)
        }
        infoStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.defaultOffset)
            make.top.equalTo(imageView.snp.bottom).offset(UIConstants.defaultOffset)
        }
        button.snp.makeConstraints { make in
            make.top.equalTo(infoStackView.snp.bottom).offset(UIConstants.minimalOffset)
            make.leading.trailing.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.height.equalTo(LayoutConstants.buttonHeight)
        }
    }

    func bind(cellModel: NftCellViewModel) {
        self.cellModel = cellModel
        if let imageViewModel = cellModel.imageViewModel {
            imageViewModel.loadImage(on: imageView, targetSize: CGSize(width: LayoutConstants.imageSize, height: LayoutConstants.imageSize), animated: true, cornerRadius: 0)
        } else {
            imageView.image = R.image.nftStub()
        }
        nameLabel.text = cellModel.name
        descriptionLabel.text = cellModel.description
        switch cellModel.type {
        case .owned:
            button.imageWithTitleView?.title = R.string.localizable.commonActionSend(preferredLanguages: cellModel.locale.rLanguages)
            button.imageWithTitleView?.iconImage = R.image.iconSend()
        case .available:
            button.imageWithTitleView?.title = R.string.localizable.commonShare(preferredLanguages: cellModel.locale.rLanguages)
            button.imageWithTitleView?.iconImage = R.image.iconShare()
        }
        button.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
    }

    @objc
    func didTapButton() {
        if let cellModel = self.cellModel {
            delegate?.handle(cellModel: cellModel)
        }
    }
}
