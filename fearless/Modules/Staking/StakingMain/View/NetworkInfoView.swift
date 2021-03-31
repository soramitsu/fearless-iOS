import UIKit
import SoraUI
import SoraFoundation

protocol NetworkInfoViewDelegate: class {
    func animateAlongsideWithInfo(view: NetworkInfoView)
}

final class NetworkInfoView: UIView {
    @IBOutlet weak var backgroundView: TriangularedBlurView!
    @IBOutlet weak var networkInfoContainer: UIView!
    @IBOutlet weak var titleControl: ActionTitleControl!
    @IBOutlet weak var collectionView: UICollectionView!

    @IBOutlet weak var totalStakedTitleLabel: UILabel!
    @IBOutlet weak var totalStakedAmountLabel: UILabel!
    @IBOutlet weak var totalStakedFiatAmountLabel: UILabel!
    @IBOutlet weak var minimumStakeTitleLabel: UILabel!
    @IBOutlet weak var minimumStakeAmountLabel: UILabel!
    @IBOutlet weak var minimumStakeFiatAmountLabel: UILabel!
    @IBOutlet weak var activeNominatorsTitleLabel: UILabel!
    @IBOutlet weak var activeNominatorsLabel: UILabel!
    @IBOutlet weak var lockUpPeriodTitleLabel: UILabel!
    @IBOutlet weak var lockUpPeriodLabel: UILabel!

    @IBOutlet weak var contentTop: NSLayoutConstraint!
    @IBOutlet weak var contentHeight: NSLayoutConstraint!

    weak var delegate: NetworkInfoViewDelegate?

    lazy var expansionAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()

    var expanded: Bool { titleControl.isActivated }

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyTitle()
            applyViewModel()
        }
    }

    private var localizableViewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?
    private var chainName: LocalizableResource<String>?

    override func awakeFromNib() {
        super.awakeFromNib()

        titleControl.imageView.isUserInteractionEnabled = false
        titleControl.activate(animated: false)
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

    func bind(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>) {
        localizableViewModel = viewModel

        applyViewModel()
    }

    func bind(chainName: LocalizableResource<String>) {
        self.chainName = chainName

        applyTitle()
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel else {
            return
        }

        let localizedViewModel = viewModel.value(for: locale)

        totalStakedAmountLabel.text = localizedViewModel.totalStake?.amount
        totalStakedFiatAmountLabel.text = localizedViewModel.totalStake?.price
        minimumStakeAmountLabel.text = localizedViewModel.minimalStake?.amount
        minimumStakeFiatAmountLabel.text = localizedViewModel.minimalStake?.price
        activeNominatorsLabel.text = localizedViewModel.activeNominators
        lockUpPeriodLabel.text = localizedViewModel.lockUpPeriod
    }

    private func applyTitle() {
        guard let chainName = chainName?.value(for: locale) else {
            return
        }

        titleControl.titleLabel.text = R.string.localizable
            .stakingMainNetworkTitle(chainName, preferredLanguages: locale.rLanguages)
        titleControl.invalidateLayout()
    }

    private func applyLocalization() {
        let languages = locale.rLanguages

        totalStakedTitleLabel.text = R.string.localizable
            .stakingMainTotalStakedTitle(preferredLanguages: languages)
        minimumStakeTitleLabel.text = R.string.localizable
            .stakingMainMinimumStakeTitle(preferredLanguages: languages)
        activeNominatorsTitleLabel.text = R.string.localizable
            .stakingMainActiveNominatorsTitle(preferredLanguages: languages)
        lockUpPeriodTitleLabel.text = R.string.localizable
            .stakingMainLockupPeriodTitle(preferredLanguages: languages)
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
            contentTop.constant = 0.0
            networkInfoContainer.alpha = 1.0
        } else {
            contentTop.constant = -self.contentHeight.constant
            networkInfoContainer.alpha = 0.0
        }
    }

    // MARK: Action

    @IBAction func actionToggleExpansion() {
        applyExpansion(animated: true)
    }
}
