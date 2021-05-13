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

    private let noAlertsLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()?.withAlphaComponent(0.64)
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
            }
        }
    }

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
        // TODO: review mockup and delete noAlertsLabel?
        noAlertsLabel.text = "Everything is fine now. Alerts will appear here."
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        let separatorView = UIView.createSeparator(color: R.color.colorWhite()?.withAlphaComponent(0.24))
        addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(15)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.separatorHeight)
        }

        addSubview(noAlertsLabel)
        noAlertsLabel.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom).offset(UIConstants.horizontalInset)
            make.leading.trailing.bottom.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(alertsStackView)
        alertsStackView.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    func bind(alerts: [StakingAlert]) {
        if alerts.isEmpty {
            noAlertsLabel.isHidden = false
            alertsStackView.isHidden = true
        } else {
            noAlertsLabel.isHidden = true
            alertsStackView.isHidden = false

            let itemViews = alerts.map { alert -> UIView in
                let itemView = AlertItemView(stakingAlert: alert, locale: locale)
                itemView.addTarget(self, action: #selector(handleSelectItem), for: .touchUpInside)
                return itemView
            }

            let separators = (0 ..< itemViews.count).map { _ -> UIView in
                UIView.createSeparator(
                    color: R.color.colorWhite()?.withAlphaComponent(0.24),
                    horizontalInset: UIConstants.horizontalInset
                )
            }

            let itemViewsWithSeparators = zip(itemViews, separators).map { [$0, $1] }
                .flatMap { $0 }
                .dropLast()

            alertsStackView.subviews.forEach { $0.removeFromSuperview() }
            itemViewsWithSeparators.forEach { alertsStackView.addArrangedSubview($0) }

            separators.dropLast().forEach { separator in
                separator.snp.makeConstraints {
                    $0.height.equalTo(UIConstants.separatorHeight)
                }
            }
        }
    }

    @objc
    private func handleSelectItem(sender: UIControl) {
        guard let itemView = sender as? AlertItemView else { return }
        delegate?.didSelectStakingAlert(itemView.alertType)
    }
}

private class AlertItemView: BackgroundedContentControl {
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
        return label
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()?.withAlphaComponent(0.64)
        label.numberOfLines = 0
        return label
    }()

    let accessoryView: UIView = UIImageView(image: R.image.iconSmallArrow())

    init(stakingAlert: StakingAlert, locale: Locale) {
        alertType = stakingAlert
        super.init(frame: .zero)

        let shapeView = ShapeView()
        shapeView.isUserInteractionEnabled = false
        shapeView.fillColor = .clear
        shapeView.highlightedFillColor = R.color.colorCellSelection()!
        backgroundView = shapeView

        setupLayout()

        iconImageView.image = stakingAlert.icon
        titleLabel.text = stakingAlert.title(for: locale)
        descriptionLabel.text = stakingAlert.description(for: locale)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: 77
        )
    }

    private func setupLayout() {
        let containerView = UIView()
        containerView.isUserInteractionEnabled = false

        containerView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(13)
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(16)
        }

        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(13)
            make.leading.equalTo(iconImageView.snp.trailing).offset(8)
        }

        containerView.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel.snp.leading)
            make.bottom.equalToSuperview().inset(14)
        }

        containerView.addSubview(accessoryView)
        accessoryView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(9)
            make.trailing.equalToSuperview().inset(12)
            make.size.equalTo(24)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(UIConstants.horizontalInset)
            make.leading.greaterThanOrEqualTo(descriptionLabel.snp.trailing).offset(UIConstants.horizontalInset)
        }

        contentView = containerView
    }
}
