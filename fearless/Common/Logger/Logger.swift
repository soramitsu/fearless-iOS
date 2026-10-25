import Foundation
import SwiftyBeaver

protocol LoggerProtocol {
    func verbose(message: String, file: String, function: String, line: Int)
    func debug(message: String, file: String, function: String, line: Int)
    func info(message: String, file: String, function: String, line: Int)
    func warning(message: String, file: String, function: String, line: Int)
    func error(message: String, file: String, function: String, line: Int)
    func customError(error: Error, file: String, function: String, line: Int)
}

extension LoggerProtocol {
    func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        verbose(message: message, file: file, function: function, line: line)
    }

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message: message, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message: message, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        warning(message: message, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        error(message: message, file: file, function: function, line: line)
    }

    func customError(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        customError(error: error, file: file, function: function, line: line)
    }
}

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

    func customError(error: Error, file: String, function: String, line: Int) {
        log.custom(
            level: .error,
            message: error.logSafeDescription,
            file: file,
            function: function,
            line: line
        )
    }
}

extension Error {
    /// This error for a log line. A node URL can carry an API key in its path, and URLError
    /// keeps the URL it failed on in its user info, so a URLError is reduced to its code and
    /// every other URL in the description is replaced.
    var logSafeDescription: String {
        LogRedaction.description(of: self)
    }
}

enum LogRedaction {
    static func description(of error: Error) -> String {
        if let urlError = error as? URLError {
            return "URLError(\(urlError.code.rawValue))"
        }
        return redactingURLs(in: String(describing: error))
    }

    static func redactingURLs(in text: String) -> String {
        text.replacingOccurrences(
            of: #"[A-Za-z][A-Za-z0-9+.\-]*://[^\s"'<>]+"#,
            with: "<url>",
            options: .regularExpression
        )
    }
}
