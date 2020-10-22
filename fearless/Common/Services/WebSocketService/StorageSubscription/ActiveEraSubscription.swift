import Foundation
import RobinHood

final class ActiveEraSubscription: BaseStorageChildSubscription {
    override func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash: Data?) {
        if case .success(let optionalChange) = result, optionalChange != nil {
            DispatchQueue.main.async {
                self.eventCenter.notify(with: WalletStakingInfoChanged())
            }
        }
    }
}
