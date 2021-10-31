protocol CrowdloanAgreementConfirmViewProtocol: ControllerBackedProtocol {
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveAccount(viewModel: CrowdloanAccountViewModel?)
}

protocol CrowdloanAgreementConfirmPresenterProtocol: AnyObject {
    func setup()
    func confirmAgreement()
}

protocol CrowdloanAgreementConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
    func confirmAgreement()
}

protocol CrowdloanAgreementConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveDisplayAddress(result: Result<DisplayAddress, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveVerifiedExtrinsicHash(result: Result<String, Error>)
}

protocol CrowdloanAgreementConfirmWireframeProtocol: AnyObject {
    func showAgreementSigned(
        from view: CrowdloanAgreementConfirmViewProtocol?,
        paraId: ParaId,
        remarkExtrinsicHash: String,
        customFlow: CustomCrowdloanFlow
    )
}
