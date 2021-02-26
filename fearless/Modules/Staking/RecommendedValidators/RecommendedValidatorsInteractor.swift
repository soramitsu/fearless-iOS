import UIKit

final class RecommendedValidatorsInteractor {
    weak var presenter: RecommendedValidatorsInteractorOutputProtocol!
}

extension RecommendedValidatorsInteractor: RecommendedValidatorsInteractorInputProtocol {}