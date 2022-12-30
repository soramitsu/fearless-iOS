import UIKit

final class ValidatorListFilterSortCell: UITableViewCell {
    let selectionImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconListSelectionOn()
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = R.color.colorLightGray()
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = R.color.colorBlack19()
    }

    private func setupLayout() {
        contentView.addSubview(selectionImageView)
        selectionImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.greaterThanOrEqualTo(selectionImageView.snp.trailing).offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }
    }

    func bind(viewModel: SelectableViewModel<TitleWithSubtitleViewModel>) {
        titleLabel.text = viewModel.underlyingViewModel.title
        selectionImageView.isHidden = !viewModel.selectable
    }
}
