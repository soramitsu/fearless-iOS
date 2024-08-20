import Foundation
import CryptoKit
import SSFNetwork
import FearlessKeys
import SoraKeystore
import SSFModels
import SSFUtils
import CommonCrypto

// https://www.okx.com/ru/web3/build/docs/waas/rest-authentication

enum OKXDexRequestSignerError: Error {
    case accountUnavailable
    case invalidData
    case invalidSecret
}

final class OKXDexRequestSigner: RequestSigner {
    func sign(request: inout URLRequest, config: SSFNetwork.RequestConfig) throws {
        let timestamp = DateFormatter.iso.string(from: Date())
        request.setValue(timestamp, forHTTPHeaderField: "OK-ACCESS-TIMESTAMP")

        let apiKey = OKXApiKeys.okxApiKey
        request.setValue(apiKey, forHTTPHeaderField: "OK-ACCESS-KEY")

        let secretKey = OKXApiKeys.okxSecretKey

        let passphrase = OKXApiKeys.okxPassphrase
        request.setValue(passphrase, forHTTPHeaderField: "OK-ACCESS-PASSPHRASE")

        let projectId = OKXApiKeys.okxProjectId
        request.setValue(projectId, forHTTPHeaderField: "OK-ACCESS-PROJECT")

        let endpoint = request.url?.absoluteString.replacingOccurrences(of: config.baseURL.absoluteString, with: "", options: .caseInsensitive, range: nil)
        guard let sign = [timestamp, config.method.rawValue.uppercased(), endpoint.or(""), (config.body?.toUTF8String()).or("")].joined().data(using: .utf8) else {
            throw OKXDexRequestSignerError.invalidData
        }
        let key = SymmetricKey(data: Data(secretKey.utf8))

        let signature = HMAC<SHA256>.authenticationCode(for: sign, using: key)
        let signatureData = Data(signature)
        request.setValue(signatureData.base64EncodedString(), forHTTPHeaderField: "OK-ACCESS-SIGN")
    }
}
