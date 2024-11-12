import Foundation

class NetworkRequestUrlParameters {
    var urlParameters: [URLQueryItem] {
        let mirror = Mirror(reflecting: self)

        return mirror.children.compactMap {
            guard let name = $0.label else {
                return nil
            }

            let string = String(describing: $0.value)

            guard string != "nil" else {
                return nil
            }

            return URLQueryItem(name: name, value: string)
        }
    }
}
