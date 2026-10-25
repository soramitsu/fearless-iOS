import UIKit
import SoraUI

final class AssetManagementTableCell: UITableViewCell {
    let iconImageView = UIImageView()

    let symbolLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let chainNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .p2Paragraph
        return label
    }()

    let preferenceLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .p2Paragraph
        return label
    }()

    let balanceLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h5Title
        label.textAlignment = .right
        return label
    }()

    let fiatBalanceLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .p2Paragraph
        label.textAlignment = .right
        return label
    }()

    let switchView: UISwitch = {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorPink()
        switchView.isUserInteractionEnabled = false
        switchView.setContentCompressionResistancePriority(.required, for: .horizontal)
        switchView.setContentHuggingPriority(.required, for: .horizontal)
        return switchView
    }()

    let textContainer = UIFactory.default.createHorizontalStackView()
    let assetTextsContainer = UIFactory.default.createVerticalStackView()
    let balanceTextsContainer = UIFactory.default.createVerticalStackView()
    private var skeletonView: SkrullableView?
    private var loadingTargetFrames: [CGRect] = []

    private var viewModel: AssetManagementTableCellViewModel?
    private var bindingId = UUID()

    override func prepareForReuse() {
        super.prepareForReuse()
        if FWAppearance.assetManagementRestyled { stopLoadingIfNeeded() }
        bindingId = UUID()
        preferenceLabel.text = nil
        accessibilityLabel = nil
        accessibilityValue = nil
        accessibilityCustomActions = nil
        iconImageView.image = nil
        iconImageView.highlightedImage = nil
        viewModel?.assetImage?.cancel(on: iconImageView)
        viewModel = nil
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupLayout()
        updateTextLayout()
        if #available(iOS 17.0, *) {
            registerForTraitChanges(
                [UITraitPreferredContentSizeCategory.self, UITraitLegibilityWeight.self]
            ) { (cell: AssetManagementTableCell, _: UITraitCollection) in
                cell.updateTextLayout()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) { return }
        updateTextLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if FWAppearance.assetManagementRestyled, viewModel?.isLoadingBalance == true {
            updateLoadingSkeleton()
        }
    }

    func bind(viewModel: AssetManagementTableCellViewModel) {
        self.viewModel?.assetImage?.cancel(on: iconImageView)
        bindingId = UUID()
        let binding = bindingId
        self.viewModel = viewModel
        iconImageView.image = nil
        iconImageView.highlightedImage = nil
        viewModel.assetImage?.loadImage(
            on: iconImageView,
            targetSize: CGSize(width: 32, height: 32),
            animated: true,
            cornerRadius: 16,
            completionHandler: { [weak self, viewModel] result in
                guard self?.bindingId == binding, let image = try? result.get() else {
                    return
                }
                self?.iconImageView.highlightedImage = image.image.monochrome()
                self?.iconImageView.isHighlighted = viewModel.hidden
            }
        )
        symbolLabel.text = viewModel.assetName
        chainNameLabel.text = viewModel.chainName
        preferenceLabel.text = viewModel.preferenceCaption
        isAccessibilityElement = true
        accessibilityLabel = viewModel.assetName + " · " + viewModel.chainName
        accessibilityValue = viewModel.preferenceCaption
        accessibilityTraits = viewModel.hidden ? [.button] : [.button, .selected]
        balanceLabel.text = viewModel.balance.amount
        fiatBalanceLabel.text = viewModel.balance.price
        switchView.isOn = !viewModel.hidden

        updateTextLayout()
        applyStyle(isOn: !viewModel.hidden, hasGroup: viewModel.hasGroup)
        if viewModel.isLoadingBalance {
            startLoadingIfNeeded()
        } else {
            stopLoadingIfNeeded()
        }
    }

    private func startLoadingIfNeeded() {
        if FWAppearance.assetManagementRestyled {
            balanceLabel.alpha = 0
            fiatBalanceLabel.alpha = 0
            setNeedsLayout()
            return
        }
        guard skeletonView == nil else {
            return
        }

        balanceLabel.alpha = 0.0
        fiatBalanceLabel.alpha = 0.0

        setupSkeleton()
    }

    private func stopLoadingIfNeeded() {
        loadingTargetFrames = []
        balanceLabel.alpha = 1.0
        fiatBalanceLabel.alpha = 1.0

        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil
    }

    private func setupSkeleton() {
        setNeedsLayout()
        layoutIfNeeded()
        let spaceSize = contentView.frame.size

        guard spaceSize != .zero else {
            self.skeletonView = Skrull(size: .zero, decorations: [], skeletons: []).build()
            return
        }

        let skeletonView = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        self.skeletonView = skeletonView

        skeletonView.frame = CGRect(origin: .zero, size: spaceSize)
        skeletonView.autoresizingMask = []
        insertSubview(skeletonView, aboveSubview: contentView)

        skeletonView.startSkrulling()
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let balanceSize = CGSize(width: 72, height: 14)
        let priceSize = CGSize(width: 52, height: 10)

        return [
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: textContainer.frame.maxX - 72, y: textContainer.frame.midY - 7),
                size: balanceSize
            ),
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: textContainer.frame.maxX - 52, y: textContainer.frame.midY + 10),
                size: priceSize
            )
        ]
    }

    private func applyStyle(isOn: Bool, hasGroup: Bool) {
        if hasGroup {
            contentView.backgroundColor = R.color.colorBlack02()
        } else {
            contentView.backgroundColor = R.color.colorBlack19()
        }

        if isOn {
            symbolLabel.textColor = R.color.colorWhite()
        } else {
            symbolLabel.textColor = R.color.colorStrokeGray()
        }
        // Hidden holdings must remain inspectable in Manage.
        balanceTextsContainer.isHidden = false
    }

    private func setupLayout() {
        [symbolLabel, chainNameLabel, preferenceLabel, balanceLabel, fiatBalanceLabel].forEach { label in
            label.numberOfLines = 0
            label.lineBreakMode = .byCharWrapping
            label.adjustsFontForContentSizeCategory = true
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        [symbolLabel, chainNameLabel, preferenceLabel].forEach { $0.lineBreakMode = .byWordWrapping }
        [textContainer, assetTextsContainer, balanceTextsContainer].forEach { stack in
            stack.distribution = .fill
            stack.alignment = .fill
            stack.spacing = 2
        }
        [
            symbolLabel,
            chainNameLabel,
            preferenceLabel
        ].forEach { assetTextsContainer.addArrangedSubview($0) }

        [
            balanceLabel,
            fiatBalanceLabel
        ].forEach { balanceTextsContainer.addArrangedSubview($0) }

        [
            assetTextsContainer,
            balanceTextsContainer
        ].forEach { textContainer.addArrangedSubview($0) }

        [
            iconImageView,
            textContainer,
            switchView
        ].forEach { contentView.addSubview($0) }

        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(32)
        }

        textContainer.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.top.bottom.equalToSuperview().inset(8)
            make.height.greaterThanOrEqualTo(39)
        }

        switchView.snp.makeConstraints { make in
            make.leading.equalTo(textContainer.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }
    }
}

