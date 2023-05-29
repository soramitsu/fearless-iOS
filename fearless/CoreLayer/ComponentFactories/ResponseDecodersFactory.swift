import Foundation
import FearlessUtils

protocol ResponseDecodersFactory {
    func buildResponseDecoder(with type: ResponseDecoderType) -> any ResponseDecoder
}

final class BaseResponseDecoderFactory: ResponseDecodersFactory {
    func buildResponseDecoder(with type: ResponseDecoderType) -> any ResponseDecoder {
        switch type {
        case let .codable(jsonDecoder):
            return JSONResponseDecoder(jsonDecoder: jsonDecoder)
        case let .custom(decoder):
            return decoder
        }
    }
}
