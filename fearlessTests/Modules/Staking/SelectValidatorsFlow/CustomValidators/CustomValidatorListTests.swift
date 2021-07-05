import XCTest
@testable import fearless
import Cuckoo
import FearlessUtils
import SoraKeystore
import SoraFoundation

class CustomValidatorListTests: XCTestCase {
    private func createSelectedValidators(from validators: [ElectedValidatorInfo]) -> [SelectedValidatorInfo] {
        validators.map {
            SelectedValidatorInfo(
                address: $0.address,
                identity: $0.identity,
                stakeInfo: ValidatorStakeInfo(
                    nominators: $0.nominators,
                    totalStake: $0.totalStake,
                    stakeReturn: $0.stakeReturn,
                    maxNominatorsRewarded: $0.maxNominatorsRewarded
                ),
                commission: $0.comission,
                hasSlashes: $0.hasSlashes
            )
        }
    }

    func testSetup() {
        // given
        let settings = InMemorySettingsManager()

        let chain = Chain.westend

        let view = MockCustomValidatorListViewProtocol()
        let wireframe = MockCustomValidatorListWireframeProtocol()

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let assetId = WalletAssetId(
            rawValue: primitiveFactory.createAssetForAddressType(chain.addressType).identifier
        )!

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let viewModelFactory = CustomValidatorListViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let interactor = CustomValidatorListInteractor(
            singleValueProviderFactory: SingleValueProviderFactoryStub.westendNominatorStub(),
            assetId: assetId
        )

        let fullValidatorList = createSelectedValidators(from: WestendStub.recommendedValidators)
        let recommendedValidatorList = createSelectedValidators(from: WestendStub.recommendedValidators)

        let presenter = CustomValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            fullValidatorList: fullValidatorList,
            recommendedValidatorList: recommendedValidatorList,
            maxTargets: 16
        )

        presenter.view = view

        // when

        let reloadExpectation = XCTestExpectation()
        let filterExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).setFilterAppliedState(to: any()).then { _ in
                filterExpectation.fulfill()
            }

            when(stub).reload(any(), at: any()).then { (viewModel, _) in
                XCTAssertEqual(WestendStub.recommendedValidators.count, viewModel.cellViewModels.count)
                reloadExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [reloadExpectation, filterExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
