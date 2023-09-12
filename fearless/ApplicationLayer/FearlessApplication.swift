import UIKit
import SoraFoundation
import SoraKeystore

class FearlessApplication: UIApplication {
    private lazy var goneBackgroundTimestamp = Date().timeIntervalSince1970
    private var timerToDetectInactivity: Timer?
    private var applicationHandler: ApplicationHandler?

    private lazy var secretManager: SecretStoreManagerProtocol = {
        KeychainManager.shared
    }()

    override init() {
        super.init()
        applicationHandler = ApplicationHandler()
        applicationHandler?.delegate = self
    }

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
        guard secretManager.checkSecret(for: KeystoreTag.pincode.rawValue) else {
            return
        }
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
        goneBackgroundTimestamp = Date().timeIntervalSince1970
    }

    func didReceiveWillEnterForeground(notification _: Notification) {
        resetTimer()
        if Date().timeIntervalSince1970 - goneBackgroundTimestamp > UtilityConstants.inactiveSessionDropTimeInSeconds {
            dropSession()
        }
    }
}
