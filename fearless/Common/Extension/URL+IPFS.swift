import Foundation

extension URL {
    var normalizedIpfsURL: URL? {
        guard !isTLSScheme, absoluteString.contains("ipfs"), let scheme = scheme else {
            return self
        }

        let pathWithoutScheme = absoluteString.replacingOccurrences(of: scheme, with: "").replacingOccurrences(of: "://", with: "")

        let pathDecoratedWithHttps = "https://ipfs.io/ipfs/\(pathWithoutScheme)"

        guard let url = URL(string: pathDecoratedWithHttps) else {
            return nil
        }

        return url
    }
}
