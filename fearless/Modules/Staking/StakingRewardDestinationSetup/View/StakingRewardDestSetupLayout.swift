import UIKit
import SnapKit

final class StakingRewardDestSetupLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let restakeOptionView = UIFactory.default.createRewardSelectionView()
    let payoutOptionView = UIFactory.default.createRewardSelectionView()
    let accountView = UIFactory.default.createAccountView(for: .selection)

    let networkFeeView = UIFactory.default.createNetworkFeeView()
    let actionButton: TriangularedButton = UIFactory.default.createMainActionButton()
    let learnMoreView = UIFactory.default.createLearnMoreView()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()!

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        networkFeeView.locale = locale

        learnMoreView.titleLabel.text = R.string.localizable
            .stakingRewardsLearnMore(preferredLanguages: locale.rLanguages)

        restakeOptionView.title = R.string.localizable
            .stakingRestakeTitle(preferredLanguages: locale.rLanguages)

        payoutOptionView.title = R.string.localizable
            .stakingPayoutTitle(preferredLanguages: locale.rLanguages)

        accountView.title = R.string.localizable
            .stakingRewardDestinationTitle(preferredLanguages: locale.rLanguages)

        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(restakeOptionView)
        restakeOptionView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: restakeOptionView)

        contentView.stackView.addArrangedSubview(payoutOptionView)
        payoutOptionView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: payoutOptionView)

        contentView.stackView.addArrangedSubview(accountView)
        accountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: payoutOptionView)

        contentView.stackView.addArrangedSubview(learnMoreView)
        learnMoreView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        contentView.stackView.addArrangedSubview(networkFeeView)
        networkFeeView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
