import UIKit
import SoraUI
import SoraFoundation

final class RewardAnalyticsWidgetView: BackgroundedContentControl {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let arrowView: UIView = UIImageView(image: R.image.iconSmallArrow())

    private let rewardsLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let periodLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()?.withAlphaComponent(0.64)
        return label
    }()

    private let tokenAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let usdAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorGray()
        return label
    }()

    let barChartView: FWChartViewProtocol = FWBarChartView()

    private var skeletonView: SkrullableView?

    private var localizableViewModel: LocalizableResource<RewardAnalyticsWidgetViewModel>?

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

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: 221
        )
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .stakingAnalyticsTitle(preferredLanguages: locale.rLanguages)
        rewardsLabel.text = R.string.localizable
            .stakingAnalyticsReceivedRewards(preferredLanguages: locale.rLanguages)
        applyViewModel()
    }

    private func setupLayout() {
        let shapeView = ShapeView()
        shapeView.isUserInteractionEnabled = false
        shapeView.fillColor = .clear
        shapeView.highlightedFillColor = R.color.colorAccent()!

        backgroundView = shapeView

        let containerView = UIView()
        containerView.isUserInteractionEnabled = false

        let separatorView = UIView.createSeparator(color: R.color.colorWhite()?.withAlphaComponent(0.24))

        let stackView: UIView = .vStack(
            spacing: 8,
            [
                .hStack([titleLabel, UIView(), arrowView]),
                separatorView,
                .vStack([
                    .hStack([rewardsLabel, UIView(), tokenAmountLabel]),
                    .hStack([periodLabel, UIView(), usdAmountLabel])
                ]),
                barChartView
            ]
        )

        let blurView = TriangularedBlurView()
        blurView.isUserInteractionEnabled = false
        containerView.addSubview(blurView)
        blurView.snp.makeConstraints { $0.edges.equalToSuperview() }

        containerView.addSubview(stackView)
        stackView.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIConstants.horizontalInset) }

        arrowView.snp.makeConstraints { $0.size.equalTo(24) }
        separatorView.snp.makeConstraints { $0.height.equalTo(UIConstants.separatorHeight) }
        barChartView.snp.makeConstraints { $0.height.equalTo(100) }

        contentView = containerView
    }

    func bind(viewModel: LocalizableResource<RewardAnalyticsWidgetViewModel>?) {
        localizableViewModel = viewModel
        if viewModel != nil {
            stopLoadingIfNeeded()

            applyViewModel()
        } else {
            startLoading()
        }
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel else {
            return
        }

        let localizedViewModel = viewModel.value(for: locale)

        barChartView.setChartData(localizedViewModel.chartData)
        usdAmountLabel.text = localizedViewModel.summary.usdAmount
        tokenAmountLabel.text = localizedViewModel.summary.tokenAmount
        periodLabel.text = localizedViewModel.summary.title
    }
}

// MARK: - Skeleton

extension RewardAnalyticsWidgetView {
    func startLoading() {
        guard skeletonView == nil else {
            return
        }

        periodLabel.alpha = 0.0
        tokenAmountLabel.alpha = 0.0
        usdAmountLabel.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        periodLabel.alpha = 1.0
        tokenAmountLabel.alpha = 1.0
        usdAmountLabel.alpha = 1.0
    }

    private func setupSkeleton() {
        guard let size = contentView?.bounds.size, size.height > 0 else { return }

        let skeletonView = Skrull(
            size: size,
            decorations: [],
            skeletons: createSkeletons(for: size)
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        skeletonView.frame = CGRect(origin: .zero, size: size)
        skeletonView.autoresizingMask = []
        insertSubview(skeletonView, aboveSubview: contentView!)

        self.skeletonView = skeletonView

        skeletonView.startSkrulling()
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let bigRowSize = CGSize(width: 100.0, height: 18.0)
        let smallRowSize = CGSize(width: 70.0, height: 15.0)

        return [
            createSkeletoRow(
                inPlaceOf: tokenAmountLabel,
                in: spaceSize,
                size: bigRowSize
            ),
            createSkeletoRow(
                inPlaceOf: usdAmountLabel,
                in: spaceSize,
                size: smallRowSize
            ),
            createSkeletoRow(
                inPlaceOf: periodLabel,
                in: spaceSize,
                size: smallRowSize
            )
        ]
    }

    private func createSkeletoRow(
        inPlaceOf targetView: UIView,
        in spaceSize: CGSize,
        size: CGSize
    ) -> SingleSkeleton {
        let targetFrame = targetView.convert(targetView.bounds, to: self)

        let position = CGPoint(
            x: targetFrame.minX + size.width / 2.0,
            y: targetFrame.midY
        )

        let mappedSize = CGSize(
            width: spaceSize.skrullMapX(size.width),
            height: spaceSize.skrullMapY(size.height)
        )

        return SingleSkeleton(position: spaceSize.skrullMap(point: position), size: mappedSize).round()
    }
}

extension RewardAnalyticsWidgetView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        guard let skeletonView = skeletonView else {
            return
        }

        if skeletonView.frame.size != contentView!.frame.size {
            skeletonView.removeFromSuperview()
            self.skeletonView = nil
            setupSkeleton()
        }
    }
}
