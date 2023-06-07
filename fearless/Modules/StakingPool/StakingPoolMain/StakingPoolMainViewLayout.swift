import UIKit
import SoraFoundation
import SnapKit

final class StakingPoolMainViewLayout: UIView {
    private enum Constants {
        static let verticalSpacing: CGFloat = 0.0
        static let bottomInset: CGFloat = 8.0
        static let contentInset = UIEdgeInsets(
            top: UIConstants.bigOffset,
            left: 0,
            bottom: UIConstants.bigOffset,
            right: 0
        )
        static let birdButtonSize = CGSize(width: 40, height: 40)
        static let networkInfoHeight: CGFloat = 292
        static let nominatorStateViewHeight: CGFloat = 232
    }

    var keyboardAdoptableConstraint: Constraint?

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = .zero
        view.scrollView.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: UIConstants.bigOffset * 3 + UIConstants.actionHeight,
            right: 0
        )
        return view
    }()

    let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let walletSelectionButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconBirdGreen(), for: .normal)
        return button
    }()

    let assetSelectionContainerView = UIView()
    let assetSelectionView: DetailsTriangularedView = {
        let view = UIFactory.default.createChainAssetSelectionView(layout: .largeIconTitleInfoSubtitle)
        view.borderWidth = 0.0
        return view
    }()

    let rewardCalculatorView: StakingRewardCalculatorView = {
        let rewardCalculatorView = StakingRewardCalculatorView()
        rewardCalculatorView.uiFactory = UIFactory.default
        return rewardCalculatorView
    }()

    let networkInfoView = NetworkInfoView()

    let nominatorStateView = NominatorStateView()

    let startStakingButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
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

    private func applyLocalization() {
        titleLabel.text = R.string.localizable.stakingTitle(preferredLanguages: locale.rLanguages)
        networkInfoView.titleControl.titleLabel.text = R.string.localizable.poolStakingTitle(
            preferredLanguages: locale.rLanguages
        )
        networkInfoView.descriptionLabel.text = R.string.localizable.poolStakingMainDescriptionTitle(
            preferredLanguages: locale.rLanguages
        )
        startStakingButton.imageWithTitleView?.title = R.string.localizable.stakingStartTitle(
            preferredLanguages: locale.rLanguages
        )

        assetSelectionView.additionalInfoView?.setTitle(
            R.string.localizable.poolCommon(preferredLanguages: locale.rLanguages).uppercased(),
            for: .normal
        )
        rewardCalculatorView.locale = locale
    }

    private func setupLayout() {
        addSubview(backgroundImageView)
        addSubview(titleLabel)
        addSubview(walletSelectionButton)
        addSubview(contentView)
        addSubview(startStakingButton)

        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(walletSelectionButton.snp.bottom).offset(UIConstants.defaultOffset)
            keyboardAdoptableConstraint = make.bottom.equalTo(safeAreaLayoutGuide).constraint
        }

        assetSelectionContainerView.translatesAutoresizingMaskIntoConstraints = false

        let backgroundView = TriangularedBlurView()
        assetSelectionContainerView.addSubview(backgroundView)
        assetSelectionContainerView.addSubview(assetSelectionView)

        applyConstraints(for: assetSelectionContainerView, innerView: assetSelectionView)

        contentView.stackView.addArrangedSubview(assetSelectionContainerView)

        assetSelectionView.snp.makeConstraints { make in
            make.height.equalTo(48.0)
        }

        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(assetSelectionView)
        }

        assetSelectionContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(networkInfoView)
        contentView.stackView.addArrangedSubview(rewardCalculatorView)
        contentView.stackView.addArrangedSubview(nominatorStateView)

        networkInfoView.collectionView.snp.makeConstraints { make in
            make.height.equalTo(0)
        }

        rewardCalculatorView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(walletSelectionButton.snp.centerY)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }

        walletSelectionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.size.equalTo(Constants.birdButtonSize)
            make.leading.equalTo(titleLabel.snp.trailing).offset(UIConstants.bigOffset)
        }

        networkInfoView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        nominatorStateView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        startStakingButton.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.bottom.equalTo(contentView.snp.bottom).inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: networkInfoView)
    }

    private func applyConstraints(for containerView: UIView, innerView: UIView) {
        innerView.translatesAutoresizingMaskIntoConstraints = false
        innerView.leadingAnchor.constraint(
            equalTo: containerView.leadingAnchor,
            constant: UIConstants.horizontalInset
        ).isActive = true
        innerView.trailingAnchor.constraint(
            equalTo: containerView.trailingAnchor,
            constant: -UIConstants.horizontalInset
        ).isActive = true
        innerView.topAnchor.constraint(
            equalTo: containerView.topAnchor,
            constant: Constants.verticalSpacing
        ).isActive = true

        containerView.bottomAnchor.constraint(
            equalTo: innerView.bottomAnchor,
            constant: Constants.bottomInset
        ).isActive = true
    }

    func bind(chainAsset: ChainAsset) {
        if let iconUrl = chainAsset.chain.icon {
            let assetIconViewModel: ImageViewModelProtocol? = RemoteImageViewModel(url: iconUrl)
            assetIconViewModel?.cancel(on: assetSelectionView.iconView)

            let iconSize = 2 * assetSelectionView.iconRadius
            assetIconViewModel?.loadImage(
                on: assetSelectionView.iconView,
                targetSize: CGSize(width: iconSize, height: iconSize),
                animated: false
            )
        }

        assetSelectionView.title = chainAsset.asset.symbolUppercased
    }

    func bind(balanceViewModel: BalanceViewModelProtocol) {
        assetSelectionView.subtitle = balanceViewModel.amount
    }

    func bind(estimationViewModel: StakingEstimationViewModel) {
        rewardCalculatorView.bind(viewModel: estimationViewModel)
    }

    func bind(viewModels: [LocalizableResource<NetworkInfoContentViewModel>]) {
        networkInfoView.bind(viewModels: viewModels)
    }

    func bind(nominatorStateViewModel: LocalizableResource<NominationViewModelProtocol>?) {
        nominatorStateView.isHidden = nominatorStateViewModel == nil
        rewardCalculatorView.isHidden = nominatorStateViewModel != nil
        startStakingButton.isHidden = nominatorStateViewModel != nil

        if let nominatorStateViewModel = nominatorStateViewModel {
            nominatorStateView.bind(viewModel: nominatorStateViewModel)
        }
    }
}
