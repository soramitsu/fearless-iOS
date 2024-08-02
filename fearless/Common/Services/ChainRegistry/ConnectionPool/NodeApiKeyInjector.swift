import Foundation
import SSFModels

struct NodeApiKeyInjector {
    func injectKey(nodes: [ChainNodeModel]) -> [URL] {
        nodes.map {
            guard $0.name.lowercased().contains("dwellir") else {
                return $0.url
            }
            #if DEBUG
                return $0.url
            #else
                let apiKey = DwellirNodeApiKey.dwellirApiKey
                return $0.url.appendingPathComponent("/\(apiKey)")
            #endif
        }
    }
}
