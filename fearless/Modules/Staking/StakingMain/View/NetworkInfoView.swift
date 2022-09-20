import UIKit
import SoraUI
import SoraFoundation

struct NetworkInfoContentViewModel {
    let title: String
    let value: String
    let details: String?
}

protocol NetworkInfoViewDelegate: AnyObject {
    func animateAlongsideWithInfo(view: NetworkInfoView)
    func didChangeExpansion(isExpanded: Bool, view: NetworkInfoView)
}

final class NetworkInfoView: UIView {
    private let stackTableView = StackedTableView(columns: 2)

    private let totalStakeView = StakingUnitInfoView()
    private let minimumStakeView = StakingUnitInfoView()
    private let activeNominatorsView = StakingUnitInfoView()
    private let unstakingPeriodView = StakingUnitInfoView()

    var backgroundView = TriangularedBlurView()
    var networkInfoContainer = UIView()
    var titleControl: ActionTitleControl = {
        let control = ActionTitleControl()
        control.titleLabel.font = .p1Paragraph
        control.imageView.image = R.image.iconArrowUp()
        control.contentInsets = UIEdgeInsets(
            top: 0,
            left: UIConstants.bigOffset,
            bottom: 0,
            right: UIConstants.bigOffset
        )
        control.layoutType = .flexible
        return control
    }()

