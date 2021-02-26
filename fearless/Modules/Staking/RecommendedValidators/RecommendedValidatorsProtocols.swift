import Foundation

protocol RecommendedValidatorsViewProtocol: ControllerBackedProtocol {}

protocol RecommendedValidatorsPresenterProtocol: class {
    func setup()
}

protocol RecommendedValidatorsInteractorInputProtocol: class {
    func setup()
}

protocol RecommendedValidatorsInteractorOutputProtocol: class {}

protocol RecommendedValidatorsWireframeProtocol: class {}

protocol RecommendedValidatorsViewFactoryProtocol: class {
    static func createView(with stakingState: StartStakingResult) -> RecommendedValidatorsViewProtocol?
}
