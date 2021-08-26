import Foundation
import SwiftyBeaver
import FearlessUtils

final class Logger {
    static let shared = Logger()

    let log = SwiftyBeaver.self

    var minLevel: SwiftyBeaver.Level? {
        get {
            log.destinations.first?.minLevel
        }

        set {
            log.removeAllDestinations()

            if let level = newValue {
                let destination = ConsoleDestination()
                destination.minLevel = level
                log.addDestination(destination)
            }
        }
    }

    private init() {
        let destination = ConsoleDestination()

        #if F_DEV
            destination.minLevel = .verbose
        #else
            destination.minLevel = .info
        #endif

        log.addDestination(destination)
    }
}

extension Logger: LoggerProtocol {
    func verbose(message: String, file: String, function: String, line: Int) {
        log.custom(
            level: .verbose,
            message: message,
            file: file,
            function: function,
            line: line
        )
    }

    func debug(message: String, file: String, function: String, line: Int) {
        log.custom(
            level: .debug,
            message: message,
            file: file,
            function: function,
            line: line
        )
    }

    func info(message: String, file: String, function: String, line: Int) {
        log.custom(
            level: .info,
            message: message,
            file: file,
            function: function,
            line: line
        )
    }

    func warning(message: String, file: String, function: String, line: Int) {
        log.custom(
            level: .warning,
            message: message,
            file: file,
            function: function,
            line: line
        )
    }

    func error(message: String, file: String, function: String, line: Int) {
        log.custom(
            level: .error,
            message: message,
            file: file,
            function: function,
            line: line
        )
    }
}
