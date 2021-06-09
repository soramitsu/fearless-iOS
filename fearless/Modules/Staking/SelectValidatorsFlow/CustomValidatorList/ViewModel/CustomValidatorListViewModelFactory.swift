import Foundation
import FearlessUtils

final class CustomValidatorListViewModelFactory: CustomValidatorListViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()

    func createViewModel(validators: [ElectedValidatorInfo]) -> [CustomValidatorCellViewModel] {
        let percentageAPYFormatter = NumberFormatter.percent.localizableResource()
        return validators.map { validator in
            let icon = try? self.iconGenerator.generateFromAddress(validator.address)
            let restakePercentage = percentageAPYFormatter
                .value(for: .current) // TODO: return LocalizebleRes<[SelectValidatorsCellViewModel]>
                .string(from: validator.stakeReturn as NSNumber)
            return CustomValidatorCellViewModel(
                icon: icon,
                name: validator.identity?.displayName ?? validator.address,
                apyPercentage: restakePercentage
            )
        }
    }
}
