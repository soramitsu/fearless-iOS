import Foundation

final class RecommendedValidatorsPresenter {
    weak var view: RecommendedValidatorsViewProtocol?
    var wireframe: RecommendedValidatorsWireframeProtocol!
    var interactor: RecommendedValidatorsInteractorInputProtocol!
}

extension RecommendedValidatorsPresenter: RecommendedValidatorsPresenterProtocol {
    func setup() {}
}

extension RecommendedValidatorsPresenter: RecommendedValidatorsInteractorOutputProtocol {}