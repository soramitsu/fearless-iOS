import UIKit
import SoraFoundation
import SSFModels
import Kingfisher

enum PortfolioStrings {
    static func text(_ key: String, locale: Locale) -> String {
        let languages = (locale.rLanguages ?? []) +
            [locale.identifier.replacingOccurrences(of: "_", with: "-"), locale.languageCode ?? ""]
        let bundle = languages.compactMap { language in
            Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
        }.first ?? .main
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

enum TokenPortfolioRow {
    case token(TokenGroupRowViewModel)
    case asset(AssetKey)
    case zeroChildren(groupId: String, count: Int)
}

/// A deterministic projection prevents table index paths from becoming network identities.
enum TokenPortfolioProjection {
    static func rows(
        _ groups: [TokenGroupRowViewModel],
        expanded: Set<String>,
        expandedZero: Set<String>
    ) -> [TokenPortfolioRow] {
        groups.flatMap { group -> [TokenPortfolioRow] in
            var rows: [TokenPortfolioRow] = [.token(group)]
            guard !group.model.isSingleNetwork, expanded.contains(group.model.id) else { return rows }
            rows += group.model.children.map { .asset($0.chainAsset.assetKey) }
            if !group.model.zeroChildren.isEmpty {
                rows.append(.zeroChildren(groupId: group.model.id, count: group.model.zeroChildrenCount))
                if expandedZero.contains(group.model.id) {
                    rows += group.model.zeroChildren.map { .asset($0.chainAsset.assetKey) }
                }
            }
            return rows
        }
    }
}

final class TokenGroupBalanceTableCell: SwipableTableViewCell {
    var onActivate: (() -> Void)?
    var onAction: ((SwipableCellButtonType) -> Void)?
    let symbolLabel = UILabel()
    let networksLabel = UILabel()
    let amountLabel = UILabel()
    let fiatLabel = UILabel()
    let pricingLabel = UILabel()
    private let iconView = UIImageView()
    private let chevron = UIImageView()
    private let labels = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        cloudView.backgroundColor = UIColor(named: "fwSurfaceRaised")
        cloudView.layer.cornerRadius = FWTokens.Radius.m
        labels.axis = .vertical
        labels.spacing = FWTokens.Spacing.s4
        let values = FWAppearance.portfolioListRestyled ? [fiatLabel, amountLabel] : [amountLabel, fiatLabel]
        for label in [symbolLabel, networksLabel] + values + [pricingLabel] {
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.adjustsFontForContentSizeCategory = true
            label.textColor = UIColor(named: "fwTextPrimary")
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            labels.addArrangedSubview(label)
        }
        symbolLabel.font = .h5Title
        amountLabel.font = .h5Title
        networksLabel.font = .p2Paragraph
        fiatLabel.font = .p2Paragraph
        pricingLabel.font = .p2Paragraph
        networksLabel.textColor = UIColor(named: "fwTextSecondary")
        pricingLabel.textColor = UIColor(named: "fwTextSecondary")
        iconView.contentMode = .scaleAspectFit
        chevron.tintColor = UIColor(named: "fwTextSecondary")
        cloudView.addSubview(iconView)
        cloudView.addSubview(labels)
        cloudView.addSubview(chevron)
        iconView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().inset(16)
            make.size.equalTo(32)
        }
        labels.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.top.bottom.equalToSuperview().inset(16)
            make.trailing.equalTo(chevron.snp.leading).offset(-8)
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(18)
            make.size.equalTo(14)
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.kf.cancelDownloadTask()
        iconView.image = nil
        onActivate = nil
        onAction = nil
        accessibilityCustomActions = nil
    }

