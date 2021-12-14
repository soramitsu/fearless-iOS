import UIKit
import FearlessUtils

class SearchPeopleTableCell: UITableViewCell {
    enum LayoutConstants {
        static let accountIconSize: CGFloat = 24
        static let detailsIconSize: CGFloat = 24
    }

    let accountIconImageView = PolkadotIconView()

    let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.lineBreakMode = .byTruncatingMiddle
        label.textColor = .white
        return label
    }()

    let detailsIconImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.image = R.image.iconSmallArrow()
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
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

    private func setupLayout() {
        contentView.addSubview(accountIconImageView)
        contentView.addSubview(addressLabel)
        contentView.addSubview(detailsIconImageView)

        accountIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.size.equalTo(LayoutConstants.accountIconSize)
            make.centerY.equalToSuperview()
        }

        addressLabel.snp.makeConstraints { make in
            make.leading.equalTo(accountIconImageView.snp.trailing).offset(UIConstants.defaultOffset)
            make.top.equalToSuperview().offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
        }

        detailsIconImageView.snp.makeConstraints { make in
            make.leading.equalTo(addressLabel.snp.trailing).offset(UIConstants.defaultOffset)
            make.size.equalTo(LayoutConstants.detailsIconSize)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }
    }

    func bind(to viewModel: SearchPeopleTableCellViewModel) {
        addressLabel.text = viewModel.address

        if let icon = viewModel.icon {
            accountIconImageView.bind(icon: icon)
        }
    }
}
