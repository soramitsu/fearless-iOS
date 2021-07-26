import XCTest
@testable import fearless
import Cuckoo
import RobinHood

class SelectValidatorsStartTests: XCTestCase {
    func testSetupValidators() throws {
        let allValidators = WestendStub.allValidators
        let recomendedValidators = WestendStub.recommendedValidators

        try performTest(
            for: nil,
            allValidators: allValidators,
            expectedRecommendedValidators: recomendedValidators,
            expectedViewModel: SelectValidatorsStartViewModel(
                phase: .setup,
                selectedCount: 0,
                totalCount: 16
            ),
            expectedCustomValidators: allValidators.map { $0.toSelected() }
        )
    }

    func testChangeValidators() throws {
        let allValidators = WestendStub.allValidators
        let recomendedValidators = WestendStub.recommendedValidators

        try performTest(
            for: recomendedValidators.map { $0.toSelected() },
            allValidators: allValidators,
            expectedRecommendedValidators: recomendedValidators,
            expectedViewModel: SelectValidatorsStartViewModel(
                phase: .update,
                selectedCount: recomendedValidators.count,
                totalCount: 16
            ),
            expectedCustomValidators: allValidators.map { $0.toSelected() }
        )
    }

    private func performTest(
        for selectedTargets: [SelectedValidatorInfo]?,
        allValidators: [ElectedValidatorInfo],
        expectedRecommendedValidators: [ElectedValidatorInfo],
        expectedViewModel: SelectValidatorsStartViewModel,
        expectedCustomValidators: [SelectedValidatorInfo]
    ) throws {
        // given

        let view = MockSelectValidatorsStartViewProtocol()
        let wireframe = MockSelectValidatorsStartWireframeProtocol()
        let operationFactory = MockValidatorOperationFactoryProtocol()

        let presenter = SelectValidatorsStartPresenter(initialTargets: nil)

        let runtimeService = try RuntimeCodingServiceStub.createWestendService()

        let interactor = SelectValidatorsStartInteractor(
            runtimeService: runtimeService,
            operationFactory: operationFactory,
            operationManager: OperationManager()
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        stub(operationFactory) { stub in
            when(stub).allElectedOperation().then { _ in
                CompoundOperationWrapper.createWithResult(allValidators)
            }
        }

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(viewModel: any()).then { viewModel in
                XCTAssertEqual(viewModel.phase, .setup)
                setupExpectation.fulfill()
            }
        }

        let generator = CustomValidatorListTestDataGenerator.self

        let recommended = generator
            .createSelectedValidators(from: expectedRecommendedValidators)

        stub(wireframe) { stub in
            when(stub).proceedToCustomList(
                from: any(),
                validatorList: any(),
                recommendedValidatorList: any(),
                selectedValidatorList: any(),
                maxTargets: any()).then { (_, validators, _, _ , _) in
                    XCTAssertEqual(
                        expectedCustomValidators.sorted {
                            $0.address.lexicographicallyPrecedes($1.address)
                        },
                        validators.sorted {
                            $0.address.lexicographicallyPrecedes($1.address)
                        })
            }

            when(stub).proceedToRecommendedList(from: any(), validatorList: any(), maxTargets: any()).then { (_, targets, _) in
                XCTAssertEqual(Set(recommended.map({ $0.address })),
                               Set(targets.map({ $0.address })))
            }
        }

        presenter.setup()

        // then

        wait(for: [setupExpectation], timeout: 10)

        presenter.selectRecommendedValidators()
        presenter.selectCustomValidators()

        verify(wireframe, times(1)).proceedToCustomList(from: any(), validatorList: any(), recommendedValidatorList: any(), selectedValidatorList: any(), maxTargets: any())
        verify(wireframe, times(1)).proceedToRecommendedList(from: any(), validatorList: any(), maxTargets: any())
    }
}
