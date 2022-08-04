import UIKit

final class WalletOptionInteractor {
    // MARK: - Private properties
    private let wallet: ManagedMetaAccountModel
    
    init(wallet: ManagedMetaAccountModel) {
        self.wallet = wallet
    }

    private weak var output: WalletOptionInteractorOutput?
}

// MARK: - WalletOptionInteractorInput

extension WalletOptionInteractor: WalletOptionInteractorInput {
    func setup(with output: WalletOptionInteractorOutput) {
        self.output = output
    }
}
