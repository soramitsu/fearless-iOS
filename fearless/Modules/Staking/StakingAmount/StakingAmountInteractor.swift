import UIKit

final class StakingAmountInteractor {
    weak var presenter: StakingAmountInteractorOutputProtocol!
}

extension StakingAmountInteractor: StakingAmountInteractorInputProtocol {}