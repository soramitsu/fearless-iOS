import UIKit

class SingleTitleTableViewCell: UITableViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
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

    func bind(title: String) {
        titleLabel.text = title
    }

    private func configure() {
        backgroundColor = .clear

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorCellSelection()!
        self.selectedBackgroundView = selectedBackgroundView

        separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        accessoryView = UIImageView(image: R.image.iconSmallArrow())
    }

    private func setupLayout() {
        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }
}
