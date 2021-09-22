import Foundation
import SoraFoundation
import BigInt

final class CrowdloanListPresenter {
    weak var view: CrowdloanListViewProtocol?
    let wireframe: CrowdloanListWireframeProtocol
    let interactor: CrowdloanListInteractorInputProtocol
    let viewModelFactory: CrowdloansViewModelFactoryProtocol
    let logger: LoggerProtocol?

    private var selectedChainResult: Result<ChainModel, Error>?
    private var accountInfoResult: Result<AccountInfo?, Error>?
    private var crowdloansResult: Result<[Crowdloan], Error>?
    private var displayInfoResult: Result<CrowdloanDisplayInfoDict, Error>?
    private var blockNumber: BlockNumber?
    private var blockDurationResult: Result<BlockTime, Error>?
    private var leasingPeriodResult: Result<LeasingPeriod, Error>?
    private var contributionsResult: Result<CrowdloanContributionDict, Error>?
    private var leaseInfoResult: Result<ParachainLeaseInfoDict, Error>?

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
        view?.didReceive(listState: .error(message: message))
    }

    private func updateChainView() {
        guard let chainResult = selectedChainResult else {
            return
        }

        guard
            case let .success(chain) = chainResult,
            let asset = chain.utilityAssets().first else {
            provideViewErrorState()
            return
        }

        let balance: BigUInt?

        if let accountInfoResult = accountInfoResult {
            balance = (try? accountInfoResult.get()?.data.available) ?? 0
        } else {
            balance = nil
        }

        let viewModel = viewModelFactory.createChainViewModel(
            from: chain,
            asset: asset,
            balance: balance,
            locale: selectedLocale
        )

        view?.didReceive(chainInfo: viewModel)
    }

    private func updateListView() {
        guard let chainResult = selectedChainResult else {
            return
        }

        guard
            case let .success(chain) = chainResult,
            let asset = chain.utilityAssets().first else {
            provideViewErrorState()
            return
        }

        guard
            let crowdloansResult = crowdloansResult,
            let displayInfoResult = displayInfoResult,
            let blockDurationResult = blockDurationResult,
            let leasingPeriodResult = leasingPeriodResult,
            let blockNumber = blockNumber,
            let contributionsResult = contributionsResult,
            let leaseInfoResult = leaseInfoResult else {
            return
        }

        guard
            case let .success(crowdloans) = crowdloansResult,
            case let .success(contributions) = contributionsResult,
            case let .success(leaseInfo) = leaseInfoResult else {
            provideViewErrorState()
            return
        }

        guard !crowdloans.isEmpty else {
            view?.didReceive(listState: .empty)
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

        let viewInfo = CrowdloansViewInfo(
            contributions: contributions,
            leaseInfo: leaseInfo,
            displayInfo: displayInfo,
            metadata: metadata
        )

        let chainAsset = ChainAssetDisplayInfo(asset: asset.displayInfo, chain: chain.conversion)

        let viewModel = viewModelFactory.createViewModel(
            from: crowdloans,
            viewInfo: viewInfo,
            chainAsset: chainAsset,
            locale: selectedLocale
        )

        view?.didReceive(listState: .loaded(viewModel: viewModel))
    }
}

extension CrowdloanListPresenter: CrowdloanListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func refresh(shouldReset: Bool) {
        crowdloansResult = nil

        if shouldReset {
            view?.didReceive(listState: .loading)
        }

        if case .success = selectedChainResult {
            interactor.refresh()
        } else {
            interactor.setup()
        }
    }

    func selectViewModel(_ viewModel: CrowdloanSectionItem<ActiveCrowdloanViewModel>) {
        wireframe.presentContributionSetup(from: view, paraId: viewModel.paraId)
    }

    func becomeOnline() {
        interactor.becomeOnline()
    }

    func putOffline() {
        interactor.putOffline()
    }
}

extension CrowdloanListPresenter: CrowdloanListInteractorOutputProtocol {
    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfoDict, Error>) {
        logger?.info("Did receive display info: \(result)")

        displayInfoResult = result
        updateListView()
    }

    func didReceiveCrowdloans(result: Result<[Crowdloan], Error>) {
        logger?.info("Did receive crowdloans: \(result)")

        crowdloansResult = result
        updateListView()
    }

    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>) {
        switch result {
        case let .success(blockNumber):
            self.blockNumber = blockNumber

            updateListView()
        case let .failure(error):
            logger?.error("Did receivee block number error: \(error)")
        }
    }

    func didReceiveBlockDuration(result: Result<BlockTime, Error>) {
        blockDurationResult = result
        updateListView()
    }

    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>) {
        leasingPeriodResult = result
        updateListView()
    }

    func didReceiveContributions(result: Result<CrowdloanContributionDict, Error>) {
        if case let .failure(error) = result {
            logger?.error("Did receive contributions error: \(error)")
        }

        contributionsResult = result
        updateListView()
    }

    func didReceiveLeaseInfo(result: Result<ParachainLeaseInfoDict, Error>) {
        if case let .failure(error) = result {
            logger?.error("Did receive lease info error: \(error)")
        }

        leaseInfoResult = result
        updateListView()
    }

    func didReceiveSelectedChain(result: Result<ChainModel, Error>) {
        selectedChainResult = result
        updateChainView()
        updateListView()
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        accountInfoResult = result
        updateChainView()
    }
}

extension CrowdloanListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateChainView()
            updateListView()
        }
    }
}
