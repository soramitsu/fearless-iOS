import UIKit

final class CrowdloanAgreementConfirmInteractor: CrowdloanAgreementConfirmInteractorInputProtocol {
    weak var presenter: CrowdloanAgreementConfirmInteractorOutputProtocol!

    private let paraId: ParaId
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let extrinsicService: ExtrinsicServiceProtocol

    init(
        paraId: ParaId,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol
    ) {
        self.paraId = paraId
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
    }
}

extension CrowdloanAgreementConfirmInteractor {
    func estimateFee() {}
}
