@testable import fearless
import UIKit
import XCTest

/// Shared helpers for lane E view tests: hosting views in an iPhone-sized window, finding subviews and
/// round-tripping Interface Builder inspectable properties through key-value coding.
@MainActor
enum CovEHost {
    static let phoneSize = CGSize(width: 390, height: 844)

    /// Puts the view into a visible 390x844 window at the given frame and lays it out.
    @discardableResult
    static func window(for view: UIView, frame: CGRect? = nil) -> UIWindow {
        let window = makeWindow()
        let root = UIViewController()
        window.rootViewController = root
        window.isHidden = false
        root.view.addSubview(view)
        if let frame {
            view.frame = frame
        } else if view.translatesAutoresizingMaskIntoConstraints {
            view.frame = CGRect(x: 16, y: 100, width: phoneSize.width - 32, height: 64)
        }
        root.view.layoutIfNeeded()
        view.layoutIfNeeded()
        return window
    }

    /// Hosts a view controller as the root of a 390x844 window and lays out its view.
    @discardableResult
    static func window(for controller: UIViewController) -> UIWindow {
        let window = makeWindow()
        window.rootViewController = controller
        window.isHidden = false
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return window
    }

    static func close(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
    }

    static func makeWindow(size: CGSize = phoneSize) -> UIWindow {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        XCTAssertNotNil(scene, "UI tests need the host application's window scene")
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: size)
        return window
    }

    /// Spins the main run loop for the given time so main-queue work and short animations can finish.
    static func spin(_ seconds: TimeInterval = 0.05) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// Spins the main run loop until the condition holds or the timeout passes; returns the final condition.
    @discardableResult
    static func spin(until condition: () -> Bool, timeout: TimeInterval = 2) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if condition() {
                return true
            }
            if Date() > deadline {
                return condition()
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}

@MainActor
enum CovEFind {
    static func all<T: UIView>(_: T.Type, in root: UIView) -> [T] {
        var result: [T] = []
        var queue: [UIView] = [root]
        while !queue.isEmpty {
            let view = queue.removeFirst()
            if let match = view as? T {
                result.append(match)
            }
            queue.append(contentsOf: view.subviews)
        }
        return result
    }

    static func first<T: UIView>(_ type: T.Type, in root: UIView) -> T? {
        all(type, in: root).first
    }

    static func texts(in root: UIView) -> [String] {
        all(UILabel.self, in: root).compactMap(\.text).filter { !$0.isEmpty }
    }

    static func label(_ text: String, in root: UIView) -> UILabel? {
        all(UILabel.self, in: root).first { $0.text == text }
    }

    /// Reads a stored property (including private ones) through reflection.
    static func mirror<T>(_ object: Any, _ name: String, as _: T.Type = T.self) -> T? {
        var mirror: Mirror? = Mirror(reflecting: object)
        while let current = mirror {
            if let child = current.children.first(where: { $0.label == name }) {
                if let value = child.value as? T {
                    return value
                }
                let inner = Mirror(reflecting: child.value)
                if inner.displayStyle == .optional, let wrapped = inner.children.first?.value as? T {
                    return wrapped
                }
                return nil
            }
            mirror = current.superclassMirror
        }
        return nil
    }
}

@MainActor
enum CovEKVC {
    /// Sets a value through KVC and asserts that reading the same key returns the expected value
    /// (the written value when no expectation is given).
    static func assertRoundTrip(
        _ object: NSObject,
        _ key: String,
        _ value: Any,
        expected: Any? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        object.setValue(value, forKey: key)
        let read = object.value(forKey: key)
        let want = (expected ?? value) as AnyObject
        XCTAssertTrue(
            (read as AnyObject?)?.isEqual(want) == true,
            "\(type(of: object)).\(key): read \(String(describing: read)), expected \(want)",
            file: file,
            line: line
        )
    }

    /// Round-trips a font name and size pair and checks both the name and the point size.
    static func assertFont(
        _ object: NSObject,
        nameKey: String,
        sizeKey: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertRoundTrip(object, nameKey, "Helvetica-Bold", file: file, line: line)
        assertRoundTrip(object, sizeKey, 21.0, file: file, line: line)
        assertRoundTrip(object, nameKey, "Helvetica-Bold", file: file, line: line)
    }
}

/// Records delegate and callback invocations shared by several lane E tests.
final class CovERecorder {
    private(set) var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}
