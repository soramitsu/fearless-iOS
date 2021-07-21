import UIKit
import SoraUI

final class ValidatorInfoViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

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

    func bind(viewModel: ValidatorInfoViewModel, locale: Locale) {
        clearStackView()

        let accountView = addAccountView(for: viewModel.account)
        contentView.stackView.setCustomSpacing(25.0, after: accountView)

        addSectionHeader(with: R.string.localizable.stakingTitle(preferredLanguages: locale.rLanguages))
        addStakingStatusView(viewModel.staking, locale: locale)

        if case let .elected(exposure) = viewModel.staking.status {
            addNominatorsView(exposure, locale: locale)
            addTotalStakeView(exposure, locale: locale)
            addTitleValueView(
                for: "Estimated reward",
                value: exposure.estimatedReward
            )
        }

        if let identityItems = viewModel.identity, !identityItems.isEmpty {
            contentView.stackView.arrangedSubviews.last.map { lastView in
                contentView.stackView.setCustomSpacing(25.0, after: lastView)
            }

            addSectionHeader(
                with: R.string.localizable.identityTitle(preferredLanguages: locale.rLanguages)
            )

            identityItems.forEach { item in
                switch item.value {
                case let .link(url):
                    addLinkView(for: item.title, url: url)
                case let .text(text):
                    addTitleValueView(for: item.title, value: text)
                case let .email(email):
                    addLinkView(for: item.title, url: email)
                }
            }
        }
    }

    private func clearStackView() {
        let arrangedSubviews = contentView.stackView.arrangedSubviews

        arrangedSubviews.forEach {
            contentView.stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    @discardableResult
    private func addAccountView(for viewModel: AccountInfoViewModel) -> UIView {
        let accountView = factory.createAccountView(for: .options, filled: false)
        accountView.iconRadius = UIConstants.normalAddressIconSize.height / 2.0
        accountView.addTarget(self, action: #selector(actionOnAccount), for: .touchUpInside)

        contentView.stackView.addArrangedSubview(accountView)
        accountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52)
        }

        accountView.iconImage = viewModel.icon

        accountView.titleLabel.textColor = R.color.colorWhite()!
        accountView.titleLabel.font = .p1Paragraph

        if viewModel.name.isEmpty {
            accountView.layout = .singleTitle
            accountView.title = viewModel.address
            accountView.titleLabel.lineBreakMode = .byTruncatingMiddle
        } else {
            accountView.layout = .largeIconTitleSubtitle
            accountView.subtitleLabel?.textColor = R.color.colorLightGray()!
            accountView.subtitleLabel?.font = .p2Paragraph
            accountView.title = viewModel.name
            accountView.subtitle = viewModel.address
            accountView.titleLabel.lineBreakMode = .byTruncatingTail
            accountView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle
        }

        return accountView
    }

    @discardableResult
    private func addSectionHeader(with title: String) -> UIView {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h4Title

        contentView.stackView.addArrangedSubview(label)
        label.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        label.text = title

        return label
    }

    @discardableResult
    private func addStakingStatusView(
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
            statusView.titleLabel.text = "Elected"
        case .unelected:
            statusView.indicatorColor = R.color.colorLightGray()!
            statusView.titleLabel.text = "Not elected"
        }

        let statusContentView = GenericTitleValueView(titleView: titleLabel, valueView: statusView)
        let rowView = RowView(contentView: statusContentView, preferredHeight: 48.0)
        rowView.isUserInteractionEnabled = false

        contentView.stackView.addArrangedSubview(rowView)
        rowView.snp.makeConstraints { make in
            make.width.equalTo(self)
        }

        if viewModel.slashed {
            rowView.borderView.borderType = .none

            let text = "Validator is slashed for misbehaves (e.g. goes offline, attacks the network, or runs modified software) in the network."

            return addHintView(for: text, icon: R.image.iconErrorFilled())
        } else {
            return rowView
        }
    }

    @discardableResult
    private func addNominatorsView(_ exposure: ValidatorInfoViewModel.Exposure, locale: Locale) -> UIView {
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

    private func addHintView(for title: String, icon: UIImage?) -> UIView {
        let borderView = factory.createBorderedContainerView()

        let hintView = factory.createHintView()
        hintView.iconView.image = icon
        hintView.titleLabel.text = title

        borderView.addSubview(hintView)
        hintView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(9)
        }

        borderView.borderType = .bottom

        contentView.stackView.addArrangedSubview(borderView)
        borderView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        return borderView
    }

    @discardableResult
    private func addTotalStakeView(_ exposure: ValidatorInfoViewModel.Exposure, locale: Locale) -> UIView {
        let titleView = factory.createInfoIndicatingView()
        titleView.title = R.string.localizable.stakingValidatorTotalStake(
            preferredLanguages: locale.rLanguages
        )

        let rowContentView = GenericTitleValueView<ImageWithTitleView, MultiValueView>(titleView: titleView)

        rowContentView.valueView.valueTop.text = exposure.totalStake.amount
        rowContentView.valueView.valueBottom.text = exposure.totalStake.price

        let rowView = RowView(contentView: rowContentView, preferredHeight: 48.0)

        rowView.addTarget(self, action: #selector(actionOnTotalStake), for: .touchUpInside)

        contentView.stackView.addArrangedSubview(rowView)
        rowView.snp.makeConstraints { make in
            make.width.equalTo(self)
        }

        return rowView
    }

    @discardableResult
    private func addTitleValueView(for title: String, value: String) -> TitleValueView {
        let view = factory.createTitleValueView()

        contentView.stackView.addArrangedSubview(view)
        view.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48)
        }

        view.titleLabel.text = title
        view.valueLabel.text = value

        return view
    }

    @discardableResult
    private func addLinkView(for title: String, url: String) -> UIView {
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

        rowView.addTarget(self, action: #selector(actionOnIdentityLink(_:)), for: .touchUpInside)

        contentView.stackView.addArrangedSubview(rowView)
        rowView.snp.makeConstraints { make in
            make.width.equalTo(self)
        }

        return rowView
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }
    }

    @objc private func actionOnAccount() {}

    @objc private func actionOnTotalStake() {}

    @objc private func actionOnIdentityLink(_: UIControl) {}
}
