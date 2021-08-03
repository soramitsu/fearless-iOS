import Foundation

protocol CustomCrowdloanDelegate: AnyObject {
    func didReceive(bonusService: CrowdloanBonusServiceProtocol)
}
