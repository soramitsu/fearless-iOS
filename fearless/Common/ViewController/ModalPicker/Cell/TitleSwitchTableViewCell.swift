import UIKit

protocol TitleSwitchTableViewCellDelegate: AnyObject {
    func switchOptionChangeState(isOn: Bool)
}

final class TitleSwitchTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = TitleSwitchTableViewCellModel

    var checkmarked: Bool = false
    private weak var delegate: TitleSwitchTableViewCellDelegate?

    private enum LayoutConstants {
        static let iconSize: CGFloat = 22
        static let switcherHeight: CGFloat = 21
        static let switcherWidth: CGFloat = 36
    }

    private let iconImageView = UIImageView()
    private let title: UILabel = {
        let label = UILabel()
        return label
    }()

    private let switchView: UISwitch = {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorPink()
        return switchView
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

    func bind(model: TitleSwitchTableViewCellModel) {
        iconImageView.image = model.icon
        title.text = model.title
        switchView.isOn = model.switchIsOn
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

        switchView.addTarget(
            self,
            action: #selector(switcherValueChanged),
            for: .valueChanged
        )
    }

    private func setupLayout() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(title)
        contentView.addSubview(switchView)

        iconImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.size.equalTo(LayoutConstants.iconSize)
        }

        title.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(iconImageView.snp.trailing).offset(UIConstants.accessoryItemsSpacing)
        }

        switchView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.greaterThanOrEqualTo(title.snp.trailing)
        }

        switchView.set(
            width: LayoutConstants.switcherWidth,
            height: LayoutConstants.switcherHeight
        )
    }

    @objc private func switcherValueChanged() {
        delegate?.switchOptionChangeState(isOn: switchView.isOn)
    }
}
