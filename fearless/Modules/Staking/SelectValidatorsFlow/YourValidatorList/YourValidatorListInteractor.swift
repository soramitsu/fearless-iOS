import UIKit
import SoraKeystore
import RobinHood
import IrohaCrypto

final class YourValidatorListInteractor: AccountFetching {
    weak var presenter: YourValidatorListInteractorOutputProtocol!

    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let strategy: YourValidatorListStrategy

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: YourValidatorListStrategy
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

extension YourValidatorListInteractor: YourValidatorListInteractorInputProtocol {
    func setup() {
        strategy.setup()
    }

    func refresh() {
        strategy.refresh()
    }
}
