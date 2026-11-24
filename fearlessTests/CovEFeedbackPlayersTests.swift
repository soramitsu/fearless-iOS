@testable import fearless
import AVFoundation
import CoreHaptics
import XCTest

@MainActor
final class CovEFeedbackPlayersTests: XCTestCase {
    func testAmbientPlayerDecodesAheadAndForgetsFinishedPlayers() throws {
        let player = FWAmbientSoundPlayer()
        let queue = try XCTUnwrap(CovEFind.mirror(player, "queue", as: DispatchQueue.self))

        player.prepare(resources: ["feedback-send", "feedback-receive", "CovE-missing-sound"])
        queue.sync {}
        let decoded = try XCTUnwrap(CovEFind.mirror(player, "decoded", as: [String: Data].self))
        XCTAssertEqual(Set(decoded.keys), ["feedback-send", "feedback-receive"], "missing files are not cached")
        XCTAssertTrue(decoded.values.allSatisfy { !$0.isEmpty })

        let data = try XCTUnwrap(decoded["feedback-send"])
        let unrelated = try AVAudioPlayer(data: data)
        player.audioPlayerDecodeErrorDidOccur(unrelated, error: nil)
        player.audioPlayerDidFinishPlaying(unrelated, successfully: true)
        queue.sync {}
        XCTAssertEqual(CovEFind.mirror(player, "players", as: [AVAudioPlayer].self)?.count, 0)
    }

    func testHapticPlayerFallsBackOrBuildsAHapticsOnlyEngine() throws {
        let events = [
            FWHapticPatterns.Event(type: .transient, time: 0, intensity: [0.5], sharpness: 0.5),
            FWHapticPatterns.Event(type: .continuous, time: 0.1, duration: 0.2, intensity: [0.2, 0.9], sharpness: 0.2),
            FWHapticPatterns.Event(type: .continuous, time: 0.4, intensity: [0.6], sharpness: 0.8)
        ]
        let player = FWHapticPlayer(supportsCoreHaptics: true)
        XCTAssertTrue(player.play(.send, events: events))
        XCTAssertTrue(player.play(.commit, events: events))
        XCTAssertTrue(player.play(.receive, events: []), "no events fall back to one generator tap")
        if let engine = CovEFind.mirror(player, "engine", as: CHHapticEngine.self) {
            XCTAssertTrue(engine.playsHapticsOnly, "the engine never touches the audio session")
            XCTAssertTrue(engine.isAutoShutdownEnabled)
            engine.stop()
        }
        XCTAssertEqual(events[1].peakIntensity, 0.9)
        let times = FWHapticPlayer.generatorSteps(for: .send, events: events).map(\.time)
        XCTAssertEqual(times.count, 3)
        for (time, expected) in zip(times, [0, 0.3, 0.4]) {
            XCTAssertEqual(time, expected, accuracy: 1e-9, "a continuous event taps at its end")
        }
    }
}
