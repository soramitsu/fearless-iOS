import UIKit
import SnapKit

protocol SwitchTableViewCellDelegate: AnyObject {
    func didToggle(cell: SwitchTableViewCell)
}

class SwitchTableViewCell: UITableViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p1Paragraph
        return label
    }()

    let switchView: UISwitch = {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorPink()
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

    fileprivate func setupLayout() {
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

    @objc fileprivate func actionToggle() {
        delegate?.didToggle(cell: self)
    }
}

final class TitleSubtitleSwitchTableViewCell: SwitchTableViewCell {
    private enum LayoutConstants {
        static let switcherWidth: CGFloat = 36
        static let switcherHeight: CGFloat = 21
    }

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p2Paragraph
        return label
    }()

    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    override func layoutSubviews() {
        super.layoutSubviews()

        switchView.set(width: LayoutConstants.switcherWidth, height: LayoutConstants.switcherHeight)
    }

    override fileprivate func setupLayout() {
        titleLabel.font = .h5Title
        titleLabel.textColor = R.color.colorLightGray()

        contentView.addSubview(switchView)
        switchView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        switchView.set(width: LayoutConstants.switcherWidth, height: LayoutConstants.switcherHeight)

        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(switchView.snp.leading).offset(-16)
            make.centerY.equalToSuperview()
        }

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
    }

    func bind(viewModel: SelectableViewModel<TitleWithSubtitleViewModel>) {
        titleLabel.text = viewModel.underlyingViewModel.title
        subtitleLabel.text = viewModel.underlyingViewModel.subtitle
        switchView.isOn = viewModel.selectable
    }
}
