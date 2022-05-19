import UIKit
import SoraUI
import SoraFoundation

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

    @IBOutlet var backgroundView: TriangularedBlurView!
    @IBOutlet var networkInfoContainer: UIView!
    @IBOutlet var titleControl: ActionTitleControl!
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var contentTop: NSLayoutConstraint!
    @IBOutlet var contentHeight: NSLayoutConstraint!

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
    private var chainName: String?

    override func awakeFromNib() {
        super.awakeFromNib()

        titleControl.imageView.isUserInteractionEnabled = false
        titleControl.activate(animated: false)

        setupLayout()
    }

    private func setupLayout() {
        networkInfoContainer.addSubview(stackTableView)

        stackTableView.snp.makeConstraints { make in
            make.top.equalTo(collectionView.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }
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

        if let totalStake = localizedViewModel.totalStake {
            stackTableView.addView(view: totalStakeView)

            totalStakeView.bind(value: totalStake.amount)
            totalStakeView.bind(subtitle: totalStake.price)
        }

        if let minimumStake = localizedViewModel.minimalStake {
            stackTableView.addView(view: minimumStakeView)

            minimumStakeView.bind(value: minimumStake.amount)
            minimumStakeView.bind(subtitle: minimumStake.price)
        }

        if let activeNominators = localizedViewModel.activeNominators {
            stackTableView.addView(view: activeNominatorsView)

            activeNominatorsView.bind(value: activeNominators)
        }

        if let unstakePeriod = localizedViewModel.lockUpPeriod {
            stackTableView.addView(view: unstakingPeriodView)

            unstakingPeriodView.bind(value: unstakePeriod)
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
        let languages = locale.rLanguages

        totalStakeView.bind(title: R.string.localizable
            .stakingMainTotalStakedTitle(preferredLanguages: languages))
        minimumStakeView.bind(title: R.string.localizable
            .stakingMainMinimumStakeTitle(preferredLanguages: languages))
        activeNominatorsView.bind(title: R.string.localizable
            .stakingMainActiveNominatorsTitle(preferredLanguages: languages))
        unstakingPeriodView.bind(title: R.string.localizable
            .stakingMainLockupPeriodTitle_v190(preferredLanguages: languages))

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
//            contentTop.constant = 0.0
            networkInfoContainer.alpha = 1.0
            delegate?.didChangeExpansion(isExpanded: true, view: self)
        } else {
//            contentTop.constant = -contentHeight.constant
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
        let spaceSize = networkInfoContainer.frame.size

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
        let topInset: CGFloat = 7.0
        let verticalSpacing: CGFloat = 10.0

        return [
            SingleSkeleton.createRow(
                under: totalStakeView.titleLabel,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0.0, y: topInset),
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                under: totalStakeView.valueLabel,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0.0, y: topInset + bigRowSize.height + verticalSpacing),
                size: smallRowSize
            ),

            SingleSkeleton.createRow(
                under: minimumStakeView.titleLabel,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0.0, y: topInset),
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                under: minimumStakeView.valueLabel,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0.0, y: topInset + bigRowSize.height + verticalSpacing),
                size: smallRowSize
            ),

            SingleSkeleton.createRow(
                under: activeNominatorsView,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0.0, y: topInset),
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                under: unstakingPeriodView,
                containerView: networkInfoContainer,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0.0, y: topInset),
                size: bigRowSize
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
