import XCTest
import Cuckoo
import FearlessUtils
import SoraFoundation
import SoraKeystore
@testable import fearless

class StakingRewardDetailsTests: XCTestCase {

    func testSetupAndHandlePayout() {
        let chain = Chain.westend
        let settings = InMemorySettingsManager()

        let view = MockStakingRewardDetailsViewProtocol()
        let wireframe = MockStakingRewardDetailsWireframeProtocol()

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(chain.addressType)
        let assetId = WalletAssetId(rawValue: asset.identifier)!
        let providerFactory = SingleValueProviderFactory.shared
        let priceProvider = providerFactory.getPriceProvider(for: assetId)
        let interactor = StakingRewardDetailsInteractor(priceProvider: priceProvider)

        let payoutInfo = PayoutInfo(
            era: 100,
            validator: Data(),
            reward: 1,
            identity: nil
        )
        let input = StakingRewardDetailsInput(
            payoutInfo: payoutInfo,
            chain: chain,
            activeEra: 101,
            historyDepth: 84
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: input.chain.addressType,
            limit: StakingConstants.maxAmount
        )
        let viewModelFactory = StakingRewardDetailsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            iconGenerator: PolkadotIconGenerator()
        )
        let presenter = StakingRewardDetailsPresenter(
            input: input,
            viewModelFactory: viewModelFactory
        )
        presenter.wireframe = wireframe
        presenter.view = view
        presenter.interactor = interactor

        let rowsExpectation = XCTestExpectation(description: "rows count is equal to 4")
        stub(view) { stub in
            when(stub).reload(with: any()).then { resource in
                let rows = resource.value(for: .current).rows
                if rows.count == 4 {
                    rowsExpectation.fulfill()
                }
            }
        }

        // when
        presenter.setup()
        // then
        wait(for: [rowsExpectation], timeout: Constants.defaultExpectationDuration)

        let handlePayoutActionExpectation = XCTestExpectation(description: "wireframe method is called")
        stub(wireframe) { stub in
            when(stub).showPayoutConfirmation(from: any(), payoutInfo: any()).then { _ in
                handlePayoutActionExpectation.fulfill()
            }
        }

        // when
        presenter.handlePayoutAction()
        // then
        wait(for: [handlePayoutActionExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
