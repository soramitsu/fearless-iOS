import Foundation

public protocol XcmConfigProtocol {
    var chainsSourceUrl: URL { get }
    var chainTypesSourceUrl: URL { get }
    var destinationFeeSourceUrl: URL { get }
    var tokenLocationsSourceUrl: URL { get }
}

/// The remote files the XCM services use when the caller gives no `XcmConfigProtocol`. All are on
/// `master`: the `feature/rococo` branch the fee and type defaults named is gone.
final class XcmConfig: XcmConfigProtocol {
    static let shared = XcmConfig()
    private init() {}

    /// The newest chain list `ChainModel` decodes as it is. The wallet reads `chains/v13` and
    /// rewrites it first: v13 names block explorer types `BlockExplorerType` does not have.
    var chainsSourceUrl: URL {
        GitHubUrl.url(suffix: "chains/v2/chains.json")
    }

    var chainTypesSourceUrl: URL {
        GitHubUrl.url(suffix: "chains/all_chains_types.json")
    }

    var destinationFeeSourceUrl: URL {
        GitHubUrl.url(suffix: "xcm/v2/xcm_fees.json")
    }

    var tokenLocationsSourceUrl: URL {
        GitHubUrl.url(suffix: "xcm/v2/xcm_token_locations.json")
    }
}

private enum GitHubUrl {
    private static var baseUrl: URL {
        URL(string: "https://raw.githubusercontent.com/soramitsu/fearless-iOS/master/remote-config/production/")!
    }

    static func url(suffix: String) -> URL {
        baseUrl.appendingPathComponent(suffix)
    }
}
