import Foundation

extension String {
    /// The first match of `regex` in the string, or nil. SignTypedData reads an EIP-712 type name with it.
    func match(for regex: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: regex) else {
            return nil
        }
        let results = regex.matches(in: self, range: NSRange(startIndex..., in: self))
        return results.lazy.compactMap { Range($0.range, in: self).map { String(self[$0]) } }.first
    }
}
