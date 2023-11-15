import Foundation
import UIKit

protocol NetworkManagmentTableCellDelegate: AnyObject {
    func didTappedFavouriteButton(at indexPath: IndexPath?)
}

final class NetworkManagmentTableCell: UITableViewCell {
    private enum Constants {
        static let iconSize = CGSize(width: 32.0, height: 32.0)
        static let checkmarkSize = CGSize(width: 20.0, height: 20.0)
    }

    weak var delegate: NetworkManagmentTableCellDelegate?

    let iconImageView = UIImageView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h5Title
        return label
    }()

    let checkmarkImageView = UIImageView()

    let favouriteButton: UIButton = {
        let button = UIButton()
        let image = R.image.iconStar()?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        return button
    }()

    let chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconArrowRightNormal()
        return imageView
    }()

    override var isSelected: Bool {
        didSet {
            if isSelected {
                let image = R.image.listCheckmarkIconPink()
                checkmarkImageView.image = image?.tinted(with: R.color.colorPink()!)
            }
            checkmarkImageView.isHidden = !isSelected
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.kf.cancelDownloadTask()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = R.color.colorBlack19()
        selectionStyle = .none
        setupLayout()
        favouriteButton.addAction { [weak self] in
            self?.delegate?.didTappedFavouriteButton(at: self?.indexPath)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: NetworkManagmentCellViewModel) {
        isSelected = viewModel.isSelected
        titleLabel.text = viewModel.name
        if let isFavourite = viewModel.isFavourite {
            favouriteButton.tintColor = isFavourite ? R.color.colorPink()! : R.color.colorWhite16()!
            checkmarkImageView.snp.makeConstraints { make in
                make.size.equalTo(16)
                make.centerY.equalToSuperview()
                make.trailing.equalToSuperview()
            }
        } else {
            checkmarkImageView.snp.makeConstraints { make in
                make.size.equalTo(16)
                make.center.equalToSuperview()
            }
        }
        favouriteButton.isHidden = viewModel.isFavourite == nil
        viewModel.icon?.loadImage(on: iconImageView, targetSize: Constants.iconSize, animated: true)
    }

    private func setupLayout() {
        let contentStack = UIFactory.default.createHorizontalStackView()
        contentStack.alignment = .center
        contentView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.cellHeight54)
        }

        let checkmarkImageViewContainer = UIView()
        checkmarkImageViewContainer.addSubview(checkmarkImageView)

        contentStack.addArrangedSubview(iconImageView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(checkmarkImageViewContainer)
        contentStack.addArrangedSubview(favouriteButton)
        contentStack.addArrangedSubview(chevronImageView)

        contentStack.setCustomSpacing(UIConstants.defaultOffset, after: iconImageView)

        iconImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }
        checkmarkImageViewContainer.snp.makeConstraints { make in
            make.size.equalTo(44)
        }
        favouriteButton.snp.makeConstraints { make in
            make.size.equalTo(44)
        }
        chevronImageView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }
    }
}
