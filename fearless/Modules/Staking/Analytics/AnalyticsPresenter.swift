import Foundation

final class AnalyticsPresenter {
    weak var view: AnalyticsViewProtocol?
    let wireframe: AnalyticsWireframeProtocol
    let interactor: AnalyticsInteractorInputProtocol

    init(
        interactor: AnalyticsInteractorInputProtocol,
        wireframe: AnalyticsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension AnalyticsPresenter: AnalyticsPresenterProtocol {
    func setup() {}
}

extension AnalyticsPresenter: AnalyticsInteractorOutputProtocol {}
