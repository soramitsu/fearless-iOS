import Foundation

extension NSPredicate {
    static var notEmpty: NSPredicate {
        return NSPredicate(format: "SELF != ''")
    }
}