    var descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorTransparentText()
        label.numberOfLines = 0
        return label
    }()

    var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 88, height: 80)
        layout.scrollDirection = .horizontal
        layout.sectionInset = UIEdgeInsets(
            top: 0,
            left: UIConstants.bigOffset,
            bottom: 0,
            right: UIConstants.bigOffset
        )

        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()

    weak var delegate: NetworkInfoViewDelegate?

    lazy var expansionAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()

    var expanded: Bool { titleControl.isActivated }

    private var skeletonView: SkrullableView?

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyTitle()
            applyViewModel()
        }
    }

    private var localizableViewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?
    private var viewModels: [LocalizableResource<NetworkInfoContentViewModel>]?
    private var chainName: String?

    override func awakeFromNib() {
        super.awakeFromNib()

        titleControl.imageView.isUserInteractionEnabled = false
        titleControl.activate(animated: false)

        setupLayout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupManualLayout()

        titleControl.imageView.isUserInteractionEnabled = false
        titleControl.activate(animated: false)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func setupManualLayout() {
        addSubview(backgroundView)
        addSubview(titleControl)
        addSubview(networkInfoContainer)

        networkInfoContainer.addSubview(descriptionLabel)
        networkInfoContainer.addSubview(collectionView)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        titleControl.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
            make.bottom.lessThanOrEqualToSuperview()
        }

        networkInfoContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleControl.snp.bottom)
        }

        collectionView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(88)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalToSuperview()
            make.height.equalTo(70)
        }

        setupLayout()
    }

    private func setupLayout() {
        networkInfoContainer.addSubview(stackTableView)

        stackTableView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(collectionView.snp.bottom).offset(UIConstants.defaultOffset)
            make.top.greaterThanOrEqualTo(descriptionLabel.snp.bottom).offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        titleControl.addTarget(self, action: #selector(actionToggleExpansion), for: .touchUpInside)
    }

    func setExpanded(_ value: Bool, animated: Bool) {
        guard value != expanded else {
            return
        }

        if value {
            titleControl.activate(animated: animated)
        } else {
            titleControl.deactivate(animated: animated)
        }

        applyExpansion(animated: animated)
    }

    func bind(viewModels: [LocalizableResource<NetworkInfoContentViewModel>]) {
        self.viewModels = viewModels
        stackTableView.clear()

        if viewModels.isEmpty {
            startLoading()
        } else {
            stopLoadingIfNeeded()

            viewModels.forEach { localizableViewModel in
                let totalStakeView = StakingUnitInfoView()
                stackTableView.addView(view: totalStakeView)
                totalStakeView.bind(title: localizableViewModel.value(for: locale).title)
                totalStakeView.bind(value: localizableViewModel.value(for: locale).value)
                totalStakeView.bind(subtitle: localizableViewModel.value(for: locale).details)
            }
        }
    }

    func bind(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?) {
        localizableViewModel = viewModel

        if viewModel != nil {
            stopLoadingIfNeeded()

            applyViewModel()
        } else {
            startLoading()
        }
    }

    func bind(chainName: String) {
        self.chainName = chainName

        applyTitle()
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel else {
            return
        }

        stackTableView.clear()

        let localizedViewModel = viewModel.value(for: locale)

        let languages = locale.rLanguages

        if let totalStake = localizedViewModel.totalStake {
            let totalStakeView = StakingUnitInfoView()
            stackTableView.addView(view: totalStakeView)

            totalStakeView.bind(value: totalStake.amount)
            totalStakeView.bind(subtitle: totalStake.price)

            totalStakeView.bind(title: R.string.localizable
                .stakingMainTotalStakedTitle(preferredLanguages: languages))
        }

        if let minimumStake = localizedViewModel.minimalStake {
            let minimumStakeView = StakingUnitInfoView()
            stackTableView.addView(view: minimumStakeView)

            minimumStakeView.bind(value: minimumStake.amount)
            minimumStakeView.bind(subtitle: minimumStake.price)

            minimumStakeView.bind(title: R.string.localizable
                .stakingMainMinimumStakeTitle(preferredLanguages: languages))
        }

        if let activeNominators = localizedViewModel.activeNominators {
            let activeNominatorsView = StakingUnitInfoView()
            stackTableView.addView(view: activeNominatorsView)

            activeNominatorsView.bind(value: activeNominators)

            activeNominatorsView.bind(title: R.string.localizable
                .stakingMainActiveNominatorsTitle(preferredLanguages: languages))
        }

        if let unstakePeriod = localizedViewModel.lockUpPeriod {
            let unstakingPeriodView = StakingUnitInfoView()
            stackTableView.addView(view: unstakingPeriodView)

            unstakingPeriodView.bind(value: unstakePeriod)

            unstakingPeriodView.bind(title: R.string.localizable
                .stakingMainLockupPeriodTitle_v190(preferredLanguages: languages))
        }
    }

    private func applyTitle() {
        guard let chainName = chainName else {
            return
        }

        titleControl.titleLabel.text = R.string.localizable
            .stakingMainNetworkTitle(chainName, preferredLanguages: locale.rLanguages)
        titleControl.invalidateLayout()
    }

    private func applyLocalization() {
        collectionView.reloadData()
    }

    private func applyExpansion(animated: Bool) {
        if animated {
            expansionAnimator.animate(block: { [weak self] in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.applyExpansionState()

                let animation = CABasicAnimation()
                animation.toValue = strongSelf.backgroundView.blurMaskView?.shapePath
                strongSelf.backgroundView.blurMaskView?.layer
                    .add(animation, forKey: #keyPath(CAShapeLayer.path))

                strongSelf.delegate?.animateAlongsideWithInfo(view: strongSelf)
            }, completionBlock: nil)
        } else {
            applyExpansionState()
            setNeedsLayout()
        }
    }

    private func applyExpansionState() {
        if expanded {
            networkInfoContainer.snp.remakeConstraints { make in
                make.leading.trailing.bottom.equalToSuperview()
                make.top.equalTo(titleControl.snp.bottom)
            }
            networkInfoContainer.alpha = 1.0
            delegate?.didChangeExpansion(isExpanded: true, view: self)
        } else {
            networkInfoContainer.snp.remakeConstraints { make in
                make.leading.trailing.bottom.equalToSuperview()
                make.height.equalTo(0)
            }
            networkInfoContainer.alpha = 0.0
            delegate?.didChangeExpansion(isExpanded: false, view: self)
        }
    }

    func startLoading() {
        guard skeletonView == nil else {
            return
        }

        totalStakeView.alpha = 0
        minimumStakeView.alpha = 0
        activeNominatorsView.alpha = 0
        unstakingPeriodView.alpha = 0

        stackTableView.clear()

        stackTableView.addView(view: totalStakeView)
        stackTableView.addView(view: minimumStakeView)
        stackTableView.addView(view: activeNominatorsView)
        stackTableView.addView(view: unstakingPeriodView)

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        totalStakeView.alpha = 1
        minimumStakeView.alpha = 1
        activeNominatorsView.alpha = 1
        unstakingPeriodView.alpha = 1
    }

    private func setupSkeleton() {
        guard !expanded else {
            return
        }

        layoutSubviews()

        let spaceSize = networkInfoContainer.frame.size

        guard spaceSize.height > 0 else {
            return
        }

        let skeletonView = Skrull(
            size: networkInfoContainer.frame.size,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        skeletonView.frame = CGRect(origin: .zero, size: spaceSize)
        skeletonView.autoresizingMask = []
        networkInfoContainer.insertSubview(skeletonView, at: 0)

        self.skeletonView = skeletonView

        skeletonView.startSkrulling()
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let bigRowSize = CGSize(width: 72.0, height: 12.0)
        let smallRowSize = CGSize(width: 57.0, height: 6.0)
        let rowOffset: CGFloat = 4.0
        let verticalSpacing: CGFloat = 10.0

        return [
            SingleSkeleton.createRow(
                inPlaceOf: totalStakeView,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                size: smallRowSize
            ),
            SingleSkeleton.createRow(
                under: totalStakeView,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0, y: rowOffset),
                size: bigRowSize
            ),
            SingleSkeleton.createRow(
                under: totalStakeView,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0, y: bigRowSize.height + verticalSpacing + rowOffset),
                size: smallRowSize
            ),
            SingleSkeleton.createRow(
                inPlaceOf: minimumStakeView,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                size: smallRowSize
            ),
            SingleSkeleton.createRow(
                under: minimumStakeView,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0, y: rowOffset),
                size: bigRowSize
            ),
            SingleSkeleton.createRow(
                under: minimumStakeView,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0, y: bigRowSize.height + verticalSpacing + rowOffset),
                size: smallRowSize
            )
        ]
    }

    // MARK: Action

    @IBAction func actionToggleExpansion() {
        applyExpansion(animated: true)
    }
}

extension NetworkInfoView: SkeletonLoadable {
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

        if skeletonView.frame.size != networkInfoContainer.frame.size {
            skeletonView.removeFromSuperview()
            self.skeletonView = nil
            setupSkeleton()
        }
    }
}
