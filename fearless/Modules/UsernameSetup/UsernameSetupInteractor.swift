import Foundation

final class UsernameSetupInteractor {
    weak var presenter: UsernameSetupInteractorOutputProtocol!

    let supportedNetworkTypes: [Chain]
    let defaultNetwork: Chain

    init(
        supportedNetworkTypes: [Chain],
        defaultNetwork: Chain
    ) {
        self.supportedNetworkTypes = supportedNetworkTypes
        self.defaultNetwork = defaultNetwork
    }
}

extension UsernameSetupInteractor: UsernameSetupInteractorInputProtocol {
    func setup() {
        let metadata = UsernameSetupMetadata(
            availableNetworks: supportedNetworkTypes,
            defaultNetwork: defaultNetwork
        )

        presenter.didReceive(metadata: metadata)
    }
}
