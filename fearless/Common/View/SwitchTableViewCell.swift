import UIKit
import SnapKit

protocol SwitchTableViewCellDelegate: AnyObject {
    func didToggle(cell: SwitchTableViewCell)
}

final class SwitchTableViewCell: UITableViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p1Paragraph
        return label
    }()

    let switchView: UISwitch = {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorAccent()
        return switchView
    }()

    weak var delegate: SwitchTableViewCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String, isOn: Bool) {
        titleLabel.text = title
        switchView.isOn = isOn
    }

    private func configure() {
        backgroundColor = .clear
        selectionStyle = .none

        switchView.addTarget(self, action: #selector(actionToggle), for: .valueChanged)
    }

    private func setupLayout() {
        contentView.addSubview(switchView)

        switchView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(switchView.snp.leading).offset(-UIConstants.horizontalInset)
        }
    }

    @objc private func actionToggle() {
        delegate?.didToggle(cell: self)
    }
}
