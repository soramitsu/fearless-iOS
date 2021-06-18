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
    private var blockNumber: BlockNumber?
    private var blockDurationResult: Result<BlockTime, Error>?
    private var leasingPeriodResult: Result<LeasingPeriod, Error>?
    private var contributions: CrowdloanContributionDict?

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

    private func provideViewErrorState() {
        let message = R.string.localizable
            .commonErrorNoDataRetrieved(preferredLanguages: selectedLocale.rLanguages)
        view?.didReceive(state: .error(message: message))
    }

    private func updateView() {
        guard
            let crowdloansResult = crowdloansResult,
            let displayInfoResult = displayInfoResult,
            let blockDurationResult = blockDurationResult,
            let leasingPeriodResult = leasingPeriodResult,
            let blockNumber = blockNumber else {
            return
        }

        guard
            case let .success(crowdloans) = crowdloansResult else {
            provideViewErrorState()
            return
        }

        guard !crowdloans.isEmpty else {
            view?.didReceive(state: .empty)
            return
        }

        guard
            case let .success(blockDuration) = blockDurationResult,
            case let .success(leasingPeriod) = leasingPeriodResult else {
            provideViewErrorState()
            return
        }

        let displayInfo = try? displayInfoResult.get()

        let metadata = CrowdloanMetadata(
            blockNumber: blockNumber,
            blockDuration: blockDuration,
            leasingPeriod: leasingPeriod
        )

        let viewModel = viewModelFactory.createViewModel(
            from: crowdloans,
            contributions: contributions,
            displayInfo: displayInfo,
            metadata: metadata,
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

    func refresh(shouldReset: Bool) {
        crowdloansResult = nil

        if shouldReset {
            view?.didReceive(state: .loading)
        }

        interactor.refresh()
    }

    func selectViewModel(_ viewModel: CrowdloanSectionItem<ActiveCrowdloanViewModel>) {
        wireframe.presentContributionSetup(from: view, paraId: viewModel.paraId)
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

    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>) {
        switch result {
        case let .success(blockNumber):
            self.blockNumber = blockNumber
            updateView()
        case let .failure(error):
            logger?.error("Did receivee block number error: \(error)")
        }
    }

    func didReceiveBlockDuration(result: Result<BlockTime, Error>) {
        blockDurationResult = result
        updateView()
    }

    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>) {
        leasingPeriodResult = result
        updateView()
    }

    func didReceiveContributions(result: Result<CrowdloanContributionDict, Error>) {
        switch result {
        case let .success(contributions):
            self.contributions = contributions
        case let .failure(error):
            contributions = nil

            logger?.error("Did receive error: \(error)")
        }

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
