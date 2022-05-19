import Foundation

final class RecommendedValidatorListPresenter {
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

    private func provideViewModel() {
        if let viewModel = viewModelFactory.buildViewModel(viewModelState: viewModelState) {
            view?.didReceive(viewModel: viewModel)
        }
    }
}

extension RecommendedValidatorListPresenter: RecommendedValidatorListPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func selectedValidatorAt(index: Int) {
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

    func proceed() {
        // TODO: Transition with new parameters

//        wireframe.proceed(
//            from: view,
//            targets: validators,
//            maxTargets: maxTargets,
//            selectedAccount: selectedAccount,
//            asset: asset,
//            chain: chain
//        )
    }
}
