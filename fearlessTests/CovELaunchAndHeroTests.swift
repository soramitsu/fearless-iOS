@testable import fearless
import AVFoundation
import UIKit
import XCTest

@MainActor
final class CovELaunchAndHeroTests: XCTestCase {
    func testLaunchInstallsOnceAndTappedFlightRestoresItsWindow() throws {
        let fixture = try CovEEffectFixture()
        let root = UIViewController()
        let window = CovEHost.window(for: root)
        window.backgroundColor = .purple
        defer {
            if FWLaunchIgnite.isShowing {
                NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            }
            CovEHost.close(window)
        }
        let scene = try XCTUnwrap(window.windowScene)
        let launch = try XCTUnwrap(FWLaunchIgnite.installIfNeeded(
            over: window,
            in: scene,
            processInfo: CovELaunchProcessInfo(),
            effects: fixture.effects
        ))
        XCTAssertTrue(FWLaunchIgnite.isShowing)
        let overlay = try XCTUnwrap(scene.windows.compactMap { $0.rootViewController as? FWLaunchOverlayViewController }.first)
        XCTAssertEqual(overlay.view.window?.windowLevel, UIWindow.Level.normal + 1)
        XCTAssertTrue(overlay.playerLayer.player?.isMuted == true)
        overlay.onTap?()
        let flight = try XCTUnwrap(CovEFind.mirror(launch, "flight", as: FWLaunchFlight.self))
        XCTAssertEqual(flight.rate, FWShikiban.bundled?.skipRate)
        overlay.onTap?()
        flight.advance(byMs: 10000)
        XCTAssertTrue(flight.isFinished)
        XCTAssertFalse(FWLaunchIgnite.isShowing)
        XCTAssertTrue(root.view.transform.isIdentity)
        XCTAssertEqual(window.backgroundColor, .purple)
        XCTAssertNil(FWLaunchIgnite.installIfNeeded(over: window, in: scene, processInfo: CovELaunchProcessInfo(), effects: fixture.effects))
    }

    func testWelcomeLoopCallCompletionAndBackgroundRespectVisibility() throws {
        let fixture = try CovEEffectFixture()
        let center = NotificationCenter()
        let bundled = FWWelcomeHeroView.Media.bundled
        XCTAssertNotNil(bundled.loop)
        XCTAssertNotNil(bundled.call)
        let hero = FWWelcomeHeroView(
            media: .init(loop: bundled.loop, call: bundled.call, sound: nil, poster: bundled.poster),
            effects: fixture.effects,
            lifecycle: center
        )
        let window = CovEHost.window(for: hero, frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        defer { CovEHost.close(window) }
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertFalse(hero.showsPosterOnly)
        XCTAssertTrue(hero.isLooping)
        XCTAssertNotNil(hero.posterView.image)
        XCTAssertTrue(hero.accessibilityElementsHidden)
        XCTAssertEqual(hero.loopLayer.frame, hero.posterView.frame)
        XCTAssertEqual(hero.callLayer.frame, hero.posterView.frame)
        XCTAssertEqual(hero.posterView.frame.minY, 0)
        XCTAssertGreaterThanOrEqual(hero.posterView.frame.height, hero.bounds.height)
        hero.isHidden = true
        XCTAssertFalse(hero.isLooping)
        hero.isHidden = false
        XCTAssertTrue(hero.isLooping)
        hero.playCall()
        XCTAssertTrue(hero.isPlayingCall)
        let player = try XCTUnwrap(hero.callLayer.player)
        hero.playCall()
        XCTAssertTrue(hero.callLayer.player === player)
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        XCTAssertTrue(CovEHost.spin(until: { !hero.isPlayingCall }, timeout: 4))
        XCTAssertNil(hero.callLayer.player)
        XCTAssertTrue(hero.isLooping)
        hero.playCall()
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertFalse(hero.isPlayingCall)
        XCTAssertFalse(hero.isLooping)
        XCTAssertNil(hero.callLayer.player)
        hero.playCall()
        XCTAssertFalse(hero.isPlayingCall)
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertTrue(hero.isLooping)
        fixture.effects.userChoice = .reduced
        XCTAssertTrue(hero.showsPosterOnly)
        XCTAssertNil(hero.loopLayer.player)
        hero.playCall()
        XCTAssertFalse(hero.isPlayingCall, "A poster without an audio resource has no call to play")
        XCTAssertEqual(FWWelcomeHeroView.footageFrame(in: .zero), .zero)
        let frame = FWWelcomeHeroView.footageFrame(in: CGRect(x: 10, y: 20, width: 200, height: 800))
        XCTAssertEqual(frame.minY, 20)
        XCTAssertEqual(frame.midX, 110)
        XCTAssertEqual(frame.height, 800, accuracy: 0.001)
    }
}

final class CovELaunchProcessInfo: ProcessInfo, @unchecked Sendable {
    override var arguments: [String] {
        []
    }
}
