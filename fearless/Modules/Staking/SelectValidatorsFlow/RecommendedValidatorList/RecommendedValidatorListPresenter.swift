import Foundation

final class RecommendedValidatorListPresenter: RecommendedValidatorListModelStateListener {
    weak var view: RecommendedValidatorListViewProtocol?
    var wireframe: RecommendedValidatorListWireframeProtocol!

    let viewModelFactory: RecommendedValidatorListViewModelFactoryProtocol
    let viewModelState: RecommendedValidatorListViewModelState
    let logger: LoggerProtocol?
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel

    init(
        viewModelFactory: RecommendedValidatorListViewModelFactoryProtocol,
        viewModelState: RecommendedValidatorListViewModelState,
        logger: LoggerProtocol? = nil,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.viewModelFactory = viewModelFactory
        self.viewModelState = viewModelState
        self.logger = logger
        self.chainAsset = chainAsset
        self.wallet = wallet
    }

    func modelStateDidChanged(viewModelState _: RecommendedValidatorListViewModelState) {
        provideViewModel()
    }

    private func provideViewModel() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        guard let viewModel = viewModelFactory.buildViewModel(viewModelState: viewModelState, locale: locale) else {
            return
        }
        view?.didReceive(viewModel: viewModel)
    }
}

extension RecommendedValidatorListPresenter: RecommendedValidatorListPresenterProtocol {
    func setup() {
        viewModelState.setStateListener(self)

        provideViewModel()
    }

    func showValidatorInfoAt(index: Int) {
        guard let flow = viewModelState.validatorInfoFlow(validatorIndex: index) else {
            return
        }

        wireframe.present(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet,
            from: view
        )
    }

    func selectedValidatorAt(index: Int) {
        if viewModelState.shouldSelectValidatorAt(index: index) {
            return
        }
    }

    func proceed() {
        guard let flow = viewModelState.selectValidatorsConfirmFlow() else {
            return
        }

        wireframe.proceed(
            from: view,
            flow: flow,
            wallet: wallet,
            chainAsset: chainAsset
        )
    }
}
