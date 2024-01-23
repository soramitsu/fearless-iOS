import Foundation
import SoraFoundation

final class ClaimCrowdloanRewardsPresenter {
    // MARK: Private properties
    private weak var view: ClaimCrowdloanRewardsViewInput?
    private let router: ClaimCrowdloanRewardsRouterInput
    private let interactor: ClaimCrowdloanRewardsInteractorInput
    private let logger: LoggerProtocol?
    
    private var balanceLocks: BalanceLocks?

    // MARK: - Constructors
    init(
        interactor: ClaimCrowdloanRewardsInteractorInput,
        router: ClaimCrowdloanRewardsRouterInput,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.localizationManager = localizationManager
    }
    
    // MARK: - Private methods
}

// MARK: - ClaimCrowdloanRewardsViewOutput
extension ClaimCrowdloanRewardsPresenter: ClaimCrowdloanRewardsViewOutput {
    func didLoad(view: ClaimCrowdloanRewardsViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - ClaimCrowdloanRewardsInteractorOutput
extension ClaimCrowdloanRewardsPresenter: ClaimCrowdloanRewardsInteractorOutput {
    func didReceiveBalanceLocks(_ balanceLocks: BalanceLocks?) {
        self.balanceLocks = balanceLocks
    }
    
    func didReceiveBalanceLocksError(_ error: Error) {
        logger?.error("Balance locks error: \(error.localizedDescription)")
    }
}

// MARK: - Localizable
extension ClaimCrowdloanRewardsPresenter: Localizable {
    func applyLocalization() {}
}

extension ClaimCrowdloanRewardsPresenter: ClaimCrowdloanRewardsModuleInput {}
