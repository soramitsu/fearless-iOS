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
        return switchView
    }()

    let textContainer = UIFactory.default.createHorizontalStackView()
    let assetTextsContainer = UIFactory.default.createVerticalStackView()
    let balanceTextsContainer = UIFactory.default.createVerticalStackView()
    private var skeletonView: SkrullableView?

    private var viewModel: AssetManagementTableCellViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = nil
        iconImageView.highlightedImage = nil
        viewModel?.assetImage?.cancel(on: iconImageView)
        viewModel = nil
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: AssetManagementTableCellViewModel) {
        self.viewModel = viewModel
        viewModel.assetImage?.loadImage(
            on: iconImageView,
            targetSize: CGSize(width: 32, height: 32),
            animated: true,
            cornerRadius: 16,
            completionHandler: { [weak self, viewModel] result in
                guard let image = try? result.get() else {
                    return
                }
                self?.iconImageView.highlightedImage = image.image.monochrome()
                self?.iconImageView.isHighlighted = viewModel.hidden
            }
        )
        symbolLabel.text = viewModel.assetName
        chainNameLabel.text = viewModel.chainName
        balanceLabel.text = viewModel.balance.amount
        fiatBalanceLabel.text = viewModel.balance.price
        switchView.isOn = !viewModel.hidden

        applyStyle(isOn: !viewModel.hidden, hasGroup: viewModel.hasGroup)
        viewModel.isLoadingBalance ? startLoadingIfNeeded() : stopLoadingIfNeeded()
    }

    private func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        balanceLabel.alpha = 0.0
        fiatBalanceLabel.alpha = 0.0

        setupSkeleton()
    }

    private func stopLoadingIfNeeded() {
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
        balanceTextsContainer.isHidden = !isOn
    }

    private func setupLayout() {
        [
            symbolLabel,
            chainNameLabel
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
            make.centerY.equalToSuperview()
        }

        switchView.set(width: 36, height: 21)
        switchView.snp.makeConstraints { make in
            make.leading.equalTo(textContainer.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }
    }
}
