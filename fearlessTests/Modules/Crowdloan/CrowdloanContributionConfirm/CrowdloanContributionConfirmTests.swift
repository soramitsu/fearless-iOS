import XCTest
@testable import fearless
import SoraKeystore
import CommonWallet
import RobinHood
import SoraFoundation
import Cuckoo

class CrowdloanContributionConfirmTests: XCTestCase {
    static let currentBlockNumber: BlockNumber = 1337

    let crowdloan = Crowdloan(
        paraId: 2000,
        fundInfo: CrowdloanFunds(
            depositor: Data(repeating: 0, count: 32),
            verifier: nil,
            deposit: 100,
            raised: 100,
            end: currentBlockNumber + 100,
            cap: 1000000000000000,
            lastContribution: .never,
            firstPeriod: 100,
            lastPeriod: 101,
            trieIndex: 1)
    )

    func testContributionConfirmation() throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let chain = Chain.westend

        let runtimeCodingService = try RuntimeCodingServiceStub.createWestendService(
            specVersion: 9010,
            txVersion: 5
        )

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            networkType: chain,
                                                            keychain: keychain,
                                                            settings: settings)

        let view = MockCrowdloanContributionConfirmViewProtocol()
        let wireframe = MockCrowdloanContributionConfirmWireframeProtocol()

        let expectedAmount: Decimal = 0.1

        let presenter = try createPresenter(
            for: view,
            wireframe: wireframe,
            settings: settings,
            inputAmount: expectedAmount,
            runtimeService: runtimeCodingService
        )

        // when

        let assetReceived = XCTestExpectation()
        let feeReceived = XCTestExpectation()
        let estimatedRewardReceived = XCTestExpectation()
        let crowdloanReceived = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceiveAsset(viewModel: any()).then { viewModel in
                if viewModel.balance != nil {
                    assetReceived.fulfill()
                }
            }

            when(stub).didReceiveFee(viewModel: any()).then { viewModel in
                if viewModel != nil {
                    feeReceived.fulfill()
                }
            }

            when(stub).didReceiveEstimatedReward(viewModel: any()).then { viewModel in
                estimatedRewardReceived.fulfill()
            }

            when(stub).didReceiveCrowdloan(viewModel: any()).then { _ in
                crowdloanReceived.fulfill()
            }

            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()

            when(stub).isSetup.get.thenReturn(false, true)
        }

        presenter.setup()

        wait(
            for: [
                assetReceived,
                feeReceived,
                estimatedRewardReceived,
                crowdloanReceived
            ],
            timeout: 10
        )

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).complete(on: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        presenter.confirm()

        // then

        wait(for: [completionExpectation], timeout: 10)
    }

    private func createPresenter(
        for view: MockCrowdloanContributionConfirmViewProtocol,
        wireframe: MockCrowdloanContributionConfirmWireframeProtocol,
        settings: SettingsManagerProtocol,
        inputAmount: Decimal,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws -> CrowdloanContributionConfirmPresenter {
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let addressType = settings.selectedConnection.type
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        let interactor = createInteractor(asset: asset, settings: settings, runtimeService: runtimeService)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: addressType,
            limit: StakingConstants.maxAmount
        )

        let amountFormatterFactory = AmountFormatterFactory()

        let crowdloanViewModelFactory = CrowdloanContributionViewModelFactory(
            amountFormatterFactory: amountFormatterFactory,
            chainDateCalculator: ChainDateCalculator(),
            asset: asset
        )

        let dataValidatingFactory = CrowdloanDataValidatingFactory(
            presentable: wireframe,
            amountFormatterFactory: amountFormatterFactory,
            chain: addressType.chain,
            asset: asset
        )

        let presenter = CrowdloanContributionConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            contributionViewModelFactory: crowdloanViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            inputAmount: inputAmount,
            chain: addressType.chain,
            localizationManager: LocalizationManager.shared
        )

        interactor.presenter = presenter
        dataValidatingFactory.view = view
        presenter.view = view

        return presenter
    }

    private func createInteractor(
        asset: WalletAsset,
        settings: SettingsManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CrowdloanContributionConfirmInteractor {
        let chain = settings.selectedConnection.type.chain

        let providerFactory = SingleValueProviderFactoryStub
            .westendNominatorStub()
            .withBlockNumber(blockNumber: Self.currentBlockNumber)
            .withCrowdloanFunds(crowdloan.fundInfo)

        let extrinsicService = ExtrinsicServiceStub.dummy()

        let signingWrapper = try! DummySigner(cryptoType: .sr25519)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageTestFacade().createRepository()

        return CrowdloanContributionConfirmInteractor(
            paraId: crowdloan.paraId,
            selectedAccountAddress: settings.selectedAccount!.address,
            chain: chain,
            assetId: WalletAssetId(rawValue: asset.identifier)!,
            runtimeService: runtimeService,
            feeProxy: ExtrinsicFeeProxy(),
            extrinsicService: extrinsicService,
            signingWrapper: signingWrapper,
            accountRepository: AnyDataProviderRepository(accountRepository),
            crowdloanFundsProvider: providerFactory.crowdloanFunds,
            singleValueProviderFactory: providerFactory,
            operationManager: OperationManager()
        )
    }

}
