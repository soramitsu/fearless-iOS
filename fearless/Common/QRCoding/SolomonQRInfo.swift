import Foundation
import SSFUtils

struct SolomonQRInfo: QRInfo {
    var address: String
}

final class SolomonQRDecoder: QRDecoderProtocol {
    static let url = URL(string: "https://mekongdebug.page.link")
    static let addressQuery = "wallAdd"

    func decode(data: Data) throws -> QRInfoType {
        guard
            let urlRepresentation = URL(dataRepresentation: data, relativeTo: Self.url),
            let components = URLComponents(url: urlRepresentation, resolvingAgainstBaseURL: true),
            let address = components.queryItems?.first(where: { $0.name == Self.addressQuery })?.value
        else {
            throw QRDecoderError.brokenFormat
        }

        return .solomon(SolomonQRInfo(address: address))
    }
}
