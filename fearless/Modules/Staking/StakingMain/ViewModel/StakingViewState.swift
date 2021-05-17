import Foundation
import SoraFoundation

enum StakingViewState {
    case undefined
    case nominator(
        viewModel: LocalizableResource<NominationViewModelProtocol>,
        alerts: [StakingAlert]
    )
    case validator(viewModel: LocalizableResource<ValidationViewModelProtocol>)
    case bonded(viewModel: StakingEstimationViewModel)
    case noStash(viewModel: StakingEstimationViewModel)
}
