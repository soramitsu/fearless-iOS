import Foundation
import UIKit
import SoraUI
import SoraFoundation

final class NominationView: UIView {
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
            applyViewModel()
        }
    }

    private var localizableViewModel: LocalizableResource<NominationViewModelProtocol>?

    func bind(viewModel: LocalizableResource<NominationViewModelProtocol>) {
        self.localizableViewModel = viewModel

        applyViewModel()
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
            statusDetailsLabel.text = "ERA #\(era)"
        case .inactive(let era):
            toggleStatus(true)

            statusIndicatorView.fillColor = R.color.colorRed()!
            statusTitleLabel.textColor = R.color.colorRed()!
            statusDetailsLabel.text = "ERA #\(era)"
        case .election, .waiting:
            toggleStatus(true)

            statusIndicatorView.fillColor = R.color.colorTransparentText()!
            statusTitleLabel.textColor = R.color.colorTransparentText()!
            statusDetailsLabel.text = ""
        }
    }

    private func toggleStatus(_ shouldShow: Bool) {
        statusTitleLabel.isHidden = !shouldShow
        statusDetailsLabel.isHidden = !shouldShow
        statusIndicatorView.isHidden = !shouldShow
    }
}
