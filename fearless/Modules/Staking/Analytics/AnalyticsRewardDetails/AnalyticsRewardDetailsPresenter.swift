import Foundation

final class AnalyticsRewardDetailsPresenter {
    weak var view: AnalyticsRewardDetailsViewProtocol?
    let wireframe: AnalyticsRewardDetailsWireframeProtocol
    let interactor: AnalyticsRewardDetailsInteractorInputProtocol

    init(
        interactor: AnalyticsRewardDetailsInteractorInputProtocol,
        wireframe: AnalyticsRewardDetailsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension AnalyticsRewardDetailsPresenter: AnalyticsRewardDetailsPresenterProtocol {
    func setup() {}
}

extension AnalyticsRewardDetailsPresenter: AnalyticsRewardDetailsInteractorOutputProtocol {}
