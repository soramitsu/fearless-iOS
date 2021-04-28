import Foundation

final class YourValidatorsPresenter {
    weak var view: YourValidatorsViewProtocol?
    let wireframe: YourValidatorsWireframeProtocol
    let interactor: YourValidatorsInteractorInputProtocol

    let viewModelFactory: YourValidatorsViewModelFactoryProtocol
    let chain: Chain

    private var validatorsModel: YourValidatorsModel?
    private var controllerAccount: AccountItem?
    private var stashItem: StashItem?
    private var electionStatus: ElectionStatus?
    private var ledger: DyStakingLedger?
    private var rewardDestinationArg: RewardDestinationArg?

    init(
        interactor: YourValidatorsInteractorInputProtocol,
        wireframe: YourValidatorsWireframeProtocol,
        viewModelFactory: YourValidatorsViewModelFactoryProtocol,
        chain: Chain
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chain = chain
    }

    private func updateView() {
        guard let model = validatorsModel else {
            return
        }

        do {
            let sections = try viewModelFactory.createViewModel(for: model)
            view?.reload(state: .validatorList(sections))
        } catch {
            Logger.shared.error("Did receive error: \(error)")
        }
    }
}

extension YourValidatorsPresenter: YourValidatorsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func didSelectValidator(viewModel: YourValidatorViewModel) {
        if let validatorInfo = validatorsModel?.allValidators
            .first(where: { $0.address == viewModel.address }) {
            wireframe.showValidatorInfo(from: view, validatorInfo: validatorInfo)
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

        guard case .close = electionStatus else {
            let locale = view.localizationManager?.selectedLocale
            wireframe.presentElectionPeriodIsNotClosed(from: view, locale: locale)
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

            wireframe.showRecommendedValidators(from: view, existingBonding: existingBonding)
        }
    }
}

extension YourValidatorsPresenter: YourValidatorsInteractorOutputProtocol {
    func didReceiveValidators(result: Result<YourValidatorsModel?, Error>) {
        switch result {
        case let .success(item):
            validatorsModel = item
        case .failure:
            return
        }

        updateView()
    }

    func didReceiveController(result: Result<AccountItem?, Error>) {
        switch result {
        case let .success(item):
            controllerAccount = item
        case .failure:
            return
        }
    }

    func didReceiveElectionStatus(result: Result<ElectionStatus?, Error>) {
        switch result {
        case let .success(item):
            electionStatus = item
        case .failure:
            return
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(item):
            stashItem = item
        case .failure:
            return
        }
    }

    func didReceiveLedger(result: Result<DyStakingLedger?, Error>) {
        switch result {
        case let .success(item):
            ledger = item
        case .failure:
            return
        }
    }

    func didReceiveRewardDestination(result: Result<RewardDestinationArg?, Error>) {
        switch result {
        case let .success(item):
            rewardDestinationArg = item
        case .failure:
            return
        }
    }
}
