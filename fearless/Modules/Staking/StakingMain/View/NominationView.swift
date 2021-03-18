import Foundation
import UIKit
import SoraUI
import SoraFoundation

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

    var locale: Locale = Locale.current {
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
        self.localizableViewModel = viewModel

        applyViewModel()
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .stakingStake(preferredLanguages: locale.rLanguages)
        stakedTitleLabel.text = R.string.localizable
            .stakingMainTotalStakedTitle(preferredLanguages: locale.rLanguages)
        rewardTitleLabel.text = R.string.localizable
            .stakingTotalRewards(preferredLanguages: locale.rLanguages)
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel?.value(for: locale) else {
            return
        }

        stakedAmountLabel.text = viewModel.totalStakedAmount
        stakedPriceLabel.text = viewModel.totalStakedPrice
        rewardAmountLabel.text = viewModel.totalRewardAmount
        rewardPriceLabel.text = viewModel.totalRewardPrice

        switch viewModel.status {
        case .undefined:
            toggleStatus(false)
        case .active(let era):
            toggleStatus(true)

            statusIndicatorView.fillColor = R.color.colorGreen()!
            statusTitleLabel.textColor = R.color.colorGreen()!

            statusTitleLabel.text = R.string.localizable
                .stakingNominatorStatusActive(preferredLanguages: locale.rLanguages).uppercased()
            statusDetailsLabel.text = R.string.localizable
                .stakingEraTitle("\(era)", preferredLanguages: locale.rLanguages).uppercased()
        case .inactive(let era):
            toggleStatus(true)

            statusIndicatorView.fillColor = R.color.colorRed()!
            statusTitleLabel.textColor = R.color.colorRed()!

            statusTitleLabel.text = R.string.localizable
                .stakingNominatorStatusInactive(preferredLanguages: locale.rLanguages).uppercased()
            statusDetailsLabel.text = R.string.localizable
                .stakingEraTitle("\(era)", preferredLanguages: locale.rLanguages).uppercased()

        case .waiting:
            toggleStatus(true)

            statusIndicatorView.fillColor = R.color.colorTransparentText()!
            statusTitleLabel.textColor = R.color.colorTransparentText()!

            statusTitleLabel.text = R.string.localizable
                .stakingNominatorStatusWaiting(preferredLanguages: locale.rLanguages).uppercased()
            statusDetailsLabel.text = ""

        case .election:
            toggleStatus(true)

            statusIndicatorView.fillColor = R.color.colorTransparentText()!
            statusTitleLabel.textColor = R.color.colorTransparentText()!

            statusTitleLabel.text = R.string.localizable
                .stakingNominatorStatusElection(preferredLanguages: locale.rLanguages).uppercased()
            statusDetailsLabel.text = ""
        }
    }

    private func toggleStatus(_ shouldShow: Bool) {
        statusTitleLabel.isHidden = !shouldShow
        statusDetailsLabel.isHidden = !shouldShow
        statusIndicatorView.isHidden = !shouldShow
    }
}
