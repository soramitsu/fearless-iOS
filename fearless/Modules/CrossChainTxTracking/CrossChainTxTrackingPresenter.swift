import Foundation
import SoraFoundation
import SSFModels

protocol CrossChainTxTrackingViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: CrossChainTxTrackingViewModel)
}

protocol CrossChainTxTrackingInteractorInput: AnyObject {
    func setup(with output: CrossChainTxTrackingInteractorOutput)
    func queryCrossChainStatus() async throws -> OKXCrossChainTransactionStatus
    func querySwapStatus() async throws -> OKXSwapTransactionHistoryDetails
    func queryChain(chainId: String) async throws -> ChainModel?
    func fetchChainAssets(chain: ChainModel) async throws -> [ChainAsset]
}

final class CrossChainTxTrackingPresenter {
    // MARK: Private properties

    private weak var view: CrossChainTxTrackingViewInput?
    private let router: CrossChainTxTrackingRouterInput
    private let interactor: CrossChainTxTrackingInteractorInput
    private let viewModelFactory: CrossChainTxTrackingViewModelFactory
    private let wallet: MetaAccountModel
    private let transaction: AssetTransactionData
    private var timer: Timer?
    private let chainAsset: ChainAsset

    // MARK: - Constructors

    init(
        interactor: CrossChainTxTrackingInteractorInput,
        router: CrossChainTxTrackingRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: CrossChainTxTrackingViewModelFactory,
        wallet: MetaAccountModel,
        transaction: AssetTransactionData,
        chainAsset: ChainAsset
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.transaction = transaction
        self.chainAsset = chainAsset

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel(_ viewModel: CrossChainTxTrackingViewModel) async {
        await MainActor.run(body: {
            view?.didStopLoading()
            view?.didReceive(viewModel: viewModel)
        })
    }

    private func handleFailedTransaction(_ status: OKXCrossChainTransactionStatus) async {
        let viewModel = viewModelFactory.buildFailureViewModel(
            transaction: transaction,
            status: status,
            sourceChainAsset: chainAsset,
            locale: selectedLocale,
            wallet: wallet
        )

        await provideViewModel(viewModel)
    }

    private func handleCrossChainTransaction(_ status: OKXCrossChainTransactionStatus) async throws {
        guard
            let sourceChain = try await interactor.queryChain(chainId: status.fromChainId),
            let destinationChain = try await interactor.queryChain(chainId: status.toChainId)
        else {
            return
        }

        let sourceChainAssets = try await interactor.fetchChainAssets(chain: sourceChain)
        try await Task.sleep(nanoseconds: UInt64(1 * Double(NSEC_PER_SEC)))
        let destinationChainAssets = try await interactor.fetchChainAssets(chain: destinationChain)

        guard
            let sourceChainAsset = sourceChainAssets.first(where: { $0.asset.id.lowercased() == status.fromTokenAddress.lowercased() }),
            let destinationChainAsset = destinationChainAssets.first(where: { $0.asset.id.lowercased() == status.toTokenAddress.lowercased() })
        else {
            return
        }

        let viewModel = viewModelFactory.buildCrossChainViewModel(
            transaction: transaction,
            status: status,
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: destinationChainAsset,
            locale: selectedLocale,
            wallet: wallet,
            destinationChainAssets: destinationChainAssets
        )

        await provideViewModel(viewModel)
    }

    private func handleSwapTransaction(_ status: OKXSwapTransactionHistoryDetails) async throws {
        guard let sourceChain = try await interactor.queryChain(chainId: status.chainId) else {
            return
        }
        let okxChainAssets = try await interactor.fetchChainAssets(chain: sourceChain)
        let destinationChainAsset = okxChainAssets.first(where: { $0.asset.id.lowercased() == status.toTokenDetails?.tokenAddress?.lowercased() })

        let viewModel = viewModelFactory.buildSwapViewModel(
            transaction: transaction,
            status: status,
            sourceChainAsset: chainAsset,
            destinationChainAsset: destinationChainAsset,
            locale: selectedLocale,
            wallet: wallet
        )

        await provideViewModel(viewModel)
    }

    private func fetchData() {
        Task {
            do {
                let status = try await interactor.queryCrossChainStatus()

                

                guard !status.transactionFailed else {
                    await handleFailedTransaction(status)
                    return
                }

                let isCrossChain = status.toChainId.isNotEmpty || (transaction.reason?.isNotEmpty).or(false)

                if isCrossChain {
                    if status.transactionFinished {
                        timer?.invalidate()
                    }
                    
                    try await handleCrossChainTransaction(status)
                } else {
                    let status = try await interactor.querySwapStatus()
                    
                    if status.transactionFinished {
                        timer?.invalidate()
                    }
                    
                    try await handleSwapTransaction(status)
                }
            } catch {
                print("fetch tx status error: ", error)
            }
        }
    }

    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { [weak self] _ in
            self?.fetchData()
        })
    }
}

// MARK: - CrossChainTxTrackingViewOutput

extension CrossChainTxTrackingPresenter: CrossChainTxTrackingViewOutput {
    func didLoad(view: CrossChainTxTrackingViewInput) {
        self.view = view
        interactor.setup(with: self)
        fetchData()
        setupTimer()
    }
    
    func viewWillAppear() {
        view?.didStartLoading()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapCopy() {
        router.presentStatus(
            with: CommonCopiedEvent(locale: selectedLocale),
            animated: true
        )
    }
}

// MARK: - CrossChainTxTrackingInteractorOutput

extension CrossChainTxTrackingPresenter: CrossChainTxTrackingInteractorOutput {}

// MARK: - Localizable

extension CrossChainTxTrackingPresenter: Localizable {
    func applyLocalization() {}
}

extension CrossChainTxTrackingPresenter: CrossChainTxTrackingModuleInput {}
