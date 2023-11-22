import UIKit

class SortTableCell: UITableViewCell {
    let filterTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let selectedIndicatorImageView: UIImageView = {
        let selectedIndicatorImageView = UIImageView()
        selectedIndicatorImageView.image = R.image.iconListSelectionOn()
        return selectedIndicatorImageView
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
        backgroundColor = .clear

        separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        selectionStyle = .none
    }

    func setupLayout() {
        contentView.addSubview(filterTitleLabel)
        contentView.addSubview(selectedIndicatorImageView)

        filterTitleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
        }

        selectedIndicatorImageView.snp.makeConstraints { make in
            make.leading.equalTo(filterTitleLabel.snp.trailing).offset(UIConstants.bigOffset)
            make.top.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.bottom.equalToSuperview().inset(UIConstants.bigOffset)
        }
    }

    func bind(to viewModel: SortFilterCellViewModel) {
        filterTitleLabel.text = viewModel.title
        selectedIndicatorImageView.isHidden = !viewModel.selected
    }
}
