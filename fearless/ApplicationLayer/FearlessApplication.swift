import UIKit

class FearlessApplication: UIApplication {
    private var timerToDetectInactivity: Timer?

    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)
        if let touches = event.allTouches {
            for touch in touches where touch.phase == UITouch.Phase.began {
                self.resetTimer()
            }
        }
    }

    private func resetTimer() {
        if let timerToDetectInactivity = timerToDetectInactivity {
            timerToDetectInactivity.invalidate()
        }

        timerToDetectInactivity = Timer.scheduledTimer(
            timeInterval: UtilityConstants.inactiveSessionDropTimeInSeconds,
            target: self,
            selector: #selector(FearlessApplication.dropSession),
            userInfo: nil,
            repeats: false
        )
    }

    @objc private func dropSession() {
        EventCenter.shared.notify(with: UserInactiveEvent())
        if let window = UIApplication.shared.windows.first {
            guard let pincodeViewController = PinViewFactory.createSecuredPinView()?.controller else {
                return
            }

            window.rootViewController?.dismiss(animated: false)
            window.rootViewController?.present(pincodeViewController, animated: false)
        }
    }
}
