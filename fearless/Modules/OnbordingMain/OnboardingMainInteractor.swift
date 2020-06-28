import Foundation
import RobinHood
import SoraKeystore

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainOutputInteractorProtocol?

    var logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

}

extension OnboardingMainInteractor: OnboardingMainInputInteractorProtocol {
    func setup() {}

    func signup() {}
}
