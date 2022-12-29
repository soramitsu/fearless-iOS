import Foundation

final class PrintTimer {
    private let start = Date()
    private let name: String

    init(name: String) {
        self.name = name
    }

    func done() {
        let end = Date()
        print("PrintTimer \(name) took \(end.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) s.")
    }
}
