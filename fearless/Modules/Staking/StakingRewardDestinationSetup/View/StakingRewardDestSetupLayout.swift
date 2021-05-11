import UIKit
import SnapKit

final class StakingRewardDestSetupLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let restakeOptionView = createPayoutOptionView()
    let payoutOptionView = createPayoutOptionView()

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
            make.height.equalTo(72.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: restakeOptionView)

        contentView.stackView.addArrangedSubview(payoutOptionView)
        payoutOptionView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(72.0)
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

    private static func createPayoutOptionView() -> RewardSelectionView {
        let view = RewardSelectionView()

        view.borderWidth = 1.0
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.strokeColor = R.color.colorGray()!
        view.highlightedStrokeColor = R.color.colorPink()!
        view.titleColor = R.color.colorWhite()!
        view.earningTitleColor = R.color.colorWhite()!
        view.earningsSubtitleColor = R.color.colorGreen()!

        view.titleLabel.font = .p1Paragraph
        view.earningsTitleLabel.font = .p2Paragraph
        view.earningsTitleLabel.font = .p2Paragraph

        view.iconView.image = R.image.listCheckmarkIcon()!
        view.isSelected = false

        return view
    }
}

// TODO: Remove after merge
import SoraUI

final class LearnMoreView: BackgroundedContentControl {
    let fearlessIconView: UIView = {
        let view = UIImageView(image: R.image.iconFearlessSmall())
        view.contentMode = .scaleAspectFit
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let arrowIconView: UIView = {
        let imageView = UIImageView(image: R.image.iconAboutArrow())
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let shapeView = ShapeView()
        shapeView.isUserInteractionEnabled = false
        shapeView.fillColor = .clear
        shapeView.highlightedFillColor = R.color.colorCellSelection()!
        backgroundView = shapeView

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
            height: 48.0
        )
    }

    private func setupLayout() {
        let stackView = UIStackView(arrangedSubviews: [fearlessIconView, titleLabel, UIView(), arrowIconView])
        stackView.spacing = 12
        stackView.isUserInteractionEnabled = false

        contentView = stackView
    }
}
