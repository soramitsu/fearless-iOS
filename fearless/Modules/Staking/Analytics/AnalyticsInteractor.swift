import UIKit

final class AnalyticsInteractor {
    weak var presenter: AnalyticsInteractorOutputProtocol!
}

extension AnalyticsInteractor: AnalyticsInteractorInputProtocol {}
