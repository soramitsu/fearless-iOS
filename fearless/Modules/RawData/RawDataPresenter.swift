import Foundation
import SoraFoundation

protocol RawDataViewInput: ControllerBackedProtocol {}

protocol RawDataInteractorInput: AnyObject {
    func setup(with output: RawDataInteractorOutput)
}

final class RawDataPresenter {
    // MARK: Private properties

    private weak var view: RawDataViewInput?
    private let router: RawDataRouterInput
    private let interactor: RawDataInteractorInput

    // MARK: - Constructors

    init(
        interactor: RawDataInteractorInput,
        router: RawDataRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - RawDataViewOutput

extension RawDataPresenter: RawDataViewOutput {
    func close() {
        router.dismiss(view: view)
    }

    func didLoad(view: RawDataViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - RawDataInteractorOutput

extension RawDataPresenter: RawDataInteractorOutput {}

// MARK: - Localizable

extension RawDataPresenter: Localizable {
    func applyLocalization() {}
}

extension RawDataPresenter: RawDataModuleInput {}
