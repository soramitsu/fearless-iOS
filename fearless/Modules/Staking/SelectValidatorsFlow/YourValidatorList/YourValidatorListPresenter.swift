import Foundation
import SoraFoundation

final class YourValidatorListPresenter {
    weak var view: YourValidatorListViewProtocol?
    let wireframe: YourValidatorListWireframeProtocol
    let interactor: YourValidatorListInteractorInputProtocol

    let viewModelFactory: YourValidatorListViewModelFactoryProtocol
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let logger: LoggerProtocol?
    let viewModelState: YourValidatorListViewModelState

    init(
        interactor: YourValidatorListInteractorInputProtocol,
        wireframe: YourValidatorListWireframeProtocol,
        viewModelFactory: YourValidatorListViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil,
        viewModelState: YourValidatorListViewModelState
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.logger = logger
        self.viewModelState = viewModelState

        self.localizationManager = localizationManager
    }

    private func updateView() {
        view?.didStopLoading()

        guard let viewModel = viewModelFactory.buildViewModel(
            viewModelState: viewModelState,
            locale: selectedLocale
        ) else {
            let errorDescription = R.string.localizable.commonErrorGeneralTitle(
                preferredLanguages: selectedLocale.rLanguages
            )

            view?.reload(state: .error(errorDescription))
            return
        }

        view?.reload(state: .validatorList(viewModel: viewModel))
    }
}

extension YourValidatorListPresenter: YourValidatorListPresenterProtocol {
    func setup() {
        interactor.setup()

        viewModelState.setStateListener(self)

        view?.didStartLoading()
    }

    func retry() {
        viewModelState.resetState()

        interactor.refresh()
    }

    func didSelectValidator(viewModel: YourValidatorViewModel) {
        guard let validatorInfoFlow = viewModelState.validatorInfoFlow(address: viewModel.address) else {
            return
        }

        wireframe.present(
            flow: validatorInfoFlow,
            chainAsset: chainAsset,
            wallet: wallet,
            from: view
        )
    }

    func changeValidators() {
        guard let flow = viewModelState.selectValidatorsStartFlow() else {
            return
        }

        wireframe.proceedToSelectValidatorsStart(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet, flow: flow
        )
    }
}

extension YourValidatorListPresenter: YourValidatorListInteractorOutputProtocol {}

extension YourValidatorListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}

extension YourValidatorListPresenter: YourValidatorListModelStateListener {
    func didReceiveError(error: Error) {
        logger?.error(error.localizedDescription)
    }

    func handleControllerAccountMissing(_ address: String) {
        guard let view = view else {
            return
        }

        wireframe.presentMissingController(
            from: view,
            address: address,
            locale: selectedLocale
        )
    }

    func modelStateDidChanged(viewModelState _: YourValidatorListViewModelState) {
        updateView()
    }

    func didReceiveError(error: YourValidatorListFlowError) {
        logger?.error(error.localizedDescription)
    }

    func didReceiveState(_ state: YourValidatorListViewState) {
        view?.reload(state: state)
    }
}
