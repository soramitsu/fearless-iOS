import Foundation
import SSFModels

struct NodeApiKeyInjector {
    private let apiKey: String

    init(apiKey: String? = nil) {
        #if DEBUG
            self.apiKey = apiKey ?? ""
        #else
            self.apiKey = apiKey ?? DwellirNodeApiKey.dwellirApiKey
        #endif
    }

    func injectKey(nodes: [ChainNodeModel]) -> [URL] {
        let authenticatedHost = #"^api-[a-z0-9]+(?:-[a-z0-9]+)*(?:\.n)?\.dwellir\.com$"#
        return nodes.map { node in
            // Names are user controlled. Only Dwellir's authenticated API hosts
            // accept this credential; public RPC hosts and custom paths do not.
            guard let components = URLComponents(url: node.url, resolvingAgainstBaseURL: false),
                  components.scheme?.lowercased() == "wss",
                  let host = components.host?.lowercased(),
                  host.range(of: authenticatedHost, options: .regularExpression) != nil,
                  components.port == nil || components.port == 443,
                  components.user == nil, components.password == nil,
                  components.query == nil, components.fragment == nil,
                  components.percentEncodedPath.isEmpty || components.percentEncodedPath == "/",
                  !apiKey.isEmpty,
                  !["true", "false", "null", "undefined"].contains(apiKey.lowercased()),
                  apiKey.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
            else {
                return node.url
            }

            return node.url.appendingPathComponent(apiKey)
        }
    }
}
