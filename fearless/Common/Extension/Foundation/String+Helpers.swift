import Foundation
import UIKit

extension String {
    static var returnKey: String { "\n" }

    var underlined: NSAttributedString {
        NSAttributedString(string: self, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
    }
}
