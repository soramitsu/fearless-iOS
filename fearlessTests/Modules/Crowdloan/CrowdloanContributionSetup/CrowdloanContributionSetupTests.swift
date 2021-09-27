import XCTest
@testable import fearless
import SoraKeystore
import CommonWallet
import RobinHood
import SoraFoundation
import Cuckoo
import BigInt

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
            trieIndex: 1)
    )

    func testContributionSetupAndContinue() throws {
        // given

        let selectedAccount = AccountGenerator.generateMetaAccount()
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 42,
            assetPresicion: 12,
            hasCrowdloans: true
        )

        let asset = chain.assets.first!

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chain])

        let view = MockCrowdloanContributionSetupViewProtocol()
        let wireframe = MockCrowdloanContributionSetupWireframeProtocol()

        guard let presenter = try createPresenter(
            for: view,
            wireframe: wireframe,
            chainRegistry: chainRegistry,
            selectedMetaAccount: selectedAccount,
            chain: chain,
            asset: asset
        ) else {
            XCTFail("Unexpected missing presenter")
            return
        }

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
                bonusService: any()
            ).then { (_, _, amount, _) in
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
        chainRegistry: ChainRegistryProtocol,
        selectedMetaAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel
    ) throws -> CrowdloanContributionSetupPresenter? {
        guard let interactor = createInteractor(
            chainRegistry: chainRegistry,
            selectedMetaAccount: selectedMetaAccount,
            chain: chain,
            asset: asset
        ) else {
            return nil
        }

        let assetInfo = asset.displayInfo(with: chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let crowdloanViewModelFactory = CrowdloanContributionViewModelFactory(
            assetInfo: assetInfo,
            chainDateCalculator: ChainDateCalculator()
        )

        let dataValidatingFactory = CrowdloanDataValidatingFactory(
            presentable: wireframe,
            assetInfo: assetInfo
        )

        let presenter = CrowdloanContributionSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            contributionViewModelFactory: crowdloanViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            localizationManager: LocalizationManager.shared
        )

        interactor.presenter = presenter
        dataValidatingFactory.view = view
        presenter.view = view

        return presenter
    }

    private func createInteractor(
        chainRegistry: ChainRegistryProtocol,
        selectedMetaAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel
    ) -> CrowdloanContributionSetupInteractor? {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        guard let crowdloanInfoUrl = chain.externalApi?.crowdloans?.url else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceStub.dummy()

        let crowdloanSubscriptionFactory = CrowdloanLocalSubscriptionFactoryStub(
            blockNumber: Self.currentBlockNumber,
            crowdloanFunds: crowdloan.fundInfo
        )

        let walletSubscriptionFactory = WalletLocalSubscriptionFactoryStub(
            balance: BigUInt(1e+18)
        )

        let priceProviderFactory = PriceProviderFactoryStub(
            priceData: PriceData(price: "100", usdDayChange: 0.01)
        )

        let jsonProviderFactory = JsonDataProviderFactoryStub(
            sources: [crowdloanInfoUrl: CrowdloanDisplayInfoList()]
        )

        return CrowdloanContributionSetupInteractor(
            paraId: crowdloan.paraId,
            selectedMetaAccount: selectedMetaAccount,
            chain: chain,
            asset: asset,
            runtimeService: runtimeService,
            feeProxy: ExtrinsicFeeProxy(),
            extrinsicService: extrinsicService,
            crowdloanLocalSubscriptionFactory: crowdloanSubscriptionFactory,
            walletLocalSubscriptionFactory: walletSubscriptionFactory,
            priceLocalSubscriptionFactory: priceProviderFactory,
            jsonLocalSubscriptionFactory: jsonProviderFactory,
            operationManager: OperationManager()
        )
    }
}
