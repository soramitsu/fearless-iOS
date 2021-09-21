import Foundation
import RobinHood

protocol RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>
}
