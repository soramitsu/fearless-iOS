import Foundation

struct MainThreadChecker {

    static let `default` = MainThreadChecker()

    var isAvailable = true

    private init() {  }

    func check() {
        if isAvailable, !Thread.isMainThread {
            assertionFailure("Y2h0byB0aSB6YSBjaGVsb3Zlaw==")
        }
    }
}
