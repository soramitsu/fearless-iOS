import Foundation
import SSFUtils

struct SolomonQRInfo: QRInfo {
    var address: String
}

final class SolomonQRDecoder: QRDecodable {
    static let url = URL(string: "https://mekongdebug.page.link")
    static let addressQuery = "wallAdd"

    func decode(data: Data) throws -> QRInfo {
        guard
            let urlRepresentation = URL(dataRepresentation: data, relativeTo: Self.url),
            let components = URLComponents(url: urlRepresentation, resolvingAgainstBaseURL: true),
            let address = components.queryItems?.first(where: { $0.name == Self.addressQuery })?.value
        else {
            throw QRDecoderError.brokenFormat
        }

        return SolomonQRInfo(address: address)
    }
}
