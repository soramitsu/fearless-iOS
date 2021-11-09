import UIKit

class SwitchView: UIView {
    let switchControl: UISwitch = {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorAccent()
        return switchView
    }()

    let switchDescriptionLabel: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.font = .p1Paragraph
        label.numberOfLines = 2
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(switchControl)
        switchControl.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        addSubview(switchDescriptionLabel)
        switchDescriptionLabel.snp.makeConstraints { make in
            make.leading.equalTo(switchControl.snp.trailing).offset(UIConstants.bigOffset)
            make.trailing.centerY.equalToSuperview()
        }
    }
}
