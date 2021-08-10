import UIKit
import FearlessUtils
import SoraUI

final class AnalyticsValidatorsCell: UITableViewCell {
    let iconView: PolkadotIconView = {
        let view = PolkadotIconView()
        view.backgroundColor = .clear
        view.fillColor = R.color.colorWhite()!
        return view
    }()

    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let progressView = RoundedView()

    let progressValueLabel: UILabel = {
        let label = UILabel()
        label.font = .p3Paragraph
        label.textColor = R.color.colorAccent()
        return label
    }()

    let infoButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconInfo(), for: .normal)
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
        setupBackground()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        separatorInset = .init(top: 0, left: UIConstants.horizontalInset, bottom: 0, right: UIConstants.horizontalInset)
    }

    private func setupLayout() {
        let content = UIView.hStack(
            alignment: .center,
            spacing: 12,
            [
                iconView,
                .vStack(
                    alignment: .leading,
                    [
                        nameLabel,
                        .hStack([progressView, progressValueLabel])
                    ]
                ),
                infoButton
            ]
        )

        iconView.snp.makeConstraints { $0.size.equalTo(24) }
        contentView.addSubview(content)
        content.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview().inset(8)
        }
    }

    private func setupBackground() {
        backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellSelection()
    }

    func bind(viewModel: AnalyticsValidatorItemViewModel) {
        if let icon = viewModel.icon {
            iconView.bind(icon: icon)
        }
        nameLabel.text = viewModel.validatorName
        progressValueLabel.text = viewModel.progressText
    }
}
