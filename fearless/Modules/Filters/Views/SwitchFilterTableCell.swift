import UIKit

protocol SwitchFilterTableCellDelegate: AnyObject {
    func switcherValueChanged(isOn: Bool)
}

class SwitchFilterTableCell: UITableViewCell {
    weak var delegate: SwitchFilterTableCellDelegate?

    let filterTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let filterValueSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.onTintColor = R.color.colorPink()
        return switchControl
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        delegate = nil
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
        contentView.addSubview(filterValueSwitch)

        filterTitleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
        }

        filterValueSwitch.snp.makeConstraints { make in
            make.leading.equalTo(filterTitleLabel.snp.trailing).offset(UIConstants.bigOffset)
            make.top.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.bottom.equalToSuperview().inset(UIConstants.bigOffset)
        }
    }

    func bind(to viewModel: SwitchFilterTableCellViewModel) {
        delegate = viewModel

        filterTitleLabel.text = viewModel.title
        filterValueSwitch.isOn = viewModel.enabled

        filterValueSwitch.addTarget(self, action: #selector(switcherValueChanged(sender:)), for: .valueChanged)
    }

    @objc func switcherValueChanged(sender: UISwitch) {
        delegate?.switcherValueChanged(isOn: sender.isOn)
    }
}
