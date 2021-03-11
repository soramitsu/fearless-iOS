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
        let iconGenerator = PolkadotIconGenerator()

        do {
            let viewModels: [LocalizableResource<SelectedValidatorViewModelProtocol>] =
                try validators.map { validator in
                    let icon = try iconGenerator.generateFromAddress(validator.address)
                    return LocalizableResource { _ in
                        let title = validator.identity?.displayName ?? validator.address

                        return SelectedValidatorViewModel(icon: icon,
                                                          title: title,
                                                          details: "")
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
        let selectedValidator = validators[index]
        wireframe.showInformation(about: selectedValidator,
                                  from: view)
    }
}
