import XCTest
@testable import FearlessFoundation

final class CountdownTimerTests: XCTestCase {
    func testStart_whenIntervalIsZero_thenStartsAndStopsImmediately() {
        let applicationHandler = ApplicationHandlerStub()
        let delegate = CountdownDelegateRecorder()
        let timer = CountdownTimer(applicationHander: applicationHandler, notificationInterval: 1)
        timer.delegate = delegate

        timer.start(with: 0, runLoop: .main, mode: .default)

        XCTAssertTrue(timer.state.isStopped)
        XCTAssertEqual(timer.remainedInterval, 0)
        XCTAssertNil(applicationHandler.delegate)
        XCTAssertEqual(delegate.events, [
            .started(0),
            .stopped(0)
        ])
    }

    func testStop_whenTimerInProgress_thenStopsAndClearsApplicationDelegate() {
        let applicationHandler = ApplicationHandlerStub()
        let delegate = CountdownDelegateRecorder()
        let timer = CountdownTimer(applicationHander: applicationHandler, notificationInterval: 1)
        timer.delegate = delegate

        timer.start(with: 10, runLoop: .main, mode: .default)

        XCTAssertTrue(timer.state.isInProgress)
        XCTAssertTrue(applicationHandler.delegate === timer)

        timer.stop()

        XCTAssertTrue(timer.state.isStopped)
        XCTAssertEqual(timer.remainedInterval, 0)
        XCTAssertNil(applicationHandler.delegate)
        XCTAssertEqual(delegate.events, [
            .started(10),
            .stopped(10)
        ])
    }

    func testApplicationLifecycle_whenTimerInProgress_thenPausesAndResumes() {
        let applicationHandler = ApplicationHandlerStub()
        let timer = CountdownTimer(applicationHander: applicationHandler, notificationInterval: 1)

        timer.start(with: 10, runLoop: .main, mode: .default)
        applicationHandler.delegate?.didReceiveWillResignActive?(notification: Notification(name: .init("test")))

        XCTAssertTrue(timer.state.isPaused)

        applicationHandler.delegate?.didReceiveDidBecomeActive?(notification: Notification(name: .init("test")))

        XCTAssertTrue(timer.state.isInProgress)
        timer.stop()
    }
}

private final class ApplicationHandlerStub: ApplicationHandlerProtocol {
    weak var delegate: ApplicationHandlerDelegate?
}

private final class CountdownDelegateRecorder: CountdownTimerDelegate {
    enum Event: Equatable {
        case started(TimeInterval)
        case countdown(TimeInterval)
        case stopped(TimeInterval)
    }

    private(set) var events: [Event] = []

    func didStart(with interval: TimeInterval) {
        events.append(.started(interval))
    }

    func didCountdown(remainedInterval: TimeInterval) {
        events.append(.countdown(remainedInterval))
    }

    func didStop(with remainedInterval: TimeInterval) {
        events.append(.stopped(remainedInterval))
    }
}

private extension CountdownTimerState {
    var isStopped: Bool {
        if case .stopped = self {
            return true
        }

        return false
    }

    var isInProgress: Bool {
        if case .inProgress = self {
            return true
        }

        return false
    }

    var isPaused: Bool {
        if case .paused = self {
            return true
        }

        return false
    }
}
