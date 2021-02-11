import Foundation
import RobinHood

protocol RuntimeRegistryServiceProtocol {
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>

    func update(to chain: Chain)
}
