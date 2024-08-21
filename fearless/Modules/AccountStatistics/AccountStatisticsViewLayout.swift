import UIKit
import Cosmos

final class AccountStatisticsViewLayout: UIView {
    let topBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.present)
        return bar
    }()

    let scrollView = UIScrollView()
    let backgroundView = UIView()

    let ratingView: CosmosView = {
        var settings = CosmosSettings()
        settings.starSize = 30
        settings.fillMode = .precise
        settings.updateOnTouch = false
        let cosmosView = CosmosView(settings: settings)
        cosmosView.rating = 5
        return cosmosView
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title
        label.textColor = .white
        return label
    }()

    let addressView = CopyableLabelView()

    let contentBackgroundView = UIView()
    let statsBackgroundView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.shadowColor = .clear
        view.strokeColor = R.color.colorWhite8()!
        view.highlightedStrokeColor = R.color.colorWhite8()!
        view.strokeWidth = 0.5
        view.layer.shadowOpacity = 0
        return view
    }()

    let stackView = UIFactory.default.createVerticalStackView(spacing: 8)

    let updatedView = makeRowView()
    let nativeBalanceUsdView = makeRowView()
    let holdTokensUsdView = makeRowView()
    let walletAgeView = makeRowView()
    let totalTransactionsView = makeRowView()
    let rejectedTransactionsView = makeRowView()
    let avgTransactionTimeView = makeRowView()
    let maxTransactionTimeView = makeRowView()
    let minTransactionTimeView = makeRowView()

    let closeButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubviews()
        setupConstraints()

        contentBackgroundView.backgroundColor = R.color.colorBlack19()
        backgroundColor = R.color.colorBlack19()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupEmptyState() {
        stackView.isHidden = true
        addressView.isHidden = true
        ratingView.rating = 0
        ratingView.settings.emptyBorderColor = R.color.colorLightGray()!
    }

    func bind(viewModel: AccountStatisticsViewModel?) {
        if let rating = viewModel?.rating {
            ratingView.rating = rating
        }

        if let address = viewModel?.addressViewText {
            addressView.bind(title: address)
        }

        updatedView.isHidden = viewModel != nil && viewModel?.updatedLabelText == nil
        nativeBalanceUsdView.isHidden = viewModel != nil && viewModel?.nativeBalanceUsdLabelText == nil
        holdTokensUsdView.isHidden = viewModel != nil && viewModel?.holdTokensUsdLabelText == nil
        walletAgeView.isHidden = viewModel != nil && viewModel?.walletAgeLabelText == nil
        totalTransactionsView.isHidden = viewModel != nil && viewModel?.totalTransactionsLabelText == nil
        rejectedTransactionsView.isHidden = viewModel != nil && viewModel?.rejectedTransactionsLabelText == nil
        avgTransactionTimeView.isHidden = viewModel != nil && viewModel?.avgTransactionTimeLabelText == nil
        maxTransactionTimeView.isHidden = viewModel != nil && viewModel?.maxTransactionTimeLabelText == nil
        minTransactionTimeView.isHidden = viewModel != nil && viewModel?.minTransactionTimeLabelText == nil

        scoreLabel.text = viewModel?.scoreLabelText
        updatedView.valueLabel.updateTextWithLoading(viewModel?.updatedLabelText)
        nativeBalanceUsdView.valueLabel.updateTextWithLoading(viewModel?.nativeBalanceUsdLabelText)
        holdTokensUsdView.valueLabel.updateTextWithLoading(viewModel?.holdTokensUsdLabelText)
        walletAgeView.valueLabel.updateTextWithLoading(viewModel?.walletAgeLabelText)
        totalTransactionsView.valueLabel.updateTextWithLoading(viewModel?.totalTransactionsLabelText)
        rejectedTransactionsView.valueLabel.updateTextWithLoading(viewModel?.rejectedTransactionsLabelText)
        avgTransactionTimeView.valueLabel.updateTextWithLoading(viewModel?.avgTransactionTimeLabelText)
        maxTransactionTimeView.valueLabel.updateTextWithLoading(viewModel?.maxTransactionTimeLabelText)
        minTransactionTimeView.valueLabel.updateTextWithLoading(viewModel?.minTransactionTimeLabelText)

        if let color = viewModel?.rate.color {
            ratingView.settings.emptyBorderColor = color
            ratingView.settings.filledColor = color
            ratingView.settings.filledBorderColor = color
        }
    }

    // MARK: - Private methods

    private func addSubviews() {
        addSubview(topBar)
        addSubview(scrollView)
        addSubview(closeButton)

        scrollView.addSubview(contentBackgroundView)
        contentBackgroundView.addSubview(ratingView)
        contentBackgroundView.addSubview(descriptionLabel)
        contentBackgroundView.addSubview(scoreLabel)
        contentBackgroundView.addSubview(addressView)
        contentBackgroundView.addSubview(statsBackgroundView)
        statsBackgroundView.addSubview(stackView)

        [updatedView,
         nativeBalanceUsdView,
         holdTokensUsdView,
         walletAgeView,
         totalTransactionsView,
         rejectedTransactionsView,
         avgTransactionTimeView,
         maxTransactionTimeView,
         minTransactionTimeView].forEach {
            stackView.addArrangedSubview($0)
            setupRowViewConstraints($0)
        }
    }

    private func setupConstraints() {
        topBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(56)
        }

        scrollView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.top.equalTo(topBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(closeButton.snp.top).offset(-16)
        }

        closeButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(48)
            make.bottom.equalTo(safeAreaInsets).inset(16)
        }

        contentBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(self)
        }

        ratingView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(30)
            make.top.equalToSuperview()
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(ratingView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        scoreLabel.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }

        addressView.snp.makeConstraints { make in
            make.top.equalTo(scoreLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }

        statsBackgroundView.snp.makeConstraints { make in
            make.top.equalTo(addressView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
        }

        stackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func applyLocalization() {
        topBar.setTitle(R.string.localizable.accountStatsTitle(preferredLanguages: locale.rLanguages))
        descriptionLabel.text = R.string.localizable.accountStatsDescriptionText(preferredLanguages: locale.rLanguages)
        updatedView.titleLabel.text = R.string.localizable.accountStatsUpdatedTitle(preferredLanguages: locale.rLanguages)
        nativeBalanceUsdView.titleLabel.text = R.string.localizable.accountStatsNativeBalanceUsdTitle(preferredLanguages: locale.rLanguages)
        holdTokensUsdView.titleLabel.text = R.string.localizable.accountStatsHoldTokensUsdTitle(preferredLanguages: locale.rLanguages)
        walletAgeView.titleLabel.text = R.string.localizable.accountStatsWalletAgeTitle(preferredLanguages: locale.rLanguages)
        totalTransactionsView.titleLabel.text = R.string.localizable.accountStatsTotalTransactionsTitle(preferredLanguages: locale.rLanguages)
        rejectedTransactionsView.titleLabel.text = R.string.localizable.accountStatsRejectedTransactionsTitle(preferredLanguages: locale.rLanguages)
        avgTransactionTimeView.titleLabel.text = R.string.localizable.accountStatsAvgTransactionTimeTitle(preferredLanguages: locale.rLanguages)
        maxTransactionTimeView.titleLabel.text = R.string.localizable.accountStatsMaxTransactionTimeTitle(preferredLanguages: locale.rLanguages)
        minTransactionTimeView.titleLabel.text = R.string.localizable.accountStatsMinTransactionsTimeTitle(preferredLanguages: locale.rLanguages)
        closeButton.imageWithTitleView?.title = R.string.localizable.commonClose(preferredLanguages: locale.rLanguages)
    }

    private func setupRowViewConstraints(_ view: TitleValueView) {
        view.snp.makeConstraints { make in
            make.height.equalTo(48)
            make.leading.trailing.equalToSuperview()
        }

        view.valueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
        }
    }

    private static func makeRowView() -> TitleValueView {
        let view = TitleValueView(skeletonSize: CGSize(width: 50, height: 12))
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorWhite50()
        view.titleLabel.numberOfLines = 0
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.valueLabel.numberOfLines = 2
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        view.valueLabel.lineBreakMode = .byTruncatingTail
        return view
    }
}
