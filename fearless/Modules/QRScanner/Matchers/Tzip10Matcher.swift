import Foundation
import SoraFoundation
import IrohaCrypto

enum Tzip10MatcherError: Error {
    case invalidUrl(actualUrl: String)
    case invalidDataLength(minLength: Int, actualLength: Int)
    case invalidChecksum(expected: Data, actual: Data)
}

final class Tzip10Matcher: QRMatching {
    let logger: LoggerProtocol

    weak var delegate: BeaconQRDelegate?

    private var lastProccessedCode: String?

    init(delegate: BeaconQRDelegate, logger: LoggerProtocol) {
        self.delegate = delegate
        self.logger = logger
    }

    func match(code: String) -> Bool {
        guard lastProccessedCode != code else {
            return false
        }

        lastProccessedCode = code

        do {
            let info = try parse(code: code)
            logger.info("Did receive connection info: \(info)")

            DispatchQueue.main.async {
                self.delegate?.didReceiveBeacon(connectionInfo: info)
            }

            return true
        } catch {
            logger.error("Did receive parsing error: \(error)")
            return false
        }
    }

    private func parse(code: String) throws -> BeaconConnectionInfo {
        guard let urlComponents = URLComponents(string: code), let queryString = urlComponents.query else {
            throw Tzip10MatcherError.invalidUrl(actualUrl: code)
        }

        let query = try QueryDecoder().decode(BeaconQuery.self, query: queryString)

        let data = NSData(base58String: query.data) as Data
        let checksumLength = 4

        guard data.count >= checksumLength else {
            throw Tzip10MatcherError.invalidDataLength(minLength: checksumLength, actualLength: data.count)
        }

        let checksumData = data.suffix(checksumLength)
        let jsonData = data.prefix(data.count - checksumLength)

        let expectedChecksumData = jsonData.sha256().sha256().prefix(checksumLength)

        guard expectedChecksumData == checksumData else {
            throw Tzip10MatcherError.invalidChecksum(expected: expectedChecksumData, actual: checksumData)
        }

        return try JSONDecoder().decode(BeaconConnectionInfo.self, from: jsonData)
    }
}
