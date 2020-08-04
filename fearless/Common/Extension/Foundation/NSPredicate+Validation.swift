import Foundation

extension NSPredicate {
    static var notEmpty: NSPredicate {
        return NSPredicate(format: "SELF != ''")
    }

    static var empty: NSPredicate {
        return NSPredicate(format: "SELF == ''")
    }

    static var deriviationPath: NSPredicate {
        let format = "(//?[^/]+)*(///[^/]+)?"
        return NSPredicate(format: "SELF MATCHES %@", format)
    }
}
