import Foundation
import SoraKeystore

final class CrowdloanChainSettings: PersistentValueSettings<ChainModel> {
    let settings: SettingsManagerProtocol
    let operationQueue: OperationQueue

    init(
        storageFacade: StorageFacadeProtocol,
        settings: SettingsManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.settings = settings
        self.operationQueue = operationQueue

        super.init(storageFacade: storageFacade)
    }

    override func performSetup(completionClosure: @escaping (Result<ChainModel?, Error>) -> Void) {
        
    }
}
