final class YourValidatorInfoInteractor: ValidatorInfoInteractorBase {
    private let accountAddress: AccountAddress

    init(
        accountAddress: AccountAddress,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        walletAssetId: WalletAssetId
    ) {
        self.accountAddress = accountAddress

        super.init(
            singleValueProviderFactory: singleValueProviderFactory,
            walletAssetId: walletAssetId
        )
    }

    private func fetchValidatorInfo() {
        // TODO: Fetch validatorInfo
        // Send it to presenter
//        presenter?.didReceive(validatorInfo: validatorInfo)
    }

    override func setup() {
        super.setup()

        fetchValidatorInfo()
    }
}
