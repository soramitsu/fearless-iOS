import Foundation
import FearlessUtils

protocol RuntimeCoderFactoryProtocol {
    func createEncoder() -> DynamicScaleEncoding
    func createDecoder(from data: Data) -> DynamicScaleDecoding
}
