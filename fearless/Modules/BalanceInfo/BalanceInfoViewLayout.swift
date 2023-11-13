import UIKit
import SoraUI

final class BalanceInfoViewLayout: UIView {
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textAlignment = .center
        return label
    }()

    private let balanceContainerView = UIFactory.default.createHorizontalStackView(spacing: UIConstants.defaultOffset)

    private let balanceLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private var skeletonView: SkrullableView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: BalanceInfoViewModel?) {
        priceLabel.attributedText = viewModel?.dayChangeAttributedString
        balanceLabel.text = viewModel?.balanceString

        balanceLabel.layoutIfNeeded()
        priceLabel.layoutIfNeeded()

        if viewModel == nil {
            startLoadingIfNeeded()
        } else {
            stopLoadingIfNeeded()
        }
    }

    private func setupLayout() {
        balanceContainerView.addArrangedSubview(balanceLabel)

        let vStackView = UIFactory.default.createVerticalStackView(spacing: 2)
        vStackView.alignment = .fill
        addSubview(vStackView)
        vStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        vStackView.addArrangedSubview(priceLabel)
        vStackView.addArrangedSubview(balanceContainerView)

        balanceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        priceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}

extension BalanceInfoViewLayout: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.stopSkrulling()
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        guard let skeletonView = skeletonView else {
            return
        }

        if skeletonView.frame.size != frame.size {
            skeletonView.removeFromSuperview()
            self.skeletonView = nil
            setupSkeleton()
        }
    }

    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        balanceLabel.alpha = 0.0
        priceLabel.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        balanceLabel.alpha = 1.0
        priceLabel.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = frame.size

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
        insertSubview(skeletonView, aboveSubview: self)

        skeletonView.startSkrulling()
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let defaultBigWidth = 72.0
        let defaultHeight = 16.0
        let smallHeight = 10.0

        let titleWidth = balanceLabel.text?.widthOfString(usingFont: balanceLabel.font)
        let incomeWidth = priceLabel.text?.widthOfString(usingFont: priceLabel.font)

        let titleSize = CGSize(width: titleWidth ?? defaultBigWidth, height: defaultHeight)
        let incomeSize = CGSize(width: incomeWidth ?? defaultBigWidth, height: smallHeight)

        return [
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: UIConstants.offset12 + UIConstants.normalAddressIconSize.width + UIConstants.hugeOffset, y: spaceSize.height / 2),
                size: titleSize
            ),
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: UIConstants.offset12 + UIConstants.normalAddressIconSize.width + UIConstants.hugeOffset, y: spaceSize.height / 2 + defaultHeight / 2 + UIConstants.offset12),
                size: incomeSize
            )
        ]
    }
}
