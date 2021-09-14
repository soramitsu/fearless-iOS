import UIKit
import SoraUI
import SoraFoundation

final class RewardAnalyticsWidgetView: UIView {
    private let backgroundView: UIView = TriangularedBlurView()

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

    private var labelsContainerView: UIView!

    private var skeletonView: SkrullableView?

    private var localizableViewModel: LocalizableResource<RewardAnalyticsWidgetViewModel>?

    let backgroundButton: TriangularedButton = {
        let button = TriangularedButton()
        button.triangularedView?.fillColor = .clear
        button.triangularedView?.highlightedFillColor = R.color.colorHighlightedPink()!
        button.triangularedView?.shadowOpacity = 0.0
        return button
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

    override func layoutSubviews() {
        super.layoutSubviews()

        if localizableViewModel == nil {
            stopLoading()
            startLoading()
        }
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .stakingAnalyticsTitle(preferredLanguages: locale.rLanguages)
        rewardsLabel.text = R.string.localizable
            .stakingAnalyticsReceivedRewards(preferredLanguages: locale.rLanguages)
        applyViewModel()
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(backgroundButton)
        backgroundButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let separatorView = UIView.createSeparator(color: R.color.colorWhite()?.withAlphaComponent(0.24))

        labelsContainerView = .vStack(
            spacing: 8,
            [
                .vStack([
                    .hStack([rewardsLabel, UIView(), tokenAmountLabel]),
                    .hStack([periodLabel, UIView(), usdAmountLabel])
                ])
            ]
        )

        let stackView: UIView = .vStack(
            spacing: 8,
            [
                .hStack([titleLabel, UIView(), arrowView]),
                separatorView,
                labelsContainerView,
                barChartView
            ]
        )

        addSubview(stackView)
        stackView.isUserInteractionEnabled = false
        stackView.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIConstants.horizontalInset) }

        arrowView.snp.makeConstraints { $0.size.equalTo(24) }
        separatorView.snp.makeConstraints { $0.height.equalTo(UIConstants.separatorHeight) }
        barChartView.snp.makeConstraints { $0.height.equalTo(100) }
    }

    func bind(viewModel: LocalizableResource<RewardAnalyticsWidgetViewModel>?) {
        localizableViewModel = viewModel
        if viewModel != nil {
            stopLoading()

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

        let chartDataWithoutAnimation = ChartData(
            amounts: localizedViewModel.chartData.amounts,
            xAxisValues: localizedViewModel.chartData.xAxisValues,
            bottomYValue: localizedViewModel.chartData.bottomYValue,
            averageAmountValue: localizedViewModel.chartData.averageAmountValue,
            averageAmountText: localizedViewModel.chartData.averageAmountText,
            animate: false
        )
        barChartView.setChartData(chartDataWithoutAnimation)
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

        labelsContainerView.alpha = 0
        barChartView.alpha = 0

        setupSkeleton()
    }

    func stopLoading() {
        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        labelsContainerView.alpha = 1
        barChartView.alpha = 1
    }

    func setupSkeleton() {
        let spaceSize = backgroundView.frame.size

        let skeletons = createSkeletons(for: spaceSize)

        let builder = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: skeletons
        )

        let currentSkeletonView: SkrullableView?

        if let skeletonView = skeletonView {
            currentSkeletonView = skeletonView
            builder.updateSkeletons(in: skeletonView)
        } else {
            let view = builder
                .fillSkeletonStart(R.color.colorSkeletonStart()!)
                .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
                .build()
            view.autoresizingMask = []
            view.isUserInteractionEnabled = false
            insertSubview(view, aboveSubview: backgroundView)

            currentSkeletonView = view
            skeletonView = view

            view.startSkrulling()
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let rowWidth = spaceSize.width - 32
        let labelsSize = CGSize(width: rowWidth, height: labelsContainerView.bounds.height)
        let chartSize = CGSize(width: rowWidth, height: barChartView.bounds.height)

        return [
            createSkeletonRow(
                inPlaceOf: labelsContainerView,
                in: spaceSize,
                size: labelsSize
            ),
            createSkeletonRow(
                inPlaceOf: barChartView,
                in: spaceSize,
                size: chartSize
            )
        ]
    }

    private func createSkeletonRow(
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

        return SingleSkeleton(position: spaceSize.skrullMap(point: position), size: mappedSize)
            .round(CGSize(width: 0.02, height: 0.02))
    }
}

extension RewardAnalyticsWidgetView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {}
}
