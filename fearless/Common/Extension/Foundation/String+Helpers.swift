import Foundation
import UIKit

extension String {
    static var returnKey: String { "\n" }

    var underLined: NSAttributedString {
        NSMutableAttributedString(string: self, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
    }
}
