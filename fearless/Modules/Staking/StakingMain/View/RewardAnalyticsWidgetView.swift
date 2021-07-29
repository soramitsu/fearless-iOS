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

    let chartView = ChartView()

    private let payableIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorAccent()
        return view
    }()

    private let payableTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p3Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let receivedIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorGray()
        return view
    }()

    private let receivedTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p3Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

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
            height: 249
        )
    }

    private func applyLocalization() {
        titleLabel.text = "Reward analytics"
        payableTitleLabel.text = "Payable"
        receivedTitleLabel.text = "Received"
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
                .hStack(
                    alignment: .center,
                    [
                        periodLabel,
                        UIView(),
                        .vStack(
                            alignment: .trailing,
                            [tokenAmountLabel, usdAmountLabel]
                        )
                    ]
                ),
                chartView,
                .hStack(
                    alignment: .center,
                    spacing: 16,
                    [
                        .hStack(alignment: .center, spacing: 8, [payableIndicatorView, payableTitleLabel]),
                        .hStack(alignment: .center, spacing: 8, [receivedIndicatorView, receivedTitleLabel]),
                        UIView()
                    ]
                )
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
        chartView.snp.makeConstraints { $0.height.equalTo(100) }
        payableIndicatorView.snp.makeConstraints { $0.size.equalTo(8) }
        receivedIndicatorView.snp.makeConstraints { $0.size.equalTo(8) }

        contentView = containerView
    }

    func bind(viewModel: LocalizableResource<RewardAnalyticsWidgetViewModel>) {
        localizableViewModel = viewModel
        applyViewModel()
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel else {
            return
        }

        let localizedViewModel = viewModel.value(for: locale)

        chartView.setChartData(localizedViewModel.chartData)
        usdAmountLabel.text = localizedViewModel.summary.usdAmount
        tokenAmountLabel.text = localizedViewModel.summary.tokenAmount
        periodLabel.text = localizedViewModel.summary.title
    }
}
