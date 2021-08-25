import Foundation

final class AnalyticsRewardDetailsPresenter {
    weak var view: AnalyticsRewardDetailsViewProtocol?
    private let wireframe: AnalyticsRewardDetailsWireframeProtocol
    private let interactor: AnalyticsRewardDetailsInteractorInputProtocol
    private let viewModelFactory: AnalyticsRewardDetailsViewModelFactoryProtocol
    private let rewardModel: AnalyticsRewardDetailsModel

    init(
        rewardModel: AnalyticsRewardDetailsModel,
        interactor: AnalyticsRewardDetailsInteractorInputProtocol,
        wireframe: AnalyticsRewardDetailsWireframeProtocol,
        viewModelFactory: AnalyticsRewardDetailsViewModelFactoryProtocol
    ) {
        self.rewardModel = rewardModel
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }
}

extension AnalyticsRewardDetailsPresenter: AnalyticsRewardDetailsPresenterProtocol {
    func setup() {
        let viewModel = viewModelFactory.createViweModel(rewardModel: rewardModel)
        view?.bind(viewModel: viewModel)
    }
}

extension AnalyticsRewardDetailsPresenter: AnalyticsRewardDetailsInteractorOutputProtocol {}
