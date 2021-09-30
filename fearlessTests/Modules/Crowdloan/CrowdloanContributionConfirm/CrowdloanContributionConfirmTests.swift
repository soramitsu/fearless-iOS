import XCTest
@testable import fearless
import SoraKeystore
import CommonWallet
import RobinHood
import SoraFoundation
import Cuckoo
import BigInt

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

        let selectedAccount = AccountGenerator.generateMetaAccount()
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 42,
            assetPresicion: 12,
            hasCrowdloans: true
        )

        let asset = chain.assets.first!

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chain])

        let view = MockCrowdloanContributionConfirmViewProtocol()
        let wireframe = MockCrowdloanContributionConfirmWireframeProtocol()

        let expectedAmount: Decimal = 1.0

        guard let presenter = try createPresenter(
            for: view,
            wireframe: wireframe,
            chainRegistry: chainRegistry,
            inputAmount: expectedAmount,
            selectedMetaAccount: selectedAccount,
            chain: chain,
            asset: asset
        ) else {
            XCTFail("Unexpected empty presenter")
            return
        }

        // when

        let assetReceived = XCTestExpectation()
        let feeReceived = XCTestExpectation()
        let estimatedRewardReceived = XCTestExpectation()
        let crowdloanReceived = XCTestExpectation()
        let bonusReceived = XCTestExpectation()

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

            when(stub).didReceiveBonus(viewModel: any()).then { _ in
                bonusReceived.fulfill()
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
                crowdloanReceived,
                bonusReceived
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
        chainRegistry: ChainRegistryProtocol,
        inputAmount: Decimal,
        selectedMetaAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel
    ) throws -> CrowdloanContributionConfirmPresenter? {

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

        let presenter = CrowdloanContributionConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            contributionViewModelFactory: crowdloanViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            inputAmount: inputAmount,
            bonusRate: nil,
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
    ) -> CrowdloanContributionConfirmInteractor? {
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

        guard let signingWrapper = try? DummySigner(cryptoType: MultiassetCryptoType.sr25519) else {
            return nil
        }

        return CrowdloanContributionConfirmInteractor(
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
            signingWrapper: signingWrapper,
            bonusService: nil,
            operationManager: OperationManager()
        )
    }

}
