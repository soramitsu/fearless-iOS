import Foundation
import RobinHood
import FearlessUtils

typealias RuntimeMetadataClosure = () throws -> RuntimeMetadata

protocol RuntimeRegistryServiceProtocol: ApplicationServiceProtocol {
    func update(to chain: Chain)
}
