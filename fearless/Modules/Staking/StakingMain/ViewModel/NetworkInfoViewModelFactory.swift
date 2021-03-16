import Foundation
import SoraFoundation

protocol NetworkInfoViewModelFactoryProtocol {
    func createChainViewModel() -> LocalizableResource<String>
}

final class NetworkInfoViewModelFactory: NetworkInfoViewModelFactoryProtocol {
    let chain: Chain

    init(with chain: Chain) {
        self.chain = chain
    }

    func createChainViewModel() -> LocalizableResource<String> {
        LocalizableResource { locale in
            return self.chain.addressType.titleForLocale(locale)
        }
    }
}
