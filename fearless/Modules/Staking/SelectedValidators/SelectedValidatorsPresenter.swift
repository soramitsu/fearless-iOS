import Foundation
import SoraFoundation
import FearlessUtils

final class SelectedValidatorsPresenter {
    weak var view: SelectedValidatorsViewProtocol?
    var wireframe: SelectedValidatorsWireframeProtocol!

    let validators: [SelectedValidatorInfo]
    let maxTargets: Int
    let logger: LoggerProtocol?

    init(validators: [SelectedValidatorInfo],
         maxTargets: Int,
         logger: LoggerProtocol? = nil) {
        self.validators = validators
        self.maxTargets = maxTargets
        self.logger = logger
    }

    private func providerViewModel() {
        let iconGenerator = PolkadotIconGenerator()

        do {
            let items: [SelectedValidatorViewModelProtocol] =
                try validators.map { validator in
                    let icon = try iconGenerator.generateFromAddress(validator.address)
                    let title = validator.identity?.displayName ?? validator.address

                    return SelectedValidatorViewModel(icon: icon,
                                                      title: title,
                                                      details: "")
                }

            let viewModel = SelectedValidatorsViewModel(maxTargets: maxTargets,
                                                        itemViewModels: items)

            view?.didReceive(viewModel: viewModel)
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
