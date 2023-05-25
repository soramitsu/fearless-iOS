import XCTest
@testable import fearless
import RobinHood
import SoraFoundation
import Cuckoo

class AnalyticsRewardDetailsTests: XCTestCase {

    func testModule() {
        let viewModelFactory = MockAnalyticsRewardDetailsViewModelFactoryProtocol()
        let wireframe = MockAnalyticsRewardDetailsWireframeProtocol()
        let rewardModel = SubqueryRewardItemData(
            eventId: "111111-2",
            timestamp: 0,
            validatorAddress: "",
            era: 0,
            stashAddress: "",
            amount: 0,
            isReward: true
        )
        
        let asset = ChainModelGenerator.generateAssetWithId("887a17c7-1370-4de0-97dd-5422e294fa75", symbol: "dot")
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let presenter = AnalyticsRewardDetailsPresenter(
            rewardModel: rewardModel,
            interactor: MockAnalyticsRewardDetailsInteractorInputProtocol(),
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset
        )

        let createViewModelExpectation = XCTestExpectation()
        stub(viewModelFactory) { stub in
            when(stub).createViweModel(rewardModel: any()).then { _ in
                createViewModelExpectation.fulfill()
                return LocalizableResource { locale in
                    .init(eventId: "", date: "", type: "", amount: "")
                }
            }
        }

        let bindViewModelExpectation = XCTestExpectation()
        let view = MockAnalyticsRewardDetailsViewProtocol()

        stub(view) { stub in
            when(stub).bind(viewModel: any()).then { _ in
                bindViewModelExpectation.fulfill()
            }
            when(stub).localizationManager.get.thenReturn(LocalizationManager.shared)
        }
        presenter.view = view

        // Test module setup
        presenter.setup()

        wait(
            for: [createViewModelExpectation, bindViewModelExpectation],
            timeout: Constants.defaultExpectationDuration,
            enforceOrder: true
        )

        // Test 'block number' action
        let presentActionSheetExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).present(viewModel: any(), from: any()).then { _ in
                presentActionSheetExpectation.fulfill()
            }
        }
        presenter.handleEventIdAction()

        wait(
            for: [presentActionSheetExpectation],
            timeout: Constants.defaultExpectationDuration
        )
    }
}
