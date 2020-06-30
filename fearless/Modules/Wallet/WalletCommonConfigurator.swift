import Foundation
import CommonWallet

struct WalletCommonConfigurator {
    func configure(builder: CommonWalletBuilderProtocol) {
        builder
            .with(commandDecoratorFactory: WalletCommandDecoratorFactory())
            .with(logger: Logger.shared)
    }
}
