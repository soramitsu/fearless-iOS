import Foundation
import FearlessUtils

final class SelectValidatorsViewModelFactory: SelectValidatorsViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()

    func createViewModel(validators: [ElectedValidatorInfo]) -> [SelectValidatorsCellViewModel] {
        validators.map { validator in
            let icon = try? self.iconGenerator.generateFromAddress(validator.address)
            return SelectValidatorsCellViewModel(
                icon: icon,
                name: validator.identity?.displayName ?? validator.address,
                apy: "17.2%"
            )
        }
    }
}
