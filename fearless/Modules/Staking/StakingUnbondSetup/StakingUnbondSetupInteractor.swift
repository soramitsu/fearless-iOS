import UIKit

final class StakingUnbondSetupInteractor {
    weak var presenter: StakingUnbondSetupInteractorOutputProtocol!
}

extension StakingUnbondSetupInteractor: StakingUnbondSetupInteractorInputProtocol {}
