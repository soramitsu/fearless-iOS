import Foundation

final class RecommendedValidatorListPresenter {
    weak var view: RecommendedValidatorListViewProtocol?
    var wireframe: RecommendedValidatorListWireframeProtocol!

    let viewModelFactory: RecommendedValidatorListViewModelFactoryProtocol
    let validators: [SelectedValidatorInfo]
    let maxTargets: Int
    let logger: LoggerProtocol?
    let chain: ChainModel
    let asset: AssetModel
    let selectedAccount: MetaAccountModel

    init(
        viewModelFactory: RecommendedValidatorListViewModelFactoryProtocol,
        validators: [SelectedValidatorInfo],
        maxTargets: Int,
        logger: LoggerProtocol? = nil,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        self.viewModelFactory = viewModelFactory
        self.validators = validators
        self.maxTargets = maxTargets
        self.logger = logger
        self.asset = asset
        self.chain = chain
        self.selectedAccount = selectedAccount
    }

    private func provideViewModel() {
        do {
            let viewModel = try viewModelFactory.createViewModel(
                from: validators,
                maxTargets: maxTargets
            )

            view?.didReceive(viewModel: viewModel)
        } catch {
            logger?.debug("Did receive error: \(error)")
        }
    }
}

extension RecommendedValidatorListPresenter: RecommendedValidatorListPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func selectedValidatorAt(index: Int) {
        let selectedValidator = validators[index]
        wireframe.present(
            asset: asset,
            chain: chain,
            validatorInfo: selectedValidator,
            from: view
        )
    }

    func proceed() {
        wireframe.proceed(
            from: view,
            targets: validators,
            maxTargets: maxTargets,
            selectedAccount: selectedAccount,
            asset: asset,
            chain: chain
        )
    }
}
