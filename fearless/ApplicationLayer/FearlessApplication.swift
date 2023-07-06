import UIKit
import SoraFoundation

class FearlessApplication: UIApplication {
    private var timerToDetectInactivity: Timer?
    private var applicationHandler: ApplicationHandler?

    override func sendEvent(_ event: UIEvent) {
        if applicationHandler == nil {
            applicationHandler = ApplicationHandler()
            applicationHandler?.delegate = self
        }

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
        if let window = UIApplication.shared.windows.first {
            guard let pincodeViewController = PinViewFactory.createPinCheckView()?.controller else {
                return
            }

            window.rootViewController?.dismiss(animated: false)
            window.rootViewController?.present(pincodeViewController, animated: false)
        }
    }
}

extension FearlessApplication: ApplicationHandlerDelegate {
    func didReceiveDidEnterBackground(notification _: Notification) {
        timerToDetectInactivity?.invalidate()
    }

    func didReceiveWillEnterForeground(notification _: Notification) {
        resetTimer()
    }
}
