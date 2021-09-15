import Foundation

extension Data {
    var ethereumAddress: Data { prefix(20) }
}
