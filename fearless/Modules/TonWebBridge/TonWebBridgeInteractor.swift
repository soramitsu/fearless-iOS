import UIKit
import SSFModels
import RobinHood

protocol TonWebBridgeInteractorOutput: AnyObject {}

final class TonWebBridgeInteractor {
    // MARK: - Private properties

    private weak var output: TonWebBridgeInteractorOutput?

    private let tonConnectService: TonConnectService
    private let chainRepository: AsyncAnyRepository<ChainModel>

    init(
        tonConnectService: TonConnectService,
        chainRepository: AsyncAnyRepository<ChainModel>
    ) {
        self.tonConnectService = tonConnectService
        self.chainRepository = chainRepository
    }
}

// MARK: - TonWebBridgeInteractorInput

extension TonWebBridgeInteractor: TonWebBridgeInteractorInput {
    func getConnectedApp(for wallet: SSFModels.MetaAccountModel) async throws -> [TonConnectApp] {
        try await tonConnectService.getConnectedApp(for: wallet)
    }

    func connected(app: TonConnectApp) async {
        await tonConnectService.saveConnected(app: app)
    }

    func disconnected(app: TonConnectApp) async {
        await tonConnectService.saveDisconnected(app: app)
    }

    func getTonChain() async throws -> SSFModels.ChainModel? {
        try await chainRepository.fetch(by: "-239", options: RepositoryFetchOptions())
    }

    func fetchManifest(with url: URL) async throws -> TonConnectManifest {
        try await tonConnectService.fetchManifest(with: url)
    }

    func setup(with output: TonWebBridgeInteractorOutput) {
        self.output = output
    }
}