private extension AssetManagementTableCell {
    func updateTextLayout() {
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        textContainer.axis = stacked ? .vertical : .horizontal
        balanceLabel.textAlignment = stacked ? .left : .right
        fiatBalanceLabel.textAlignment = stacked ? .left : .right
        guard FWAppearance.assetManagementRestyled else { return }
        symbolLabel.font = .fw(.titleS, compatibleWith: traitCollection)
        chainNameLabel.font = .fw(.bodyS, compatibleWith: traitCollection)
        preferenceLabel.font = .fw(.bodyS, compatibleWith: traitCollection)
        balanceLabel.font = .fw(.numberL, compatibleWith: traitCollection)
        fiatBalanceLabel.font = .fw(.numberM, compatibleWith: traitCollection)
        iconImageView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.size.equalTo(32)
            if stacked {
                make.top.equalToSuperview().inset(12)
            } else {
                make.centerY.equalToSuperview()
            }
        }
        textContainer.snp.remakeConstraints { make in
            make.height.greaterThanOrEqualTo(39)
            if stacked {
                make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
                make.top.equalTo(iconImageView.snp.bottom).offset(12)
                make.bottom.equalToSuperview().inset(12)
            } else {
                make.leading.equalTo(iconImageView.snp.trailing).offset(12)
                make.top.bottom.equalToSuperview().inset(8)
            }
        }
        switchView.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            if stacked {
                make.centerY.equalTo(iconImageView)
            } else {
                make.leading.equalTo(textContainer.snp.trailing).offset(12)
                make.centerY.equalToSuperview()
            }
        }
        setNeedsLayout()
    }

    func updateLoadingSkeleton() {
        contentView.layoutIfNeeded()
        textContainer.layoutIfNeeded()
        balanceTextsContainer.layoutIfNeeded()
        let size = contentView.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let labels = [balanceLabel, fiatBalanceLabel]
        let frames = labels.map { $0.convert($0.bounds, to: contentView) }
        guard skeletonView?.bounds.size != size || frames != loadingTargetFrames else { return }
        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let preferred = [CGSize(width: 72, height: 14), CGSize(width: 52, height: 10)]
        let rows = zip(frames, preferred).map { frame, preferredSize -> Skeletonable in
            let bar = CGSize(
                width: min(preferredSize.width, size.width),
                height: min(preferredSize.height, size.height)
            )
            let positionX = stacked ? frame.minX : frame.maxX - bar.width
            let position = CGPoint(
                x: max(0, min(positionX, size.width - bar.width)),
                y: max(bar.height / 2, min(frame.midY, size.height - bar.height / 2))
            )
            return SingleSkeleton.createRow(spaceSize: size, position: position, size: bar)
        }
        let skeleton = Skrull(size: size, decorations: [], skeletons: rows)
            .fillSkeletonStart(R.color.colorSkeletonStart()!)
            .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
            .build()
        skeleton.frame = CGRect(origin: .zero, size: size)
        skeleton.isUserInteractionEnabled = false
        contentView.addSubview(skeleton)
        skeletonView = skeleton
        loadingTargetFrames = frames
        skeleton.startSkrulling()
    }
}
