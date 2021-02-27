import Foundation

final class RecommendedValidatorsPresenter {
    weak var view: RecommendedValidatorsViewProtocol?
    var wireframe: RecommendedValidatorsWireframeProtocol!
    var interactor: RecommendedValidatorsInteractorInputProtocol!

    let logger: LoggerProtocol?

    var allValidators: [ElectedValidatorInfo]?
    var recommended: [ElectedValidatorInfo]?

    init(logger: LoggerProtocol? = nil) {
        self.logger = logger
    }

    private func updateView() {}
}

extension RecommendedValidatorsPresenter: RecommendedValidatorsPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension RecommendedValidatorsPresenter: RecommendedValidatorsInteractorOutputProtocol {
    func didReceive(validators: [ElectedValidatorInfo]) {
        allValidators = validators

        recommended = validators
            .filter { $0.hasIdentity && !$0.hasSlashes && !$0.oversubscribed}
            .sorted(by: { $0.stakeReturnPer >= $1.stakeReturnPer })
    }

    func didReceive(error: Error) {
        logger?.error("Did receive error \(error)")
    }
}
