import Foundation
import SoraFoundation

final class YourValidatorListPresenter {
    weak var view: YourValidatorListViewProtocol?
    let wireframe: YourValidatorListWireframeProtocol
    let interactor: YourValidatorListInteractorInputProtocol

    let viewModelFactory: YourValidatorListViewModelFactoryProtocol
    let chain: ChainModel
    let asset: AssetModel
    let logger: LoggerProtocol?

    private var validatorsModel: YourValidatorsModel?
    private var stashItem: StashItem?
    private var ledger: StakingLedger?
    private var rewardDestinationArg: RewardDestinationArg?
    private var lastError: Error?

    init(
        interactor: YourValidatorListInteractorInputProtocol,
        wireframe: YourValidatorListWireframeProtocol,
        viewModelFactory: YourValidatorListViewModelFactoryProtocol,
        chain: ChainModel,
        asset: AssetModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chain = chain
        self.asset = asset
        self.logger = logger

        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard lastError == nil else {
            let errorDescription = R.string.localizable
                .commonErrorNoDataRetrieved(preferredLanguages: selectedLocale.rLanguages)
            view?.reload(state: .error(errorDescription))
            return
        }

        guard let model = validatorsModel else {
            view?.reload(state: .loading)
            return
        }

        do {
            let viewModel = try viewModelFactory.createViewModel(for: model, locale: selectedLocale)
            view?.reload(state: .validatorList(viewModel: viewModel))
        } catch {
            logger?.error("Did receive error: \(error)")

            let errorDescription = R.string.localizable.commonErrorGeneralTitle(
                preferredLanguages: selectedLocale.rLanguages
            )

            view?.reload(state: .error(errorDescription))
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
        updateView()
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

        if
            let amount = Decimal.fromSubstrateAmount(
                bondedAmount,
                precision: Int16(asset.precision)
            ),
            let rewardDestination = try? RewardDestination(
                payee: rewardDestination,
                stashItem: stashItem,
                chainFormat: chain.chainFormat
            ) {
            let selectedTargets = validatorsModel.map {
                !$0.pendingValidators.isEmpty ? $0.pendingValidators : $0.currentValidators
            }

            let existingBonding = ExistingBonding(
                stashAddress: stashItem.stash,
                amount: amount,
                rewardDestination: rewardDestination,
                selectedTargets: selectedTargets
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

extension YourValidatorListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
