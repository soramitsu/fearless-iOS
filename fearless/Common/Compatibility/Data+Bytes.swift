import Foundation

// Compatibility shim: some code and dependencies expect `Data.bytes: [UInt8]`.
// In Swift 6, prefer `Array(data)` but provide this for source compatibility.
extension Data {
    var bytes: [UInt8] { Array(self) }
}

