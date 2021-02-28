import UIKit

final class StakingConfirmInteractor {
    weak var presenter: StakingConfirmInteractorOutputProtocol!
}

extension StakingConfirmInteractor: StakingConfirmInteractorInputProtocol {}