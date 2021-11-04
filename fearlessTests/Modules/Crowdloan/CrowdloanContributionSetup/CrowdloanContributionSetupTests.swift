import XCTest
@testable import fearless
import SoraKeystore
import CommonWallet
import FearlessUtils
import RobinHood
import SoraFoundation
import Cuckoo

class CrowdloanContributionSetupTests: XCTestCase {
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
            trieIndex: 1
        )
    )

    func testContributionSetupAndContinue() throws {
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

        let view = MockCrowdloanContributionSetupViewProtocol()
        let wireframe = MockCrowdloanContributionSetupWireframeProtocol()

        let presenter = try createPresenter(
            for: view,
            wireframe: wireframe,
            settings: settings, runtimeService: runtimeCodingService
        )

        // when

        let inputViewModelReceived = XCTestExpectation()
        let assetReceived = XCTestExpectation()
        let feeReceived = XCTestExpectation()
        let estimatedRewardReceived = XCTestExpectation()
        let crowdloanReceived = XCTestExpectation()
        let bonusReceived = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceiveInput(viewModel: any()).then { viewModel in
                inputViewModelReceived.fulfill()
            }

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

            when(stub).didReceiveBonus(viewModel: any()).then { _ in
                bonusReceived.fulfill()
            }

            when(stub).isSetup.get.thenReturn(false, true)
        }

        presenter.setup()

        wait(
            for: [
                inputViewModelReceived,
                assetReceived,
                feeReceived,
                estimatedRewardReceived,
                crowdloanReceived,
                bonusReceived
            ],
            timeout: 10
        )

        let expectedAmount: Decimal = 1.0

        presenter.updateAmount(expectedAmount)

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).showConfirmation(
                from: any(),
                paraId: any(),
                inputAmount: any(),
                bonusService: any(),
                customFlow: any(),
                ethereumAddress: any()
            ).then { (_, _, amount, _, _, _) in
                XCTAssertEqual(expectedAmount, amount)
                completionExpectation.fulfill()
            }
        }

        presenter.proceed()

        // then

        wait(for: [completionExpectation], timeout: 10)
    }

    private func createPresenter(
        for view: MockCrowdloanContributionSetupViewProtocol,
        wireframe: MockCrowdloanContributionSetupWireframeProtocol,
        settings: SettingsManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws -> CrowdloanContributionSetupPresenter {
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

        let presenter = CrowdloanContributionSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            contributionViewModelFactory: crowdloanViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chain: addressType.chain,
            localizationManager: LocalizationManager.shared,
            customFlow: nil
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
    ) -> CrowdloanContributionSetupInteractor {
        let chain = settings.selectedConnection.type.chain

        let providerFactory = SingleValueProviderFactoryStub
            .westendNominatorStub()
            .withBlockNumber(blockNumber: Self.currentBlockNumber)
            .withCrowdloanFunds(crowdloan.fundInfo)

        let extrinsicService = ExtrinsicServiceStub.dummy()
        let operationManager = OperationManagerFacade.sharedManager
        
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let crowdloanOperationFactory = CrowdloanOperationFactory(
            requestOperationFactory: storageRequestFactory,
            operationManager: operationManager
        )
        
        return CrowdloanContributionSetupInteractor(
            paraId: crowdloan.paraId,
            selectedAccountAddress: settings.selectedAccount!.address,
            chain: chain,
            assetId: WalletAssetId(rawValue: asset.identifier)!,
            runtimeService: runtimeService,
            feeProxy: ExtrinsicFeeProxy(),
            extrinsicService: extrinsicService,
            crowdloanFundsProvider: providerFactory.crowdloanFunds,
            singleValueProviderFactory: providerFactory,
            operationManager: operationManager,
            logger: Logger.shared,
            crowdloanOperationFactory: crowdloanOperationFactory,
            connection: nil,
            settings: settings
        )
    }
}
