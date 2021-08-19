import UIKit
import FearlessUtils
import SoraUI
import SnapKit

protocol AnalyticsValidatorsCellDelegate: AnyObject {
    func didTapInfoButton(in cell: AnalyticsValidatorsCell)
}

final class AnalyticsValidatorsCell: UITableViewCell {
    weak var delegate: AnalyticsValidatorsCellDelegate?

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

    let progressView: RoundedView = {
        let view = RoundedView()
        view.fillColor = R.color.colorAccent()!
        return view
    }()

    private var progressValue: Double = 0.0
    private var widthConstraint: Constraint?

    let progressValueLabel: UILabel = {
        let label = UILabel()
        label.font = .p3Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let infoButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconInfo(), for: .normal)
        return button
    }()

    private lazy var progressStackView: UIStackView = {
        UIView.hStack(
            alignment: .center,
            spacing: 8,
            [progressView, progressValueLabel]
        )
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
        setupBackground()
        infoButton.addTarget(self, action: #selector(tapInfoButton), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        progressValue = 0
    }

    private enum Constants {
        static let iconProgressSpacing: CGFloat = 12
        static let progressValueSpacing: CGFloat = 8
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        separatorInset = .init(top: 0, left: UIConstants.horizontalInset, bottom: 0, right: UIConstants.horizontalInset)

        guard progressValue > 0 else {
            widthConstraint?.update(offset: 0)
            progressStackView.setCustomSpacing(0, after: progressView)
            return
        }
        let totalWidth = infoButton.frame.minX
            - Constants.iconProgressSpacing
            - iconView.frame.maxX
            - Constants.iconProgressSpacing
            - Constants.progressValueSpacing
            - progressValueLabel.bounds.width

        progressStackView.setCustomSpacing(Constants.progressValueSpacing, after: progressView)
        let progressViewWidth = totalWidth * CGFloat(progressValue / 100.0)
        widthConstraint?.update(offset: progressViewWidth)
    }

    @objc
    private func tapInfoButton() {
        delegate?.didTapInfoButton(in: self)
    }

    private func setupLayout() {
        let content = UIView.hStack(
            alignment: .center,
            spacing: Constants.iconProgressSpacing,
            [
                iconView,
                .vStack(
                    alignment: .leading,
                    [
                        nameLabel,
                        progressStackView
                    ]
                ),
                infoButton
            ]
        )

        iconView.snp.makeConstraints { $0.size.equalTo(24) }
        progressView.snp.makeConstraints { make in
            make.height.equalTo(4)
            widthConstraint = make.width.equalTo(progressValue).constraint
        }
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
        progressValue = viewModel.progress
    }
}
