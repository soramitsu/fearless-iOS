import UIKit
import SoraUI

protocol AlertsViewDelegate: AnyObject {
    func didSelectStakingAlert(_ alert: StakingAlert)
}

final class AlertsView: UIView {
    weak var delegate: AlertsViewDelegate?

    private let backgroundView: UIView = TriangularedBlurView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let alertsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
                applyAlerts()
            }
        }
    }

    private var alerts: [StakingAlert]?

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyLocalization()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable.stakingAlertsTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        let separatorView = UIView.createSeparator(color: R.color.colorWhite()?.withAlphaComponent(0.24))
        addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(15)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.separatorHeight)
        }

        addSubview(alertsStackView)
        alertsStackView.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    func bind(alerts: [StakingAlert]) {
        self.alerts = alerts
        applyAlerts()
    }

    private func applyAlerts() {
        guard let alerts = alerts else {
            return
        }

        alertsStackView.subviews.forEach { $0.removeFromSuperview() }
        if alerts.isEmpty {
            alertsStackView.isHidden = true
        } else {
            alertsStackView.isHidden = false

            var itemViews = [UIView]()
            for (index, alert) in alerts.enumerated() {
                let alertView = AlertItemView(stakingAlert: alert, locale: locale)
                let rowView = RowView(contentView: alertView)
                rowView.borderView.strokeColor = R.color.colorBlurSeparator()!
                rowView.contentInsets = UIEdgeInsets(
                    top: 0.0,
                    left: UIConstants.horizontalInset,
                    bottom: 0.0,
                    right: UIConstants.horizontalInset
                )

                if index == alerts.count - 1 {
                    rowView.borderView.borderType = .none
                }

                rowView.addTarget(self, action: #selector(handleSelectItem), for: .touchUpInside)
                itemViews.append(rowView)
            }

            itemViews.forEach { alertsStackView.addArrangedSubview($0) }
        }
    }

    @objc
    private func handleSelectItem(sender: UIControl) {
        guard let rowView = sender as? RowView<AlertItemView> else { return }
        delegate?.didSelectStakingAlert(rowView.rowContentView.alertType)
    }
}

private class AlertItemView: UIView {
    let alertType: StakingAlert

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorTransparentText()
        label.numberOfLines = 0
        return label
    }()

    let accessoryView: UIView = UIImageView(image: R.image.iconSmallArrow())

    init(stakingAlert: StakingAlert, locale: Locale) {
        alertType = stakingAlert

        super.init(frame: .zero)

        setupLayout()

        iconImageView.image = stakingAlert.icon
        titleLabel.text = stakingAlert.title(for: locale)
        descriptionLabel.text = stakingAlert.description(for: locale)
        accessoryView.isHidden = !stakingAlert.hasAssociatedAction
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(13)
            make.leading.equalToSuperview()
            make.size.equalTo(16)
        }

        addSubview(accessoryView)
        accessoryView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(9)
            make.trailing.equalToSuperview()
            make.size.equalTo(24)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(13)
            make.leading.equalTo(iconImageView.snp.trailing).offset(8)
            make.trailing.lessThanOrEqualTo(accessoryView.snp.leading).offset(UIConstants.horizontalInset)
        }

        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel.snp.leading)
            make.bottom.equalToSuperview().inset(14)
            make.trailing.lessThanOrEqualTo(accessoryView.snp.leading).offset(UIConstants.horizontalInset)
        }
    }
}
