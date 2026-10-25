import XCTest

@testable import SSFUtils

/// `ExtrinsicBuilder.build` switches the trace on and off for every extrinsic, from whatever queue
/// the caller is on. The state used to be a plain static array that crashed under concurrent use.
final class LogConcurrencyTests: XCTestCase {
    func testEnablingAndDisablingFromManyThreadsIsSafe() {
        let iterations = 20000

        DispatchQueue.concurrentPerform(iterations: 16) { worker in
            for _ in 0 ..< iterations {
                Log.enable(kind: "LogConcurrencyTests.churn")
                Log.write("LogConcurrencyTests.quiet", message: "worker \(worker)")
                Log.disable(kind: "LogConcurrencyTests.churn")
            }
        }

        // Every enable was matched by a disable, so nothing is left switched on.
        XCTAssertFalse(Log.isEnabled(kind: "LogConcurrencyTests.churn"))
    }

    func testOverlappingBuildsKeepTheTraceOnUntilTheLastOneEnds() {
        let kind = "LogConcurrencyTests.nesting"

        Log.enable(kind: kind)
        Log.enable(kind: kind)
        Log.disable(kind: kind)
        XCTAssertTrue(Log.isEnabled(kind: kind))

        Log.disable(kind: kind)
        XCTAssertFalse(Log.isEnabled(kind: kind))

        Log.disable(kind: kind)
        XCTAssertFalse(
            Log.isEnabled(kind: kind),
            "disabling more often than enabling must not underflow"
        )
    }

    func testTheMessageIsNotBuiltWhileTheTraceIsOff() {
        var built = false

        Log.write("LogConcurrencyTests.off", message: {
            built = true
            return "expensive"
        }())

        XCTAssertFalse(built)
    }
}
