import Foundation
import SoraFoundation
import SwiftUI
import SoraKeystore

final class CrowdloanListPresenter {
    weak var view: CrowdloanListViewProtocol?
    let wireframe: CrowdloanListWireframeProtocol
    let interactor: CrowdloanListInteractorInputProtocol
    let viewModelFactory: CrowdloansViewModelFactoryProtocol
    let logger: LoggerProtocol?
    private weak var moduleOutput: CrowdloanListModuleOutput?
    private var settings: SettingsManagerProtocol

    private var crowdloansResult: Result<[Crowdloan], Error>?
    private var displayInfoResult: Result<CrowdloanDisplayInfoDict, Error>?
    private var blockNumber: BlockNumber?
    private var blockDurationResult: Result<BlockTime, Error>?
    private var leasingPeriodResult: Result<LeasingPeriod, Error>?
    private var contributionsResult: Result<CrowdloanContributionDict, Error>?
    private var leaseInfoResult: Result<ParachainLeaseInfoDict, Error>?
    private var failedMemosResult: Result<[ParaId: String], Error>?

    init(
        interactor: CrowdloanListInteractorInputProtocol,
        wireframe: CrowdloanListWireframeProtocol,
        viewModelFactory: CrowdloansViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil,
        moduleOutput: CrowdloanListModuleOutput?,
        settings: SettingsManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.settings = settings
        self.localizationManager = localizationManager
        self.moduleOutput = moduleOutput
    }

    private func provideViewErrorState() {
        let message = R.string.localizable
            .commonErrorNoDataRetrieved(preferredLanguages: selectedLocale.rLanguages)
        view?.didReceive(state: .error(message: message))
    }

    private func updateView() {
        guard let displayInfoResult = displayInfoResult,
              let crowdloansResult = crowdloansResult,
              let contributionsResult = contributionsResult,
              let failedMemosResult = failedMemosResult else {
            return
        }

        guard
            case let .success(crowdloans) = crowdloansResult,
            case let .success(contributions) = contributionsResult else {
            provideViewErrorState()
            return
        }

        let contributionsByParaIds = contributions.compactMap { trieIndex, contribution in
            guard let crowdloan = crowdloans.first(where: { currentCrowdloan in
                currentCrowdloan.fundInfo.trieIndex == trieIndex
            }) else {
                return nil
            }

            return [crowdloan.paraId: contribution]
        }
        .reduce(into: [:]) { result, next in
            result.merge(next) { _, rhs in rhs }
        } as? [ParaId: CrowdloanContribution]

        let displayInfo = try? displayInfoResult.get()
        let supportedParaIds = displayInfo?.filter { dict in
            if let flow = dict.value.flow, case .moonbeam = flow { return true }
            return false
        }.map(\.key)

        let failedMemos = try? failedMemosResult.get()
            .filter { supportedParaIds?.contains($0.key) == true }
            .filter { contributionsByParaIds?[$0.key]?.balance ?? 0 > 0 }

        view?.didReceive(tabBarNotifications: failedMemos?.isEmpty == false)

        if failedMemos?.isEmpty == false {
            settings.saveReferralEthereumAddressForSelectedAccount(ethereumAccountAddress: nil)

            moduleOutput?.didReceiveFailedMemos()
        }

        guard
            let blockDurationResult = blockDurationResult,
            let leasingPeriodResult = leasingPeriodResult,
            let blockNumber = blockNumber,
            let leaseInfoResult = leaseInfoResult else {
            return
        }

        guard
            case let .success(leaseInfo) = leaseInfoResult else {
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

        let metadata = CrowdloanMetadata(
            blockNumber: blockNumber,
            blockDuration: blockDuration,
            leasingPeriod: leasingPeriod
        )

        let viewModel = viewModelFactory.createViewModel(
            from: crowdloans,
            contributions: contributions,
            leaseInfo: leaseInfo,
            displayInfo: displayInfo,
            metadata: metadata,
            locale: selectedLocale,
            failedMemos: failedMemos
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
        let crowdloanDisplayInfo: CrowdloanDisplayInfo? = try? displayInfoResult?
            .get()
            .first(where: { key, _ in key == viewModel.paraId })?
            .value

        var customFlow: CustomCrowdloanFlow? = crowdloanDisplayInfo?.flowIfSupported

        if let failedMemo = viewModel.content.failedMemo {
            customFlow = .moonbeamMemoFix(failedMemo)
        }

        if let customFlow = customFlow {
            switch customFlow {
            case .moonbeam:
                wireframe.presentAgreement(
                    from: view,
                    paraId: viewModel.paraId,
                    customFlow: customFlow
                )
            default:
                wireframe.presentContributionSetup(
                    from: view,
                    paraId: viewModel.paraId,
                    customFlow: customFlow
                )
            }
        } else {
            wireframe.presentContributionSetup(
                from: view,
                paraId: viewModel.paraId,
                customFlow: nil
            )
        }
    }

    func becomeOnline() {
        interactor.becomeOnline()
    }

    func putOffline() {
        interactor.putOffline()
    }
}

extension CrowdloanListPresenter: CrowdloanListInteractorOutputProtocol {
    func didReceiveFailedMemos(result: Result<[ParaId: String], Error>) {
        logger?.info("Did receive failed memos: \(result)")

        failedMemosResult = result
        updateView()
    }

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
        if case let .failure(error) = result {
            logger?.error("Did receive contributions error: \(error)")
        }

        contributionsResult = result
        updateView()
    }

    func didReceiveLeaseInfo(result: Result<ParachainLeaseInfoDict, Error>) {
        if case let .failure(error) = result {
            logger?.error("Did receive lease info error: \(error)")
        }

        leaseInfoResult = result
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
