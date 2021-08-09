import Foundation

final class AnalyticsValidatorsPresenter {
    weak var view: AnalyticsValidatorsViewProtocol?
    let wireframe: AnalyticsValidatorsWireframeProtocol
    let interactor: AnalyticsValidatorsInteractorInputProtocol

    init(
        interactor: AnalyticsValidatorsInteractorInputProtocol,
        wireframe: AnalyticsValidatorsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension AnalyticsValidatorsPresenter: AnalyticsValidatorsPresenterProtocol {
    func setup() {}
}

extension AnalyticsValidatorsPresenter: AnalyticsValidatorsInteractorOutputProtocol {}
