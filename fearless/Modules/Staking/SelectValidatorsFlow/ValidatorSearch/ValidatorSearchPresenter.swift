import SoraFoundation

final class ValidatorSearchPresenter {
    weak var view: ValidatorSearchViewProtocol?
    let wireframe: ValidatorSearchWireframeProtocol
    let interactor: ValidatorSearchInteractorInputProtocol
    let logger: LoggerProtocol?

    private var filteredValidatorList: [ElectedValidatorInfo] = []

    init(
        wireframe: ValidatorSearchWireframeProtocol,
        interactor: ValidatorSearchInteractorInputProtocol,
        localizationManager: LocalizationManager,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        self.localizationManager = localizationManager
    }

    #warning("Not implemented")
}

extension ValidatorSearchPresenter: ValidatorSearchPresenterProtocol {
    func setup() {
        // TODO: provideViewModels()?
        interactor.setup()
    }

    // MARK: - Presenting actions

    func didSelectValidator(at index: Int) {
        let selectedValidator = filteredValidatorList[index]

        let validatorInfo = SelectedValidatorInfo(
            address: selectedValidator.address,
            identity: selectedValidator.identity,
            stakeInfo: ValidatorStakeInfo(
                nominators: selectedValidator.nominators,
                totalStake: selectedValidator.totalStake,
                stakeReturn: selectedValidator.stakeReturn,
                maxNominatorsRewarded: selectedValidator.maxNominatorsRewarded
            )
        )

        wireframe.present(validatorInfo, from: view)
    }
}

extension ValidatorSearchPresenter: ValidatorSearchInteractorOutputProtocol {
    #warning("Not implemented")
}

extension ValidatorSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            // TODO: provideViewModels()?
        }
    }
}
