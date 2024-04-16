import Foundation
import RobinHood
import SSFUtils

// typealias RuntimeMetadataClosure = () throws -> RuntimeMetadata
//
// protocol RuntimeCodingServiceProtocol {
//    var snapshot: RuntimeSnapshot? { get }
//
//    func fetchCoderFactoryOperation(
//        with timeout: TimeInterval,
//        closure: RuntimeMetadataClosure?
//    ) -> BaseOperation<RuntimeCoderFactoryProtocol>
//
//    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol
// }
//
// extension RuntimeCodingServiceProtocol {
//    func fetchCoderFactoryOperation(with timeout: TimeInterval) -> BaseOperation<RuntimeCoderFactoryProtocol> {
//        fetchCoderFactoryOperation(with: timeout, closure: nil)
//    }
//
//    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
//        fetchCoderFactoryOperation(with: 20, closure: nil)
//    }
// }
