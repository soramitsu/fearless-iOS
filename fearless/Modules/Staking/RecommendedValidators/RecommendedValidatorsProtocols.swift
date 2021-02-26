import Foundation

protocol RecommendedValidatorsViewProtocol: class {}

protocol RecommendedValidatorsPresenterProtocol: class {
    func setup()
}

protocol RecommendedValidatorsInteractorInputProtocol: class {}

protocol RecommendedValidatorsInteractorOutputProtocol: class {}

protocol RecommendedValidatorsWireframeProtocol: class {}

protocol RecommendedValidatorsViewFactoryProtocol: class {
	static func createView() -> RecommendedValidatorsViewProtocol?
}
