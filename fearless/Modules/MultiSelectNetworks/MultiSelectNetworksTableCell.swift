import Foundation
import UIKit

final class MultiSelectNetworksTableCell: UITableViewCell {
    private enum Constants {
        static let iconSize = CGSize(width: 32.0, height: 32.0)
        static let checkmarkSize = CGSize(width: 20.0, height: 20.0)
    }

    let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconCheckMark()
        return imageView
    }()

    let iconImageView = UIImageView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h5Title
        return label
    }()

    override var isSelected: Bool {
        didSet {
            if isSelected {
                let image = R.image.iconCheckMark()
                checkmarkImageView.image = image
            } else {
                let image = R.image.iconListSelectionOff()
                checkmarkImageView.image = image
            }
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

//        selectedBackgroundView = UIView()
//        selectedBackgroundView?.backgroundColor = R.color.colorCellSelection()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: MultiSelectNetworksViewModel.CellModel) {
        isSelected = viewModel.isSelected
        titleLabel.text = viewModel.chainName
        viewModel.icon?.loadImage(on: iconImageView, targetSize: Constants.iconSize, animated: true)
    }

    private func setupLayout() {
        let contentStack = UIFactory.default.createHorizontalStackView()
        contentStack.alignment = .center
        contentView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight54)
        }

        contentStack.addArrangedSubview(checkmarkImageView)
        contentStack.addArrangedSubview(iconImageView)
        contentStack.addArrangedSubview(titleLabel)

        contentStack.setCustomSpacing(UIConstants.bigOffset, after: checkmarkImageView)
        contentStack.setCustomSpacing(UIConstants.defaultOffset, after: iconImageView)

        checkmarkImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.checkmarkSize)
        }
        iconImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }
    }
}
