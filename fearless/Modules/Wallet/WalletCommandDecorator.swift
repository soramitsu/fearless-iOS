import Foundation
import CommonWallet

final class StubCommandDecorator: WalletCommandDecoratorProtocol {
    var undelyingCommand: WalletCommandProtocol?

    func execute() throws {}
}

final class WalletCommandDecoratorFactory: WalletCommandDecoratorFactoryProtocol {
    func createSendCommandDecorator(with commandFactory: WalletCommandFactoryProtocol)
        -> WalletCommandDecoratorProtocol? {
        StubCommandDecorator()
    }
    func createReceiveCommandDecorator(with commandFactory: WalletCommandFactoryProtocol)
        -> WalletCommandDecoratorProtocol? {
        StubCommandDecorator()
    }

    func createAssetDetailsDecorator(with commandFactory: WalletCommandFactoryProtocol,
                                     asset: WalletAsset,
                                     balanceData: BalanceData?) -> WalletCommandDecoratorProtocol? {
        StubCommandDecorator()
    }
}
