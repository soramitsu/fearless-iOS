import XCTest
import UIKit
@testable import fearless

/// Shared lane-J helpers: hosting views in an iPhone-sized window, walking view trees, and spinning the main run loop.
enum CovJViewFixture {
    static func host(_ controller: UIViewController) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return window
    }

    static func host(_ view: UIView) throws -> UIWindow {
        let controller = UIViewController()
        controller.view = view
        return try host(controller)
    }

    static func descendants<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        view.subviews.flatMap { child in
            (child as? T).map { [$0] }.or([]) + descendants(type, in: child)
        }
    }
}

enum CovJWait {
    /// Spins the main run loop until `condition` holds or the deadline passes; returns the last value of `condition`.
    @discardableResult
    static func until(timeout: TimeInterval = 2, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if condition() { return true }
            if Date() > deadline { return condition() }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    /// Lets queued main-queue work run for a short while.
    static func drain(_ interval: TimeInterval = 0.05) {
        RunLoop.main.run(until: Date().addingTimeInterval(interval))
    }
}
