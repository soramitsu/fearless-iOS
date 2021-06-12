import Foundation
import FearlessUtils
import SoraFoundation

final class CustomValidatorListViewModelFactory: CustomValidatorListViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()

    func createViewModel(validators: [ElectedValidatorInfo]) -> [CustomValidatorCellViewModel] {
        let percentageAPYFormatter = NumberFormatter.percentBase.localizableResource()
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

    func createProceedButtonViewModel(for count: Int, maxCount _: Int) ->
        LocalizableResource<CustomValidatorListProceedButtonState> {
        LocalizableResource { locale in
            if count == 0 {
                return .disabled(title: "")
            } else {
                return .enabled(title: R.string.localizable
                    .commonContinue(preferredLanguages: locale.rLanguages))
            }
        }
    }
}

enum CustomValidatorListProceedButtonState {
    case disabled(title: String)
    case enabled(title: String)
}
