import SSFModels

typealias NftSendModuleCreationResult = (view: NftSendViewInput, input: NftSendModuleInput)

protocol NftSendViewInput: ControllerBackedProtocol {
    func didReceive(feeViewModel: BalanceViewModelProtocol?)
    func didReceive(scamInfo: ScamInfo?)
    func didReceive(viewModel: RecipientViewModel)
}

protocol NftSendViewOutput: AnyObject {
    func didLoad(view: NftSendViewInput)
    func didBackButtonTapped()
    func didTapScanButton()
    func didTapHistoryButton()
    func didTapPasteButton()
    func didTapContinueButton()
    func searchTextDidChanged(_ text: String)
}

protocol NftSendInteractorInput: AnyObject {
    func setup(with output: NftSendInteractorOutput)
    func estimateFee(for nft: NFT, address: String?)
    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult
}

protocol NftSendInteractorOutput: AnyObject {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceive(scamInfo: ScamInfo?)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol NftSendRouterInput: AnyObject, PushDismissable, BaseErrorPresentable, SheetAlertPresentable {
    func presentScan(
        from view: ControllerBackedProtocol?,
        moduleOutput: ScanQRModuleOutput
    )

    func presentHistory(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chain: ChainModel,
        moduleOutput: ContactsModuleOutput
    )

    func presentConfirm(
        nft: NFT,
        receiver: String,
        scamInfo: ScamInfo?,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )
}

protocol NftSendModuleInput: AnyObject {}

protocol NftSendModuleOutput: AnyObject {}
