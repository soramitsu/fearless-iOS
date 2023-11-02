import Foundation
import SoraFoundation
import SSFUtils

protocol RawDataViewInput: ControllerBackedProtocol {
    func didReceive(text: String)
}

protocol RawDataInteractorInput: AnyObject {
    func setup(with output: RawDataInteractorOutput)
}

final class RawDataPresenter {
    // MARK: Private properties

    private weak var view: RawDataViewInput?
    private let router: RawDataRouterInput
    private let interactor: RawDataInteractorInput

    private let json: JSON

    // MARK: - Constructors

    init(
        json: JSON,
        interactor: RawDataInteractorInput,
        router: RawDataRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.json = json
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func providePrettyPrintedJson() {
        if case let .stringValue(value) = json {
            view?.didReceive(text: value)
        } else {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(json)
                guard let displayString = String(data: data, encoding: .utf8) else {
                    return
                }
                view?.didReceive(text: displayString)
            } catch {
                router.present(error: error, from: view, locale: selectedLocale)
            }
        }
    }
}

// MARK: - RawDataViewOutput

extension RawDataPresenter: RawDataViewOutput {
    func close() {
        router.dismiss(view: view)
    }

    func didLoad(view: RawDataViewInput) {
        self.view = view
        interactor.setup(with: self)
        providePrettyPrintedJson()
    }
}

// MARK: - RawDataInteractorOutput

extension RawDataPresenter: RawDataInteractorOutput {}

// MARK: - Localizable

extension RawDataPresenter: Localizable {
    func applyLocalization() {}
}

extension RawDataPresenter: RawDataModuleInput {}
