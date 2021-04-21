import UIKit

final class StakingManageCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = IconWithTitleViewModel

    static let cellHeight: CGFloat = 48

    var checkmarked: Bool = false

    let iconImageView = UIImageView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let disclosureIndicatorView: UIView = UIImageView(image: R.image.iconSmallArrow())

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorAccent()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView
        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        contentView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(disclosureIndicatorView)
        disclosureIndicatorView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing)
        }
    }

    func bind(model: Model) {
        titleLabel.text = model.title
        iconImageView.image = model.icon
    }
}
