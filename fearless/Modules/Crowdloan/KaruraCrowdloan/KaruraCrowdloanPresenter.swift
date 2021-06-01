import Foundation

final class KaruraCrowdloanPresenter {
    weak var view: KaruraCrowdloanViewProtocol?
    let wireframe: KaruraCrowdloanWireframeProtocol

    let bonusService: CrowdloanBonusServiceProtocol
    let displayInfo: CrowdloanDisplayInfo
    let inputAmount: Decimal

    weak var crowdloanDelegate: CustomCrowdloanDelegate?

    init(
        wireframe: KaruraCrowdloanWireframeProtocol,
        bonusService: CrowdloanBonusServiceProtocol,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        crowdloanDelegate: CustomCrowdloanDelegate
    ) {
        self.wireframe = wireframe
        self.bonusService = bonusService
        self.inputAmount = inputAmount
        self.displayInfo = displayInfo
        self.crowdloanDelegate = crowdloanDelegate
    }
}

extension KaruraCrowdloanPresenter: KaruraCrowdloanPresenterProtocol {
    func setup() {}
}
