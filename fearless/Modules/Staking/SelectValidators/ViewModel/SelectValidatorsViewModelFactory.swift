import Foundation
import FearlessUtils

final class SelectValidatorsViewModelFactory: SelectValidatorsViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()

    func createViewModel(validators: [ElectedValidatorInfo]) -> [SelectValidatorsCellViewModel] {
        let percentageAPYFormatter = NumberFormatter.percent.localizableResource()
        return validators.map { validator in
            let icon = try? self.iconGenerator.generateFromAddress(validator.address)
            let restakePercentage = percentageAPYFormatter
                .value(for: .current) // TODO: return LocalizebleRes<[SelectValidatorsCellViewModel]>
                .string(from: validator.stakeReturn as NSNumber)
            return SelectValidatorsCellViewModel(
                icon: icon,
                name: validator.identity?.displayName ?? validator.address,
                apyPercentage: restakePercentage
            )
        }
    }
}
