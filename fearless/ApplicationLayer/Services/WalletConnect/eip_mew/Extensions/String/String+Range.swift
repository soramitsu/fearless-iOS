import Foundation

extension String {
    var fullRange: Range<Index> {
        startIndex ..< endIndex
    }

    var fullNSRange: NSRange {
        NSRange(fullRange, in: self)
    }
}

extension String {
    func match(for regex: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(
                in: self,
                range: NSRange(startIndex..., in: self)
            )
            let matches = results.map {
                String(self[Range($0.range, in: self)!])
            }
            return matches.first
        } catch {
            return nil
        }
    }
}
