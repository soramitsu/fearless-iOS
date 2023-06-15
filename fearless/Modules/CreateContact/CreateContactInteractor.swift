import UIKit
import SSFModels

final class CreateContactInteractor {
    // MARK: - Private properties

    private weak var output: CreateContactInteractorOutput?
}

// MARK: - CreateContactInteractorInput

extension CreateContactInteractor: CreateContactInteractorInput {
    func validate(address: String, for chain: ChainModel) -> Bool {
        ((try? AddressFactory.accountId(from: address, chain: chain)) != nil)
    }

    func setup(with output: CreateContactInteractorOutput) {
        self.output = output
    }
}
