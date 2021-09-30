import XCTest
@testable import fearless
import SoraFoundation
import SoraKeystore
import FearlessUtils
import Cuckoo
import BigInt

class CrowdloanListTests: XCTestCase {
    static let currentBlockNumber: BlockNumber = 1337

    let activeCrowdloans: [Crowdloan] = [
        Crowdloan(
            paraId: 2000,
            fundInfo: CrowdloanFunds(
                depositor: Data(repeating: 0, count: 32),
                verifier: nil,
                deposit: 100,
                raised: 100,
                end: currentBlockNumber + 100,
                cap: 1000,
                lastContribution: .never,
                firstPeriod: 100,
                lastPeriod: 101,
                trieIndex: 1)
        )
    ]

    let endedCrowdloans: [Crowdloan] = [
        Crowdloan(
            paraId: 2001,
            fundInfo: CrowdloanFunds(
                depositor: Data(repeating: 1, count: 32),
                verifier: nil,
                deposit: 100,
                raised: 1000,
                end: currentBlockNumber,
                cap: 1000,
                lastContribution: .never,
                firstPeriod: 100,
                lastPeriod: 101,
                trieIndex: 2)
        )
    ]

    let wonCrowdloans: [Crowdloan] = [
        Crowdloan(
            paraId: 2002,
            fundInfo: CrowdloanFunds(
                depositor: Data(repeating: 2, count: 32),
                verifier: nil,
                deposit: 100,
                raised: 100,
                end: currentBlockNumber + 100,
                cap: 1000,
                lastContribution: .never,
                firstPeriod: 100,
                lastPeriod: 101,
                trieIndex: 3)
        )
    ]

    let leaseInfo: ParachainLeaseInfoList = [
        ParachainLeaseInfo(paraId: 2000,
                           fundAccountId: Data(repeating: 10, count: 32),
                           leasedAmount: nil
        ),
        ParachainLeaseInfo(paraId: 2001,
                           fundAccountId: Data(repeating: 11, count: 32),
                           leasedAmount: nil
        ),
        ParachainLeaseInfo(paraId: 2002,
                           fundAccountId: Data(repeating: 12, count: 32),
                           leasedAmount: 1000
        )
    ]

    func testCrowdloansSuccessRetrieving() throws {
        // given

        let view = MockCrowdloanListViewProtocol()
        let wireframe = MockCrowdloanListWireframeProtocol()

        let expectedActiveParaIds: Set<ParaId> = activeCrowdloans
            .reduce(into: Set<ParaId>()) { (result, crowdloan) in
            result.insert(crowdloan.paraId)
        }

        let expectedCompletedParaIds: Set<ParaId> = (endedCrowdloans + wonCrowdloans)
            .reduce(into: Set<ParaId>()) { (result, crowdloan) in
            result.insert(crowdloan.paraId)
        }

        var actualViewModel: CrowdloansViewModel?

        let chainCompletionExpectation = XCTestExpectation()
        let listCompletionExpectation = XCTestExpectation()

        stub(view) { stub in
            stub.isSetup.get.thenReturn(false, true)

            stub.didReceive(listState: any()).then { state in
                if case let .loaded(viewModel) = state {
                    actualViewModel = viewModel

                    listCompletionExpectation.fulfill()
                }
            }

            stub.didReceive(chainInfo: any()).then { state in
                chainCompletionExpectation.fulfill()
            }
        }

        guard let presenter = try createPresenter(for: view, wireframe: wireframe) else {
            XCTFail("Initialization failed")
            return
        }

        // when

        presenter.setup()
        presenter.becomeOnline()

        // then

        wait(for: [listCompletionExpectation, chainCompletionExpectation], timeout: 10)

        let actualActiveParaIds = actualViewModel?.active?.crowdloans
            .reduce(into: Set<ParaId>()) { (result, crowdloan) in
                result.insert(crowdloan.paraId)
            } ?? Set<ParaId>()

        let actualCompletedParaIds = actualViewModel?.completed?.crowdloans
            .reduce(into: Set<ParaId>()) { (result, crowdloan) in
                result.insert(crowdloan.paraId)
            } ?? Set<ParaId>()

        XCTAssertEqual(expectedActiveParaIds, actualActiveParaIds)
        XCTAssertEqual(expectedCompletedParaIds, actualCompletedParaIds)
    }

    private func createPresenter(
        for view: MockCrowdloanListViewProtocol,
        wireframe: MockCrowdloanListWireframeProtocol
    ) throws -> CrowdloanListPresenter? {
        let localizationManager = LocalizationManager.shared
        let selectedAccount = AccountGenerator.generateMetaAccount()
        let selectedChain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            hasCrowdloans: true
        )

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [selectedChain])

        let maybeInteractor = createInteractor(
            selectedAccount: selectedAccount,
            selectedChain: selectedChain,
            chainRegistry: chainRegistry
        )

        guard let interactor = maybeInteractor else {
            return nil
        }

        let wireframe = MockCrowdloanListWireframeProtocol()

        let viewModelFactory = CrowdloansViewModelFactory(
            amountFormatterFactory: AssetBalanceFormatterFactory()
        )

        let presenter = CrowdloanListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return presenter
    }

    private func createInteractor(
        selectedAccount: MetaAccountModel,
        selectedChain: ChainModel,
        chainRegistry: ChainRegistryProtocol
    ) -> CrowdloanListInteractor? {
        let settings = CrowdloanChainSettings(
            storageFacade: SubstrateStorageTestFacade(),
            settings: InMemorySettingsManager(),
            operationQueue: OperationQueue()
        )

        settings.save(value: selectedChain)

        let crowdloans = activeCrowdloans + endedCrowdloans + wonCrowdloans
        let crowdloanOperationFactory = CrowdloansOperationFactoryStub(
            crowdloans: crowdloans,
            parachainLeaseInfo: leaseInfo
        )

        let crowdloanRemoteSubscriptionService = MockCrowdloanRemoteSubscriptionServiceProtocol()
            .applyDefaultStub()

        let crowdloanLocalSubscriptionService = CrowdloanLocalSubscriptionFactoryStub(
            blockNumber: Self.currentBlockNumber
        )

        let walletLocalSubscriptionService = WalletLocalSubscriptionFactoryStub(
            balance: BigUInt(1e+18)
        )

        guard let crowdloanInfoURL = selectedChain.externalApi?.crowdloans?.url else {
            return nil
        }

        let jsonProviderFactory = JsonDataProviderFactoryStub(
            sources: [
                crowdloanInfoURL: CrowdloanDisplayInfoList()
            ]
        )

        return CrowdloanListInteractor(
            selectedMetaAccount: selectedAccount,
            settings: settings,
            chainRegistry: chainRegistry,
            crowdloanOperationFactory: crowdloanOperationFactory,
            crowdloanRemoteSubscriptionService: crowdloanRemoteSubscriptionService,
            crowdloanLocalSubscriptionFactory: crowdloanLocalSubscriptionService,
            walletLocalSubscriptionFactory: walletLocalSubscriptionService,
            jsonDataProviderFactory: jsonProviderFactory,
            operationManager: OperationManagerFacade.sharedManager
        )
    }
}
