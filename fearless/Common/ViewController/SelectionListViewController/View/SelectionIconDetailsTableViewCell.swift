import UIKit

final class SelectionIconDetailsTableViewCell: UITableViewCell {
    let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.listCheckmarkIcon()
        imageView.tintColor = R.color.colorWhite()
        return imageView
    }()

    let iconImageView = UIImageView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p2Paragraph
        return label
    }()

    private var viewModel: SelectableIconDetailsListViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.icon?.cancel(on: iconImageView)
        viewModel?.removeObserver(self)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellSelection()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(checkmarkImageView)

        checkmarkImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(24.0)
        }

        contentView.addSubview(iconImageView)

        iconImageView.snp.makeConstraints { make in
            make.left.equalTo(checkmarkImageView.snp.right).offset(12.0)
            make.centerY.equalToSuperview()
            make.size.equalTo(32.0)
        }

        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(12.0)
            make.right.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(7.0)
        }

        contentView.addSubview(subtitleLabel)

        subtitleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(12.0)
            make.right.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(8.0)
        }
    }

    private func updateSelectionState() {
        checkmarkImageView.isHidden = !(viewModel?.isSelected ?? false)
    }
}

extension SelectionIconDetailsTableViewCell: SelectionItemViewProtocol {
    func bind(viewModel: SelectableViewModelProtocol) {
        guard let iconDetailsViewModel = viewModel as? SelectableIconDetailsListViewModel else {
            return
        }

        self.viewModel = iconDetailsViewModel

        titleLabel.text = iconDetailsViewModel.title
        subtitleLabel.text = iconDetailsViewModel.subtitle

        iconImageView.image = nil
        iconDetailsViewModel.icon?.loadImage(
            on: iconImageView,
            targetSize: CGSize(width: 32.0, height: 32.0),
            animated: true
        )

        updateSelectionState()

        iconDetailsViewModel.addObserver(self)
    }
}

extension SelectionIconDetailsTableViewCell: SelectionListViewModelObserver {
    func didChangeSelection() {
        updateSelectionState()
    }
}
