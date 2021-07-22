import UIKit
import SoraUI

final class ValidatorInfoViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    var stackView: UIStackView {
        contentView.stackView
    }

    let factory = UIFactory.default

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func clearStackView() {
        let arrangedSubviews = stackView.arrangedSubviews

        arrangedSubviews.forEach {
            contentView.stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    @discardableResult
    func addAccountView(for viewModel: AccountInfoViewModel) -> DetailsTriangularedView {
        let accountView: DetailsTriangularedView

        if viewModel.name.isEmpty {
            accountView = factory.createIdentityView(isSingleTitle: true)
            accountView.title = viewModel.address
        } else {
            accountView = factory.createIdentityView(isSingleTitle: false)
            accountView.title = viewModel.name
            accountView.subtitle = viewModel.address
        }

        accountView.iconImage = viewModel.icon

        stackView.addArrangedSubview(accountView)
        accountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52)
        }

        return accountView
    }

    @discardableResult
    func addSectionHeader(with title: String) -> UIView {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h4Title

        stackView.addArrangedSubview(label)
        label.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        label.text = title

        return label
    }

    @discardableResult
    func addStakingStatusView(
        _ viewModel: ValidatorInfoViewModel.Staking,
        locale: Locale
    ) -> UIView {
        let titleLabel = UILabel()
        titleLabel.textColor = R.color.colorLightGray()
        titleLabel.font = .p1Paragraph
        titleLabel.text = R.string.localizable.stakingRewardDetailsStatus(
            preferredLanguages: locale.rLanguages
        )

        let statusView = TitleStatusView()

        switch viewModel.status {
        case .elected:
            statusView.indicatorColor = R.color.colorGreen()!
            statusView.titleLabel.text = R.string.localizable.stakingValidatorStatusElected(
                preferredLanguages: locale.rLanguages
            )
        case .unelected:
            statusView.indicatorColor = R.color.colorLightGray()!
            statusView.titleLabel.text = R.string.localizable.stakingValidatorStatusUnelected(
                preferredLanguages: locale.rLanguages
            )
        }

        let statusContentView = GenericTitleValueView(titleView: titleLabel, valueView: statusView)
        let rowView = RowView(contentView: statusContentView, preferredHeight: 48.0)
        rowView.isUserInteractionEnabled = false

        stackView.addArrangedSubview(rowView)
        rowView.snp.makeConstraints { make in
            make.width.equalTo(self)
        }

        if viewModel.slashed {
            rowView.borderView.borderType = .none

            let text = R.string.localizable.stakingValidatorSlashedDesc(
                preferredLanguages: locale.rLanguages
            )

            return addHintView(for: text, icon: R.image.iconErrorFilled())
        } else {
            return rowView
        }
    }

    @discardableResult
    func addNominatorsView(_ exposure: ValidatorInfoViewModel.Exposure, locale: Locale) -> UIView {
        let nominatorsView = addTitleValueView(
            for: R.string.localizable.stakingValidatorNominators(preferredLanguages: locale.rLanguages),
            value: exposure.nominators
        )

        if let myNomination = exposure.myNomination, !myNomination.isRewarded {
            nominatorsView.borderView.borderType = .none

            return addHintView(
                for: R.string.localizable.stakingYourOversubscribedMessage(
                    preferredLanguages: locale.rLanguages
                ),
                icon: R.image.iconWarning()
            )
        } else {
            return nominatorsView
        }
    }

    func addHintView(for title: String, icon: UIImage?) -> UIView {
        let borderView = factory.createBorderedContainerView()

        let hintView = factory.createHintView()
        hintView.iconView.image = icon
        hintView.titleLabel.text = title

        borderView.addSubview(hintView)
        hintView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().inset(9)
        }

        borderView.borderType = .bottom

        stackView.addArrangedSubview(borderView)
        borderView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        return borderView
    }

    @discardableResult
    func addTotalStakeView(
        _ exposure: ValidatorInfoViewModel.Exposure,
        locale: Locale
    ) -> UIControl {
        let titleView = factory.createInfoIndicatingView()
        titleView.title = R.string.localizable.stakingValidatorTotalStake(
            preferredLanguages: locale.rLanguages
        )

        let rowContentView = GenericTitleValueView<ImageWithTitleView, MultiValueView>(titleView: titleView)

        rowContentView.valueView.bind(
            topValue: exposure.totalStake.amount,
            bottomValue: exposure.totalStake.price
        )

        let rowView = RowView(contentView: rowContentView, preferredHeight: 48.0)

        stackView.addArrangedSubview(rowView)
        rowView.snp.makeConstraints { make in
            make.width.equalTo(self)
        }

        return rowView
    }

    @discardableResult
    func addTitleValueView(for title: String, value: String) -> TitleValueView {
        let view = factory.createTitleValueView()
        view.borderView.strokeWidth = 1 / UIScreen.main.scale

        stackView.addArrangedSubview(view)
        view.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48)
        }

        view.titleLabel.text = title
        view.valueLabel.text = value

        return view
    }

    @discardableResult
    func addLinkView(for title: String, url: String) -> UIControl {
        let titleLabel = UILabel()
        titleLabel.textColor = R.color.colorLightGray()
        titleLabel.font = .p1Paragraph
        titleLabel.text = title

        let valueView = ImageWithTitleView()
        valueView.titleColor = R.color.colorWhite()
        valueView.titleFont = .p1Paragraph
        valueView.iconImage = R.image.iconAboutArrow()
        valueView.iconTintColor = R.color.colorWhite()
        valueView.spacingBetweenLabelAndIcon = 8.0
        valueView.layoutType = .horizontalLabelFirst
        valueView.title = url

        let rowContentView = GenericTitleValueView(titleView: titleLabel, valueView: valueView)
        let rowView = RowView(contentView: rowContentView, preferredHeight: 48.0)

        stackView.addArrangedSubview(rowView)
        rowView.snp.makeConstraints { make in
            make.width.equalTo(self)
        }

        return rowView
    }

    // MARK: Private

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }
    }
}
