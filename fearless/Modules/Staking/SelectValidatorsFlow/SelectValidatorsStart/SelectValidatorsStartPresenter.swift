import Foundation
import RobinHood

final class SelectValidatorsStartPresenter {
    weak var view: SelectValidatorsStartViewProtocol?
    private let wireframe: SelectValidatorsStartWireframeProtocol
    private let interactor: SelectValidatorsStartInteractorInputProtocol
    private let logger: LoggerProtocol?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let viewModelState: SelectValidatorsStartViewModelState
    private let viewModelFactory: SelectValidatorsStartViewModelFactoryProtocol
    private var electedValidators: [AccountAddress: ElectedValidatorInfo]?
    private var recommendedValidators: [ElectedValidatorInfo]?
    private var selectedValidators: SharedList<SelectedValidatorInfo>?
    private var maxNominations: Int?

    init(
        interactor: SelectValidatorsStartInteractorInputProtocol,
        wireframe: SelectValidatorsStartWireframeProtocol,
        logger: LoggerProtocol? = nil,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        viewModelState: SelectValidatorsStartViewModelState,
        viewModelFactory: SelectValidatorsStartViewModelFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        self.viewModelState = viewModelState
        self.viewModelFactory = viewModelFactory
    }

    private func updateView() {
        guard
            let maxNominations = maxNominations,
            let selectedValidators = selectedValidators else {
            return
        }

        let viewModel = SelectValidatorsStartViewModel(
            selectedCount: selectedValidators.count,
            totalCount: maxNominations,
            recommendedValidatorListLoaded: !(recommendedValidators?.isEmpty ?? true)
        )

        view?.didReceive(viewModel: viewModel)
    }

    private func handle(error: Error) {
        logger?.error("Did receive error \(error)")

        let locale = view?.localizationManager?.selectedLocale
        if !wireframe.present(error: error, from: view, locale: locale) {
            _ = wireframe.present(
                error: BaseOperationError.unexpectedDependentResult,
                from: view,
                locale: locale
            )
        }
    }
}

extension SelectValidatorsStartPresenter: SelectValidatorsStartPresenterProtocol {
    func setup() {
        interactor.setup()

        viewModelState.setStateListener(self)

        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        if let textsViewModel = viewModelFactory.buildTextsViewModel(locale: locale) {
            view?.didReceive(textsViewModel: textsViewModel)
        }

        view?.didStartLoading()
    }

    func updateOnAppearance() {
        updateView()
    }

    func selectRecommendedValidators() {
        do {
            guard let recommendedValidatorListFlow = try viewModelState.recommendedValidatorListFlow() else {
                return
            }

            wireframe.proceedToRecommendedList(
                from: view,
                flow: recommendedValidatorListFlow,
                wallet: wallet,
                chainAsset: chainAsset
            )
        } catch {
            let locale = view?.localizationManager?.selectedLocale ?? Locale.current
            wireframe.present(error: error, from: view, locale: locale)
        }
    }

    func selectCustomValidators() {
        guard let flow = viewModelState.customValidatorListFlow else {
            return
        }

        wireframe.proceedToCustomList(
            from: view,
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }
}

extension SelectValidatorsStartPresenter: SelectValidatorsStartModelStateListener {
    func didReceiveError(error: Error) {
        handle(error: error)
    }

    func modelStateDidChanged(viewModelState: SelectValidatorsStartViewModelState) {
        let viewModel = viewModelFactory.buildViewModel(viewModelState: viewModelState)
        view?.didReceive(viewModel: viewModel)

        if viewModel != nil {
            view?.didStopLoading()
        }
    }
}

extension SelectValidatorsStartPresenter: SelectValidatorsStartInteractorOutputProtocol {}
