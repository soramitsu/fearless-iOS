import Foundation

extension String {
    var fullRange: Range<Index> {
        startIndex ..< endIndex
    }

    var fullNSRange: NSRange {
        NSRange(fullRange, in: self)
    }
}
