import Foundation
import SoraFoundation
import SSFModels

protocol CrossChainTxTrackingViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: CrossChainTxTrackingViewModel)
}

protocol CrossChainTxTrackingInteractorInput: AnyObject {
    func setup(with output: CrossChainTxTrackingInteractorOutput)
    func queryTransactionStatus() async throws -> OKXCrossChainTransactionStatus
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
        print("debug-txs: tx: ", status)

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
            wallet: wallet
        )

        await provideViewModel(viewModel)
    }

    private func handleSwapTransaction(_ status: OKXCrossChainTransactionStatus) async throws {
        print("debug-txs: tx: ", status)
        guard let sourceChain = try await interactor.queryChain(chainId: status.fromChainId) else {
            return
        }
        let okxChainAssets = try await interactor.fetchChainAssets(chain: sourceChain)
        let destinationChainAsset = okxChainAssets.first(where: { $0.asset.id.lowercased() == status.toTokenAddress.lowercased() })

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
                let status = try await interactor.queryTransactionStatus()

                if status.transactionFinished {
                    timer?.invalidate()
                }

                guard !status.transactionFailed else {
                    await handleFailedTransaction(status)
                    return
                }

                let isCrossChain = status.toChainId.isNotEmpty

                print("debug-txs: isCrossChain: ", isCrossChain)
                if isCrossChain {
                    try await handleCrossChainTransaction(status)
                } else {
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
