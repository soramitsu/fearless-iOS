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

    static var websocket: NSPredicate {
        let format = "^" +
          // protocol identifier (optional)
          // short syntax // still required
          "(?:(?:(?:wss?):)?\\/\\/)" +
          // user:pass BasicAuth (optional)
          "(?:\\S+(?::\\S*)?@)?" +
          "(?:" +
            // IP address exclusion
            // private & local networks
            "(?!(?:10|127)(?:\\.\\d{1,3}){3})" +
            "(?!(?:169\\.254|192\\.168)(?:\\.\\d{1,3}){2})" +
            "(?!172\\.(?:1[6-9]|2\\d|3[0-1])(?:\\.\\d{1,3}){2})" +
            // IP address dotted notation octets
            // excludes loopback network 0.0.0.0
            // excludes reserved space >= 224.0.0.0
            // excludes network & broadcast addresses
            // (first & last IP address of each class)
            "(?:[1-9]\\d?|1\\d\\d|2[01]\\d|22[0-3])" +
            "(?:\\.(?:1?\\d{1,2}|2[0-4]\\d|25[0-5])){2}" +
            "(?:\\.(?:[1-9]\\d?|1\\d\\d|2[0-4]\\d|25[0-4]))" +
          "|" +
            // host & domain names, may end with dot
            // can be replaced by a shortest alternative
            // (?![-_])(?:[-\\w\\u00a1-\\uffff]{0,63}[^-_]\\.)+
            "(?:" +
              "(?:" +
                "[a-z0-9\\u00a1-\\uffff]" +
                "[a-z0-9\\u00a1-\\uffff_-]{0,62}" +
              ")?" +
              "[a-z0-9\\u00a1-\\uffff]\\." +
            ")+" +
            // TLD identifier name, may end with dot
            "(?:[a-z\\u00a1-\\uffff]{2,}\\.?)" +
          ")" +
          // port number (optional)
          "(?::\\d{2,5})?" +
          // resource path (optional)
          "(?:[/?#]\\S*)?" +
        "$"

        return NSPredicate(format: "SELF MATCHES %@", format)
    }
}
