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
        settings.fillMode = .full
        return CosmosView(settings: settings)
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title
        label.textColor = .white
        return label
    }()

    let addressView = CopyableLabelView()

    let statsBackgroundView = TriangularedView()

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

    let closeButton = TriangularedButton()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubviews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private methods

    private func addSubviews() {
        addSubview(topBar)
        addSubview(scrollView)
        addSubview(closeButton)

        scrollView.addSubview(statsBackgroundView)
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

        closeButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(48)
            make.bottom.equalTo(safeAreaInsets).inset(16)
        }

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom)
            make.bottom.equalTo(closeButton).offset(16)
            make.leading.trailing.equalToSuperview()
        }

        statsBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        ratingView.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.height.equalTo(30)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(ratingView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        scoreLabel.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }

        addressView.snp.makeConstraints { make in
            make.top.equalTo(scoreLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
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
    }

    private func setupRowViewConstraints(_ view: UIView) {
        view.snp.makeConstraints { make in
            make.height.equalTo(48)
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private static func makeRowView() -> TitleValueView {
        let view = TitleValueView()
        view.titleLabel.font = .p1Paragraph
        view.titleLabel.textColor = R.color.colorWhite()
        view.valueLabel.font = .p1Paragraph
        view.valueLabel.textColor = R.color.colorWhite()
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        view.valueLabel.lineBreakMode = .byTruncatingTail
        return view
    }
}
