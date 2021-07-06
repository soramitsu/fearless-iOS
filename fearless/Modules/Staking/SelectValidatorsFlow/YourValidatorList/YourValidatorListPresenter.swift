import Foundation
import SoraFoundation

final class YourValidatorListPresenter {
    weak var view: YourValidatorListViewProtocol?
    let wireframe: YourValidatorListWireframeProtocol
    let interactor: YourValidatorListInteractorInputProtocol

    let viewModelFactory: YourValidatorListViewModelFactoryProtocol
    let chain: Chain
    let logger: LoggerProtocol?

    private var validatorsModel: YourValidatorsModel?
    private var controllerAccount: AccountItem?
    private var stashItem: StashItem?
    private var ledger: StakingLedger?
    private var rewardDestinationArg: RewardDestinationArg?
    private var lastError: Error?

    init(
        interactor: YourValidatorListInteractorInputProtocol,
        wireframe: YourValidatorListWireframeProtocol,
        viewModelFactory: YourValidatorListViewModelFactoryProtocol,
        chain: Chain,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chain = chain
        self.logger = logger
    }

    private func updateView() {
        guard lastError == nil else {
            let errorDescription = LocalizableResource { locale in
                R.string.localizable
                    .commonErrorNoDataRetrieved(preferredLanguages: locale.rLanguages)
            }
            view?.reload(state: .error(errorDescription))
            return
        }

        guard let model = validatorsModel else {
            view?.reload(state: .loading)
            return
        }

        do {
            let sections = try viewModelFactory.createViewModel(for: model)
            view?.reload(state: .validatorList(sections))
        } catch {
            logger?.error("Did receive error: \(error)")
        }
    }

    private func handle(error: Error) {
        lastError = error
        validatorsModel = nil

        updateView()
    }

    private func handle(validatorsModel: YourValidatorsModel?) {
        self.validatorsModel = validatorsModel
        lastError = nil

        updateView()
    }
}

extension YourValidatorListPresenter: YourValidatorListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func retry() {
        validatorsModel = nil
        lastError = nil

        interactor.refresh()
    }

    func didSelectValidator(viewModel: YourValidatorViewModel) {
        if let validatorInfo = validatorsModel?.allValidators
            .first(where: { $0.address == viewModel.address }) {
            wireframe.present(validatorInfo, from: view)
        }
    }

    func changeValidators() {
        guard let view = view else {
            return
        }

        guard
            let bondedAmount = ledger?.active,
            let rewardDestination = rewardDestinationArg,
            let stashItem = stashItem else {
            return
        }

        guard let controllerAccount = controllerAccount else {
            let locale = view.localizationManager?.selectedLocale
            wireframe.presentMissingController(
                from: view,
                address: stashItem.controller,
                locale: locale
            )
            return
        }

        if
            let amount = Decimal.fromSubstrateAmount(
                bondedAmount,
                precision: chain.addressType.precision
            ),
            let rewardDestination = try? RewardDestination(
                payee: rewardDestination,
                stashItem: stashItem,
                chain: chain
            ) {
            let existingBonding = ExistingBonding(
                stashAddress: stashItem.stash,
                controllerAccount: controllerAccount,
                amount: amount,
                rewardDestination: rewardDestination
            )

            wireframe.proceedToSelectValidatorsStart(from: view, existingBonding: existingBonding)
        }
    }
}

extension YourValidatorListPresenter: YourValidatorListInteractorOutputProtocol {
    func didReceiveValidators(result: Result<YourValidatorsModel?, Error>) {
        switch result {
        case let .success(item):
            handle(validatorsModel: item)
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveController(result: Result<AccountItem?, Error>) {
        switch result {
        case let .success(item):
            controllerAccount = item
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(item):
            stashItem = item
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveLedger(result: Result<StakingLedger?, Error>) {
        switch result {
        case let .success(item):
            ledger = item
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveRewardDestination(result: Result<RewardDestinationArg?, Error>) {
        switch result {
        case let .success(item):
            rewardDestinationArg = item
        case let .failure(error):
            handle(error: error)
        }
    }
}
