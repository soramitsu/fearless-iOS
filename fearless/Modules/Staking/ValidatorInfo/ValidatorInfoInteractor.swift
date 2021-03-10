import Foundation

final class ValidatorInfoInteractor {
    weak var presenter: ValidatorInfoInteractorOutputProtocol?
    var validatorInfo: ValidatorInfoProtocol?

    init(validatorInfo: ValidatorInfoProtocol) {
        self.validatorInfo = validatorInfo
    }
}

extension ValidatorInfoInteractor: ValidatorInfoInteractorInputProtocol {
    func setup() {
        guard let validator = validatorInfo else { return }
        presenter?.didReceive(validatorInfo: validator)
    }
}
