import UIKit

final class AnalyticsValidatorsInteractor {
    weak var presenter: AnalyticsValidatorsInteractorOutputProtocol!
}

extension AnalyticsValidatorsInteractor: AnalyticsValidatorsInteractorInputProtocol {}
