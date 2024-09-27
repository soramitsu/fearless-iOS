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

    // MARK: - Constructors

    init(
        interactor: CrossChainTxTrackingInteractorInput,
        router: CrossChainTxTrackingRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: CrossChainTxTrackingViewModelFactory,
        wallet: MetaAccountModel,
        transaction: AssetTransactionData
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.transaction = transaction

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func fetchData() {
        Task {
            let status = try await interactor.queryTransactionStatus()

            if OKXCrossChainTxDetailStatus(rawValue: status.detailStatus) == .success {
                timer?.invalidate()
            }

            guard let sourceChain = try await interactor.queryChain(chainId: status.fromChainId),
                  let destinationChain = try await interactor.queryChain(chainId: status.toChainId) else {
                return
            }

            let sourceChainAssets = try await interactor.fetchChainAssets(chain: sourceChain)
            let destinationChainAssets = try await interactor.fetchChainAssets(chain: destinationChain)

            guard let sourceChainAsset = sourceChainAssets.first(where: { $0.asset.id.lowercased() == status.fromTokenAddress.lowercased() }),
                  let destinationChainAsset = destinationChainAssets.first(where: { $0.asset.id.lowercased() == status.toTokenAddress.lowercased() }) else {
                return
            }

            let viewModel = viewModelFactory.buildViewModel(
                transaction: transaction,
                status: status,
                sourceChainAsset: sourceChainAsset,
                destinationChainAsset: destinationChainAsset,
                locale: selectedLocale,
                wallet: wallet
            )

            await MainActor.run(body: {
                view?.didReceive(viewModel: viewModel)
            })
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
}

// MARK: - CrossChainTxTrackingInteractorOutput

extension CrossChainTxTrackingPresenter: CrossChainTxTrackingInteractorOutput {}

// MARK: - Localizable

extension CrossChainTxTrackingPresenter: Localizable {
    func applyLocalization() {}
}

extension CrossChainTxTrackingPresenter: CrossChainTxTrackingModuleInput {}
