import Foundation

enum ResponseDecoderType {
    case codable(jsonDecoder: JSONDecoder = JSONDecoder())
    case custom(decoder: any ResponseDecoder)
}
