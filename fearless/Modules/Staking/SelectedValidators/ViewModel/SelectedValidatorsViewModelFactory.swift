import Foundation
import FearlessUtils
import SoraFoundation

protocol SelectedValidatorsViewModelFactoryProtocol {
    func createViewModel(
        from validators: [SelectedValidatorInfo],
        maxTargets: Int
    ) throws -> SelectedValidatorsViewModelProtocol
}

final class SelectedValidatorsViewModelFactory {
    private let iconGenerator: IconGenerating

    init(
        iconGenerator: IconGenerating
    ) {
        self.iconGenerator = iconGenerator
    }

    private func createStakeReturnString(from stakeReturn: Decimal?) -> LocalizableResource<String> {
        LocalizableResource { locale in
            guard let stakeReturn = stakeReturn else { return "" }

            let percentageFormatter = NumberFormatter.percentBase.localizableResource().value(for: locale)

            return percentageFormatter.string(from: stakeReturn as NSNumber) ?? ""
        }
    }
}

extension SelectedValidatorsViewModelFactory: SelectedValidatorsViewModelFactoryProtocol {
    func createViewModel(
        from validators: [SelectedValidatorInfo],
        maxTargets: Int
    ) throws -> SelectedValidatorsViewModelProtocol {
        let items: [LocalizableResource<SelectedValidatorViewModelProtocol>] =
            try validators.map { validator in
                let icon = try iconGenerator.generateFromAddress(validator.address)
                let title = validator.identity?.displayName ?? validator.address

                let details = createStakeReturnString(from: validator.stakeInfo?.stakeReturn)

                return LocalizableResource { locale in
                    SelectedValidatorViewModel(
                        icon: icon,
                        title: title,
                        details: details.value(for: locale)
                    )
                }
            }

        return SelectedValidatorsViewModel(
            maxTargets: maxTargets,
            itemViewModels: items
        )
    }
}
