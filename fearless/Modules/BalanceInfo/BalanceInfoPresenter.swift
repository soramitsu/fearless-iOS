import Foundation
import SoraFoundation

final class BalanceInfoPresenter {
    // MARK: Private properties

    private weak var view: BalanceInfoViewInput?
    private let router: BalanceInfoRouterInput
    private let interactor: BalanceInfoInteractorInput

    private var balanceInfoType: BalanceInfoType
    private let balanceInfoViewModelFactoryProtocol: BalanceInfoViewModelFactoryProtocol

    private var balances: WalletBalanceInfos = [:]

    // MARK: - Constructors

    init(
        balanceInfoType: BalanceInfoType,
        balanceInfoViewModelFactoryProtocol: BalanceInfoViewModelFactoryProtocol,
        interactor: BalanceInfoInteractorInput,
        router: BalanceInfoRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.balanceInfoType = balanceInfoType
        self.balanceInfoViewModelFactoryProtocol = balanceInfoViewModelFactoryProtocol
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func buildBalance() {
        let viewModel = balanceInfoViewModelFactoryProtocol.buildBalanceInfo(
            with: balanceInfoType,
            balances: balances,
            locale: selectedLocale
        )

        view?.didReceiveViewModel(viewModel)
    }
}

// MARK: - BalanceInfoViewOutput

extension BalanceInfoPresenter: BalanceInfoViewOutput {
    func didLoad(view: BalanceInfoViewInput) {
        self.view = view
        interactor.setup(with: self)

        interactor.fetchBalance(for: balanceInfoType)
    }
}

// MARK: - BalanceInfoInteractorOutput

extension BalanceInfoPresenter: BalanceInfoInteractorOutput {
    func didReceiveWalletBalancesResult(_ result: WalletBalancesResult) {
        switch result {
        case let .success(balances):
            self.balances = balances
            buildBalance()
        case let .failure(error):
            print(error)
        }
    }
}

// MARK: - Localizable

extension BalanceInfoPresenter: Localizable {
    func applyLocalization() {}
}

extension BalanceInfoPresenter: BalanceInfoModuleInput {
    func replace(infoType: BalanceInfoType) {
        balanceInfoType = infoType
        interactor.fetchBalance(for: infoType)
    }
}
