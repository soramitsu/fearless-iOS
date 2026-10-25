import Foundation

public protocol ApplicationSources {
    var chainsSourceUrl: URL { get }
    var chainTypesSourceUrl: URL { get }
}

public final class ApplicationSourcesImpl: ApplicationSources {
    public static let shared = ApplicationSourcesImpl()
    private init() {}

    public var chainsSourceUrl: URL {
        #if DEBUG
            GitHubUrl.url(suffix: "chains/v9/chains_dev.json", environment: .development)
        #else
            GitHubUrl.url(suffix: "chains/v9/chains.json")
        #endif
    }

    public var chainTypesSourceUrl: URL {
        GitHubUrl.url(suffix: "chains/all_chains_types.json")
    }
}

private enum GitHubUrl {
    enum Environment: String {
        case production
        case development
    }

    static func url(suffix: String, environment: Environment = .production) -> URL {
        URL(string: "https://raw.githubusercontent.com/soramitsu/fearless-iOS/master/remote-config/")!
            .appendingPathComponent(environment.rawValue)
            .appendingPathComponent(suffix)
    }
}
