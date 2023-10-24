import Foundation
import SSFUtils
import MPQRCoreSDK

struct BokoloCashQRInfo: QRInfo {
    let address: String
    let assetId: String?
    let transactionAmount: String?
}

final class BokoloCashDecoder: QRDecoderProtocol {
    func decode(data: Data) throws -> QRInfoType {
        guard
            let incomingURL = URL(dataRepresentation: data, relativeTo: nil, isAbsolute: true),
            let payload = fetchPayloadData(url: incomingURL)
        else {
            throw QRDecoderError.brokenFormat
        }

        let payloadData = try MPQRParser.parse(string: payload)

        var maiData: MAIData?
        for value in EMVQRConstants.availableIDTags {
            if let item = try? payloadData.getMAIData(forTagString: value) {
                maiData = item
                break
            }
        }

        guard let accountId = maiData?.AID else {
            throw QRDecoderError.accountIdMismatch
        }

        let qrInfo = BokoloCashQRInfo(
            address: accountId,
            assetId: payloadData.transactionCurrencyCode,
            transactionAmount: payloadData.transactionAmount
        )
        return .bokoloCash(qrInfo)
    }

    private func fetchPayloadData(url: URL?) -> String? {
        guard
            let url = url,
            let longComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = longComponents.queryItems,
            let qr = queryItems.first(where: { component in
                component.name == "qr"
            })
        else {
            return nil
        }

        return qr.value?.replacingOccurrences(of: "+", with: " ")
    }
}

enum EMVQRConstants {
    static let availableIDTags = Array(26 ... 51).map { String($0) }
}
