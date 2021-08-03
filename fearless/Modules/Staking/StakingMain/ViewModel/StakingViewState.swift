import Foundation
import SoraFoundation

enum StakingViewState {
    case undefined
    case nominator(
        viewModel: LocalizableResource<NominationViewModelProtocol>,
        alerts: [StakingAlert]
    )
    case validator(viewModel: LocalizableResource<ValidationViewModelProtocol>, alerts: [StakingAlert])
    case noStash(viewModel: StakingEstimationViewModel, alerts: [StakingAlert])
}
