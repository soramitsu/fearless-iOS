import Foundation
import SoraFoundation
import FearlessUtils

final class SelectedValidatorsPresenter {
    weak var view: SelectedValidatorsViewProtocol?
    var wireframe: SelectedValidatorsWireframeProtocol!

    let validators: [SelectedValidatorInfo]
    let logger: LoggerProtocol?

    init(validators: [SelectedValidatorInfo],
         logger: LoggerProtocol? = nil) {
        self.validators = validators
        self.logger = logger
    }

    private func providerViewModel() {
        let formatter = NumberFormatter.percent.localizableResource()
        let iconGenerator = PolkadotIconGenerator()

        do {
            let viewModels: [LocalizableResource<SelectedValidatorViewModelProtocol>] =
                try validators.map { validator in
                let icon = try iconGenerator.generateFromAddress(validator.address)
                return LocalizableResource { locale in

                    let details = formatter.value(for: locale)
                        .string(from: validator.stakeReturn as NSNumber) ?? ""
                    let title = validator.identity?.displayName ?? validator.address

                    return SelectedValidatorViewModel(icon: icon,
                                                      title: title,
                                                      details: details)
                }
            }

            view?.didReceive(viewModels: viewModels)
        } catch {
            logger?.debug("Did receive error: \(error)")
        }

    }
}

extension SelectedValidatorsPresenter: SelectedValidatorsPresenterProtocol {
    func setup() {
        providerViewModel()
    }

    func selectedValidatorAt(index: Int) {
        // TODO: FLW-593
    }
}
