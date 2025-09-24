import Foundation

class NetworkRequestUrlParameters {
    var urlParameters: [URLQueryItem] {
        let mirror = Mirror(reflecting: self)

        return mirror.children.compactMap {
            guard let name = $0.label, let value = $0.value as? String else {
                return nil
            }

            return URLQueryItem(name: name, value: value)
        }
    }
}
