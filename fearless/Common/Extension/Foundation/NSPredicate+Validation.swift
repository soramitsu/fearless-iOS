import Foundation

extension NSPredicate {
    static var notEmpty: NSPredicate {
        return NSPredicate(format: "SELF != ''")
    }

    static var empty: NSPredicate {
        return NSPredicate(format: "SELF == ''")
    }

    static var deriviationPathHardSoftPassword: NSPredicate {
        let format = "(//?[^/]+)*(///[^/]+)?"
        return NSPredicate(format: "SELF MATCHES %@", format)
    }

    static var deriviationPathHardSoft: NSPredicate {
        let format = "(//?[^/]+)*"
        return NSPredicate(format: "SELF MATCHES %@", format)
    }

    static var deriviationPathHard: NSPredicate {
        let format = "(//[^/]+)*"
        return NSPredicate(format: "SELF MATCHES %@", format)
    }

    static var deriviationPathHardPassword: NSPredicate {
        let format = "(//[^/]+)*(///[^/]+)?"
        return NSPredicate(format: "SELF MATCHES %@", format)
    }

    static var seed: NSPredicate {
        let format = "(0x)?[a-fA-F0-9]{64}"
        return NSPredicate(format: "SELF MATCHES %@", format)
    }
}
