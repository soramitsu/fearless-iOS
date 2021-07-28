import Foundation
import UIKit
import SoraUI
import SoraFoundation

protocol ValidationViewDelegate: AnyObject {
    func validationViewDidReceiveMoreAction(_ validationView: ValidationView)
    func validationViewDidReceiveStatusAction(_ validationView: ValidationView)
}

final class ValidationView: UIView, LocalizableViewProtocol {
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

    weak var delegate: ValidationViewDelegate?

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

    private var localizableViewModel: LocalizableResource<ValidationViewModelProtocol>?

    func bind(viewModel: LocalizableResource<ValidationViewModelProtocol>) {
        localizableViewModel = viewModel

        applyViewModel()
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .stakingValidatorSummaryTitle(preferredLanguages: locale.rLanguages)
        stakedTitleLabel.text = R.string.localizable
            .stakingMainStakeBalanceStaked(preferredLanguages: locale.rLanguages)
        rewardTitleLabel.text = R.string.localizable
            .stakingTotalRewards_v190(preferredLanguages: locale.rLanguages)
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

    @IBAction private func actionOnMore() {
        delegate?.validationViewDidReceiveMoreAction(self)
    }

    @IBAction private func actionOnStatus() {
        delegate?.validationViewDidReceiveStatusAction(self)
    }
}
