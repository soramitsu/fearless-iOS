import Foundation
import SoraFoundation

final class CrowdloanListPresenter {
    weak var view: CrowdloanListViewProtocol?
    let wireframe: CrowdloanListWireframeProtocol
    let interactor: CrowdloanListInteractorInputProtocol
    let viewModelFactory: CrowdloansViewModelFactoryProtocol
    let logger: LoggerProtocol?

    private var crowdloansResult: Result<[Crowdloan], Error>?
    private var displayInfoResult: Result<CrowdloanDisplayInfoDict, Error>?

    init(
        interactor: CrowdloanListInteractorInputProtocol,
        wireframe: CrowdloanListWireframeProtocol,
        viewModelFactory: CrowdloansViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let crowdloansResult = crowdloansResult, let displayInfoResult = displayInfoResult else {
            view?.didReceive(state: .loading)
            return
        }

        guard case let .success(crowdloans) = crowdloansResult else {
            let message = R.string.localizable
                .commonErrorNoDataRetrieved(preferredLanguages: selectedLocale.rLanguages)
            view?.didReceive(state: .error(message: message))
            return
        }

        guard !crowdloans.isEmpty else {
            view?.didReceive(state: .empty)
            return
        }

        let displayInfo = try? displayInfoResult.get()

        let viewModel = viewModelFactory.createViewModel(
            from: crowdloans,
            displayInfo: displayInfo,
            locale: selectedLocale
        )

        view?.didReceive(state: .loaded(viewModel: viewModel))
    }
}

extension CrowdloanListPresenter: CrowdloanListPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()
    }

    func refresh() {
        crowdloansResult = nil

        updateView()

        interactor.refresh()
    }
}

extension CrowdloanListPresenter: CrowdloanListInteractorOutputProtocol {
    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfoDict, Error>) {
        logger?.info("Did receive display info: \(result)")

        displayInfoResult = result
        updateView()
    }

    func didReceiveCrowdloans(result: Result<[Crowdloan], Error>) {
        logger?.info("Did receive crowdloans: \(result)")

        crowdloansResult = result
        updateView()
    }
}

extension CrowdloanListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
