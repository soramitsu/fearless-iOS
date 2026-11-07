import Foundation

struct Caip2ChainId: Hashable {
    let namespace: String
    let reference: String

    init?(raw: String) {
        let chain = raw.components(separatedBy: ":")
        guard chain.count == 2 else {
            return nil
        }

        namespace = chain[0]
        reference = chain[1]
    }

    init(namespace: String, reference: String) {
        self.namespace = namespace
        self.reference = reference
    }

    var raw: String {
        [namespace, reference].joined(separator: ":")
    }
}
