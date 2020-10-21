import Foundation
import RobinHood

final class AccountInfoSubscription: BaseStorageChildSubscription {
    override func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>) {
        logger.debug("Did account info update")

        if case .success(let optionalChange) = result, optionalChange != nil {
            logger.debug("Did change account info")

            DispatchQueue.main.async {
                self.eventCenter.notify(with: WalletBalanceChanged())
            }
        }
    }
}
