import Foundation

protocol BeaconQRDelegate: AnyObject {
    func didReceiveBeacon(connectionInfo: BeaconConnectionInfo)
}
