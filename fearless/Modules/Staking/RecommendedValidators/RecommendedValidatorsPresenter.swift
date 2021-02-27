import Foundation

final class RecommendedValidatorsPresenter {
    weak var view: RecommendedValidatorsViewProtocol?
    var wireframe: RecommendedValidatorsWireframeProtocol!
    var interactor: RecommendedValidatorsInteractorInputProtocol!

    let logger: LoggerProtocol?

    init(logger: LoggerProtocol? = nil) {
        self.logger = logger
    }
}

extension RecommendedValidatorsPresenter: RecommendedValidatorsPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension RecommendedValidatorsPresenter: RecommendedValidatorsInteractorOutputProtocol {
    func didReceive(validators: [ElectedValidatorInfo]) {
        let slashedCount = validators.filter { $0.hasSlashes }.count

        logger?.debug("Slashed count \(slashedCount) of \(validators.count)")

        let oversubscribedCount = validators.filter { $0.oversubscribed }.count
        logger?.debug("Oversubscribed count \(oversubscribedCount) of \(validators.count)")

        let minStakeNominator = validators.flatMap { $0.nominators }.min(by: { $0.stake < $1.stake })
        logger?.debug("Minimal stake \(minStakeNominator?.stake ?? 0.0)")
    }

    func didReceive(error: Error) {
        logger?.error("Did receive error \(error)")
    }
}
