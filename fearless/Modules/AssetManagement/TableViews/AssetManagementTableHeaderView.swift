import Foundation
import UIKit

final class AssetManagementTableHeaderView: UITableViewHeaderFooterView {
    let assetImageView = UIImageView()

    let symbolLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let countLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .h5Title
        return label
    }()

    let textContainer = AssetManagementHeaderTextView()

    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        return imageView
    }()

    let visibilityButton = UIButton(type: .custom)
    private let controls = UIStackView()
    var onToggleVisibility: (() -> Void)?
    var onToggleExpansion: (() -> Void)?

    var viewModel: AssetManagementTableSection?
    private var bindingId = UUID()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        backgroundView = UIView(frame: bounds)
        backgroundView?.backgroundColor = R.color.colorBlack19()

        visibilityButton.isHidden = true
        setupLayout()
        if #available(iOS 17.0, *) {
            registerForTraitChanges([
                UITraitPreferredContentSizeCategory.self,
                UITraitLegibilityWeight.self
            ]) { (header: AssetManagementTableHeaderView, _: UITraitCollection) in
                header.updateContentConstraints()
            }
        }
        textContainer.onActivate = { [weak self] in
            guard let action = self?.onToggleExpansion else { return false }
            action()
            return true
        }
        visibilityButton.addAction(UIAction { [weak self] _ in self?.onToggleVisibility?() }, for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) { return }
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory ||
            previousTraitCollection?.legibilityWeight != traitCollection.legibilityWeight {
            updateContentConstraints()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        bindingId = UUID()
        assetImageView.image = nil
        assetImageView.highlightedImage = nil
        viewModel?.assetImage?.cancel(on: assetImageView)
        viewModel = nil
        onToggleVisibility = nil
        onToggleExpansion = nil
        textContainer.accessibilityLabel = nil
        textContainer.accessibilityValue = nil
    }

    func bind(viewModel: AssetManagementTableSection, locale: Locale = .current) {
        self.viewModel?.assetImage?.cancel(on: assetImageView)
        bindingId = UUID()
        let binding = bindingId
        self.viewModel = viewModel
        assetImageView.image = nil
        assetImageView.highlightedImage = nil

        viewModel.assetImage?.loadImage(
            on: assetImageView,
            targetSize: CGSize(width: 32, height: 32),
            animated: true,
            cornerRadius: 16,
            completionHandler: { [weak self, viewModel] result in
                guard self?.bindingId == binding, let image = try? result.get() else {
                    return
                }
                self?.assetImageView.highlightedImage = image.image.monochrome()
                self?.assetImageView.isHighlighted = viewModel.isAllDisabled
            }
        )
        applyGroupState(viewModel, locale: locale)
        symbolLabel.text = viewModel.assetName
        countLabel.text = viewModel.assetCount
        imageView.image = viewModel.isExpanded ? R.image.iconArrowUp() : R.image.iconSmallArrowDown()
        updateContentConstraints()
    }

    // MARK: - Private methods

    private func applyGroupState(_ viewModel: AssetManagementTableSection, locale: Locale) {
        visibilityButton.isHidden = !viewModel.id.hasPrefix("group:")
        let isOn = viewModel.groupVisibility == .on
        let icon: String
        let valueKey: String
        switch viewModel.groupVisibility {
        case .on: icon = "checkmark.circle.fill"; valueKey = "manage_assets.shown"
        case .off: icon = "circle"; valueKey = "manage_assets.hidden"
        case .mixed: icon = "minus.circle.fill"; valueKey = "manage_assets.mixed"
        }
        visibilityButton.setImage(
            UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24)),
            for: .normal
        )
        visibilityButton.tintColor = viewModel.groupVisibility == .off ? R.color.colorStrokeGray() : R.color.colorPink()
        visibilityButton.accessibilityLabel = String(
            format: PortfolioStrings
                .text(isOn ? "manage_assets.hide_group" : "manage_assets.show_group", locale: locale),
            locale: locale,
            viewModel.assetName ?? ""
        )
        visibilityButton.accessibilityValue = PortfolioStrings.text(valueKey, locale: locale)
        visibilityButton.accessibilityTraits = isOn ? [.button, .selected] : [.button]
        textContainer.isAccessibilityElement = true
        textContainer.accessibilityTraits = [.button]
        textContainer.accessibilityLabel = [viewModel.assetName, viewModel.assetCount].compactMap { $0 }
            .joined(separator: " · ")
        textContainer.accessibilityValue = PortfolioStrings.text(
            viewModel.isExpanded ? "ux.expanded" : "ux.collapsed",
            locale: locale
        )
    }

    private func setupLayout() {
        [symbolLabel, countLabel].forEach { label in
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.adjustsFontForContentSizeCategory = true
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        textContainer.axis = .vertical
        textContainer.distribution = .fill
        textContainer.spacing = 2
        [
            assetImageView,
            textContainer,
            controls
        ].forEach { contentView.addSubview($0) }

        [
            symbolLabel,
            countLabel
        ].forEach { textContainer.addArrangedSubview($0) }

        assetImageView.snp.makeConstraints { make in
            make.centerY.equalTo(symbolLabel)
            make.leading.equalToSuperview().inset(16)
            make.size.equalTo(32)
        }

        controls.axis = .horizontal
        controls.alignment = .center
        controls.spacing = 8
        controls.addArrangedSubview(visibilityButton)
        controls.addArrangedSubview(imageView)
        visibilityButton.snp.makeConstraints { $0.width.equalTo(44).priority(999); $0.height.equalTo(44) }
        imageView.snp.makeConstraints { $0.size.equalTo(16) }
        updateContentConstraints()
    }

    private func updateContentConstraints() {
        if FWAppearance.assetManagementRestyled {
            symbolLabel.font = .fw(.titleS, compatibleWith: traitCollection)
            countLabel.font = .fw(.bodyM, compatibleWith: traitCollection)
        }
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        textContainer.snp.remakeConstraints { make in
            make.leading.equalTo(assetImageView.snp.trailing).offset(12)
            make.top.equalToSuperview().inset(8)
            make.height.greaterThanOrEqualTo(39)
            if stacked {
                make.trailing.equalToSuperview().inset(16)
            } else {
                make.bottom.equalToSuperview().inset(8)
            }
        }
        controls.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            if stacked {
                make.top.equalTo(textContainer.snp.bottom).offset(8)
                make.bottom.equalToSuperview().inset(8)
            } else {
                make.leading.equalTo(textContainer.snp.trailing).offset(12)
                make.centerY.equalToSuperview()
            }
        }
    }
}

final class AssetManagementHeaderTextView: UIStackView {
    var onActivate: (() -> Bool)?
    override func accessibilityActivate() -> Bool { onActivate?() ?? false }
}
