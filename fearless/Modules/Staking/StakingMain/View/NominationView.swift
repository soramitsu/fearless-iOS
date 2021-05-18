import Foundation
import UIKit
import SoraUI
import SoraFoundation

protocol NominationViewDelegate: AnyObject {
    func nominationViewDidReceiveMoreAction(_ nominationView: NominationView)
    func nominationViewDidReceiveStatusAction(_ nominationView: NominationView)
}

final class NominationView: UIView, LocalizableViewProtocol {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var stakedTitleLabel: UILabel!
    @IBOutlet private var stakedAmountLabel: UILabel!
    @IBOutlet private var stakedPriceLabel: UILabel!
    @IBOutlet private var rewardTitleLabel: UILabel!
    @IBOutlet private var rewardAmountLabel: UILabel!
    @IBOutlet private var rewardPriceLabel: UILabel!
    @IBOutlet private var statusIndicatorView: RoundedView!
    @IBOutlet private var statusTitleLabel: UILabel!
    @IBOutlet private var statusDetailsLabel: UILabel!
    @IBOutlet private var statusNavigationView: UIImageView!

    @IBOutlet private var statusButton: TriangularedButton!

    weak var delegate: NominationViewDelegate?

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyViewModel()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        applyLocalization()
    }

    private var localizableViewModel: LocalizableResource<NominationViewModelProtocol>?

    func bind(viewModel: LocalizableResource<NominationViewModelProtocol>) {
        localizableViewModel = viewModel

        applyViewModel()
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable.stakingYourStake(preferredLanguages: locale.rLanguages)
        stakedTitleLabel.text = R.string.localizable.stakingBonded(preferredLanguages: locale.rLanguages)
        rewardTitleLabel.text = R.string.localizable.stakingEarned(preferredLanguages: locale.rLanguages)
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel?.value(for: locale) else {
            return
        }

        stakedAmountLabel.text = viewModel.totalStakedAmount
        stakedPriceLabel.text = viewModel.totalStakedPrice
        rewardAmountLabel.text = viewModel.totalRewardAmount
        rewardPriceLabel.text = viewModel.totalRewardPrice

        if case .undefined = viewModel.status {
            toggleStatus(false)
        } else {
            toggleStatus(true)
        }

        switch viewModel.status {
        case .undefined:
            break
        case let .active(era):
            presentActiveStatus(for: era)
        case let .inactive(era):
            presentInactiveStatus(for: era)
        case .waiting:
            presentWaitingStatus()
        }
    }

    private func toggleStatus(_ shouldShow: Bool) {
        statusTitleLabel.isHidden = !shouldShow
        statusDetailsLabel.isHidden = !shouldShow
        statusIndicatorView.isHidden = !shouldShow
        statusNavigationView.isHidden = !shouldShow
        statusButton.isUserInteractionEnabled = shouldShow
    }

    private func presentActiveStatus(for era: UInt32) {
        statusIndicatorView.fillColor = R.color.colorGreen()!
        statusTitleLabel.textColor = R.color.colorGreen()!

        statusTitleLabel.text = R.string.localizable
            .stakingNominatorStatusActive(preferredLanguages: locale.rLanguages).uppercased()
        statusDetailsLabel.text = R.string.localizable
            .stakingEraTitle("\(era)", preferredLanguages: locale.rLanguages).uppercased()
    }

    private func presentInactiveStatus(for era: UInt32) {
        statusIndicatorView.fillColor = R.color.colorRed()!
        statusTitleLabel.textColor = R.color.colorRed()!

        statusTitleLabel.text = R.string.localizable
            .stakingNominatorStatusInactive(preferredLanguages: locale.rLanguages).uppercased()
        statusDetailsLabel.text = R.string.localizable
            .stakingEraTitle("\(era)", preferredLanguages: locale.rLanguages).uppercased()
    }

    private func presentWaitingStatus() {
        statusIndicatorView.fillColor = R.color.colorTransparentText()!
        statusTitleLabel.textColor = R.color.colorTransparentText()!

        statusTitleLabel.text = R.string.localizable
            .stakingNominatorStatusWaiting(preferredLanguages: locale.rLanguages).uppercased()
        statusDetailsLabel.text = ""
    }

    @IBAction private func actionOnMore() {
        delegate?.nominationViewDidReceiveMoreAction(self)
    }

    @IBAction private func actionOnStatus() {
        delegate?.nominationViewDidReceiveStatusAction(self)
    }
}
