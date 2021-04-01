import Foundation
import SoraFoundation

enum StakingViewState {
    case undefined
    case nominator(viewModel: LocalizableResource<NominationViewModelProtocol>)
    case validator
    case bonded(viewModel: StakingEstimationViewModel)
    case noStash(viewModel: StakingEstimationViewModel)
}
