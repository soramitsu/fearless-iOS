import Foundation
import RobinHood
import SSFUtils

public typealias RuntimeMetadataClosure = () throws -> RuntimeMetadata

// sourcery: AutoMockable
public protocol RuntimeCodingServiceProtocol {
    var snapshot: RuntimeSnapshot? { get }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>
    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol
}
