import XCTest
@testable import fearless
import SoraFoundation
import SoraKeystore
import FearlessUtils
import Cuckoo

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

        let completionExpectation = XCTestExpectation()

        stub(view) { stub in
            stub.isSetup.get.thenReturn(false, true)

            stub.didReceive(state: any()).then { state in
                if case let .loaded(viewModel) = state {
                    actualViewModel = viewModel

                    completionExpectation.fulfill()
                }
            }
        }

        guard let presenter = try createPresenter(for: view, wireframe: wireframe) else {
            XCTFail("Initialization failed")
            return
        }

        // when

        presenter.setup()

        // then

        wait(for: [completionExpectation], timeout: 10)

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
        let chain = Chain.westend
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        try! AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                             networkType: chain,
                                                             keychain: keychain,
                                                             settings: settings)

        let runtimeCodingService = try RuntimeCodingServiceStub.createWestendService(
            specVersion: 9010,
            txVersion: 5
        )

        guard let interactor = createInteractor(
                settings: settings,
                runtimeService: runtimeCodingService
        ) else {
            return nil
        }

        let wireframe = CrowdloanListWireframe()

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(chain.addressType)

        let viewModelFactory = CrowdloansViewModelFactory(
            amountFormatterFactory: AmountFormatterFactory(),
            asset: asset,
            chain: chain
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
        settings: SettingsManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CrowdloanListInteractor? {
        guard let selectedAddress = settings.selectedAccount?.address else {
            return nil
        }

        let chain = settings.selectedConnection.type.chain

        let connection = MockJSONRPCEngine()
        let operationManager = OperationManagerFacade.sharedManager

        let providerFactory = SingleValueProviderFactoryStub
            .westendNominatorStub()
            .withBlockNumber(blockNumber: Self.currentBlockNumber)
            .withJSON(value: CrowdloanDisplayInfoList(), for: chain.crowdloanDisplayInfoURL())

        let crowdloans = activeCrowdloans + endedCrowdloans + wonCrowdloans
        let crowdloanOperationFactory = CrowdloansOperationFactoryStub(
            crowdloans: crowdloans,
            parachainLeaseInfo: leaseInfo
        )

        return CrowdloanListInteractor(
            selectedAddress: selectedAddress,
            runtimeService: runtimeService,
            crowdloanOperationFactory: crowdloanOperationFactory,
            connection: connection,
            singleValueProviderFactory: providerFactory,
            chain: chain,
            operationManager: operationManager,
            logger: Logger.shared
        )
    }
}