    func bind(_ row: TokenGroupRowViewModel, expanded: Bool, locale: Locale) {
        updateTypography()
        let model = row.model
        symbolLabel.text = model.symbol
        networksLabel.text = model.isSingleNetwork ? model.children.first?.networkName : String(
            format: PortfolioStrings.text("portfolio.network_count", locale: locale),
            Set(model.allChildren.map { $0.chainAsset.chain.chainId }).count
        )
        amountLabel.text = row.amountText
        fiatLabel.text = row
            .fiatText ??
            (
                model.unpricedNetworkCount > 0 ? PortfolioStrings
                    .text("portfolio.price_unavailable", locale: locale) : nil
            )
        fiatLabel.isHidden = fiatLabel.text == nil
        pricingLabel.text = model.unpricedNetworkCount > 0 && row.fiatText != nil ? String(
            format: PortfolioStrings.text("portfolio.partial_value", locale: locale), model.unpricedNetworkCount
        ) : nil
        pricingLabel.isHidden = pricingLabel.text == nil
        iconView.kf.cancelDownloadTask()
        iconView.image = nil
        model.icon.map { RemoteImageViewModel(url: $0) }?
            .loadImage(on: iconView, targetSize: CGSize(width: 32, height: 32), animated: false)
        chevron
            .image = UIImage(
                systemName: model
                    .isSingleNetwork ? "chevron.right" : (expanded ? "chevron.up" : "chevron.down")
            )
        accessibilityLabel = [symbolLabel.text, networksLabel.text, amountLabel.text, fiatLabel.text, pricingLabel.text]
            .compactMap { $0 }.joined(separator: ", ")
        accessibilityValue = model.isSingleNetwork ? nil : PortfolioStrings.text(
            expanded ? "ux.expanded" : "ux.collapsed",
            locale: locale
        )
        configureActions(model: model, expanded: expanded, locale: locale)
    }

    private func configureActions(model: TokenGroupRowModel, expanded: Bool, locale: Locale) {
        leftMenuButtons = model.allChildren.contains(where: { $0.value.transferable > .zero })
            ? [SwipeCellButton.createSendButton(locale: locale), SwipeCellButton.createReceiveButton(locale: locale)]
            : [SwipeCellButton.createReceiveButton(locale: locale)]
        rightMenuButtons = [SwipeCellButton.createHideButton(locale: locale)]
        var actions: [UIAccessibilityCustomAction] = []
        if !model.isSingleNetwork {
            actions
                .append(UIAccessibilityCustomAction(
                    name: PortfolioStrings
                        .text(expanded ? "portfolio.collapse" : "portfolio.expand", locale: locale)
                ) { [weak self] _ in
                    self?.accessibilityActivate() ?? false
                })
        }
        for button in leftMenuButtons + rightMenuButtons {
            actions.append(UIAccessibilityCustomAction(name: button.title(for: .normal) ?? "") { [weak self] _ in
                guard let action = self?.onAction else { return false }
                action(button.type)
                return true
            })
        }
        accessibilityCustomActions = actions
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateTypography()
    }

    private func updateTypography() {
        guard FWAppearance.portfolioListRestyled else { return }
        symbolLabel.font = .fw(.titleS, compatibleWith: traitCollection)
        networksLabel.font = .fw(.bodyM, compatibleWith: traitCollection)
        amountLabel.font = .fw(.numberM, compatibleWith: traitCollection)
        fiatLabel.font = .fw(.numberL, compatibleWith: traitCollection)
        pricingLabel.font = .fw(.bodyS, compatibleWith: traitCollection)
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        labels.snp.remakeConstraints { make in
            make.bottom.equalToSuperview().inset(16)
            if stacked {
                make.leading.trailing.equalToSuperview().inset(16)
                make.top.equalTo(iconView.snp.bottom).offset(12)
            } else {
                make.leading.equalTo(iconView.snp.trailing).offset(12)
                make.top.equalToSuperview().inset(16)
                make.trailing.equalTo(chevron.snp.leading).offset(-8)
            }
        }
    }

    override func accessibilityActivate() -> Bool {
        guard let onActivate else { return false }
        onActivate()
        return true
    }
}
