import Foundation
import RobinHood

extension ConnectionItem: Identifiable {
    var identifier: String { url.absoluteString }
}

extension ManagedConnectionItem: Identifiable {
    var identifier: String { url.absoluteString }
}
