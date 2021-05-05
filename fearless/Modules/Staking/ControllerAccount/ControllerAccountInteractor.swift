import UIKit
import SoraKeystore
import RobinHood

final class ControllerAccountInteractor {
    weak var presenter: ControllerAccountInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let settings: SettingsManagerProtocol

    private var stashItemProvider: StreamableProvider<StashItem>?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        settings: SettingsManagerProtocol
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.settings = settings
    }
}

extension ControllerAccountInteractor: ControllerAccountInteractorInputProtocol {
    func setup() {
        if let address = settings.selectedAccount?.address {
            stashItemProvider = subscribeToStashItemProvider(for: address)
        }
    }
}

extension ControllerAccountInteractor: SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>) {
        presenter.didReceiveStashItem(result: result)
    }
}
