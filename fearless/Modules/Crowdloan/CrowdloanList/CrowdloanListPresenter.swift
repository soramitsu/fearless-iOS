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

    private func createMetadataResult() -> Result<CrowdloanMetadata, Error>? {
        guard
            let blockDurationResult = blockDurationResult,
            let leasingPeriodResult = leasingPeriodResult,
            let blockNumber = blockNumber else {
            return nil
        }

        do {
            let blockDuration = try blockDurationResult.get()
            let leasingPeriod = try leasingPeriodResult.get()

            let metadata = CrowdloanMetadata(
                blockNumber: blockNumber,
                blockDuration: blockDuration,
                leasingPeriod: leasingPeriod
            )

            return .success(metadata)
        } catch {
            return .failure(error)
        }
    }

    private func createViewInfoResult() -> Result<CrowdloansViewInfo, Error>? {
        guard
            let displayInfoResult = displayInfoResult,
            let metadataResult = createMetadataResult(),
            let contributionsResult = contributionsResult,
            let leaseInfoResult = leaseInfoResult else {
            return nil
        }

        do {
            let contributions = try contributionsResult.get()
            let leaseInfo = try leaseInfoResult.get()
            let metadata = try metadataResult.get()
            let displayInfo = try? displayInfoResult.get()

            let viewInfo = CrowdloansViewInfo(
                contributions: contributions,
                leaseInfo: leaseInfo,
                displayInfo: displayInfo,
                metadata: metadata
            )

            return .success(viewInfo)
        } catch {
            return .failure(error)
        }
    }

    private func updateListView() {
        guard let chainResult = selectedChainResult else {
            return
        }

        guard case let .success(chain) = chainResult, let asset = chain.utilityAssets().first else {
            provideViewErrorState()
            return
        }

        guard
            let crowdloansResult = crowdloansResult,
            let viewInfoResult = createViewInfoResult() else {
            return
        }

        do {
            let crowdloans = try crowdloansResult.get()

            guard !crowdloans.isEmpty else {
                view?.didReceive(listState: .empty)
                return
            }

            let viewInfo = try viewInfoResult.get()

            let chainAsset = ChainAssetDisplayInfo(asset: asset.displayInfo, chain: chain.chainFormat)

            let viewModel = viewModelFactory.createViewModel(
                from: crowdloans,
                viewInfo: viewInfo,
                chainAsset: chainAsset,
                locale: selectedLocale
            )

            view?.didReceive(listState: .loaded(viewModel: viewModel))
        } catch {
            provideViewErrorState()
        }
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

    func selectChain() {
        let chainId = try? selectedChainResult?.get().chainId

        wireframe.selectChain(
            from: view,
            delegate: self,
            selectedChainId: chainId
        )
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

extension CrowdloanListPresenter: ChainSelectionDelegate {
    func chainSelection(view _: ChainSelectionViewProtocol, didCompleteWith chain: ChainModel) {
        selectedChainResult = .success(chain)
        accountInfoResult = nil
        crowdloansResult = nil
        displayInfoResult = nil
        blockNumber = nil
        blockDurationResult = nil
        leasingPeriodResult = nil
        contributionsResult = nil
        leaseInfoResult = nil

        updateChainView()
        view?.didReceive(listState: .loading)

        interactor.saveSelected(chainModel: chain)
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
