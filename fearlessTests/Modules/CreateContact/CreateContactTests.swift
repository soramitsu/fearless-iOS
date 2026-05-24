import XCTest
import UIKit
import FearlessFoundation
import SSFModels
@testable import fearless

final class CreateContactTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenSetsUpInteractorAndProvidesViewModel() {
        let interactor = CreateContactInteractorInputSpy()
        let viewModel = CreateContactViewModel(address: "address", chainName: "Test Chain", iconViewModel: nil)
        let factory = CreateContactViewModelFactorySpy(viewModel: viewModel)
        let chain = makeChain()
        let presenter = createPresenter(
            interactor: interactor,
            viewModelFactory: factory,
            chain: chain,
            address: "address"
        )
        let view = CreateContactViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(factory.receivedAddress, "address")
        XCTAssertEqual(factory.receivedChain?.chainId, chain.chainId)
        XCTAssertEqual(view.viewModel?.chainName, "Test Chain")
    }

    func testTextChanges_whenNameOrAddressMissing_thenReportsInvalidState() {
        let presenter = createPresenter()
        let view = CreateContactViewSpy()

        presenter.didLoad(view: view)
        presenter.nameTextDidChanged("Alice")

        XCTAssertEqual(view.validStates, [false])
    }

    func testTextChanges_whenNameAndValidAddressProvided_thenReportsValidState() {
        let interactor = CreateContactInteractorInputSpy(isValidAddress: true)
        let presenter = createPresenter(interactor: interactor)
        let view = CreateContactViewSpy()

        presenter.didLoad(view: view)
        presenter.nameTextDidChanged("Alice")
        presenter.addressTextDidChanged("valid-address")

        XCTAssertEqual(interactor.validatedAddress, "valid-address")
        XCTAssertEqual(view.validStates, [false, true])
    }

    func testTextChanges_whenInteractorRejectsAddress_thenReportsInvalidState() {
        let interactor = CreateContactInteractorInputSpy(isValidAddress: false)
        let presenter = createPresenter(interactor: interactor)
        let view = CreateContactViewSpy()

        presenter.didLoad(view: view)
        presenter.nameTextDidChanged("Alice")
        presenter.addressTextDidChanged("invalid-address")

        XCTAssertEqual(view.validStates, [false, false])
    }

    func testDidTapCreateButton_whenNameAndAddressExist_thenOutputsContactAndDismisses() {
        let router = CreateContactRouterSpy()
        let moduleOutput = CreateContactModuleOutputSpy()
        let chain = makeChain()
        let presenter = createPresenter(
            router: router,
            moduleOutput: moduleOutput,
            chain: chain
        )
        let view = CreateContactViewSpy()

        presenter.didLoad(view: view)
        presenter.nameTextDidChanged("Alice")
        presenter.addressTextDidChanged("valid-address")
        presenter.didTapCreateButton()

        XCTAssertEqual(
            moduleOutput.createdContact,
            Contact(name: "Alice", address: "valid-address", chainId: chain.chainId)
        )
        XCTAssertTrue(router.dismissedView === view)
    }

    func testDidTapBackButton_whenViewLoaded_thenDismissesView() {
        let router = CreateContactRouterSpy()
        let presenter = createPresenter(router: router)
        let view = CreateContactViewSpy()

        presenter.didLoad(view: view)
        presenter.didTapBackButton()

        XCTAssertTrue(router.dismissedView === view)
    }

    func testApplyLocalization_whenViewLoaded_thenProvidesLocale() {
        let presenter = createPresenter()
        let view = CreateContactViewSpy()

        presenter.didLoad(view: view)
        presenter.applyLocalization()

        XCTAssertEqual(view.receivedLocale, LocalizationManager.shared.selectedLocale)
    }

    private func createPresenter(
        interactor: CreateContactInteractorInput = CreateContactInteractorInputSpy(),
        router: CreateContactRouterInput = CreateContactRouterSpy(),
        viewModelFactory: CreateContactViewModelFactoryProtocol = CreateContactViewModelFactorySpy(),
        moduleOutput: CreateContactModuleOutput = CreateContactModuleOutputSpy(),
        chain: ChainModel = ChainModelGenerator.generate(count: 1).first!,
        address: String? = nil
    ) -> CreateContactPresenter {
        CreateContactPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            viewModelFactory: viewModelFactory,
            moduleOutput: moduleOutput,
            chain: chain,
            address: address
        )
    }

    private func makeChain() -> ChainModel {
        ChainModelGenerator.generate(count: 1).first!
    }
}

private final class CreateContactViewSpy: CreateContactViewInput {
    let controller = UIViewController()
    let isSetup = false
    private(set) var receivedLocale: Locale?
    private(set) var viewModel: CreateContactViewModel?
    private(set) var validStates: [Bool] = []

    func didReceive(locale: Locale) {
        receivedLocale = locale
    }

    func didReceive(viewModel: CreateContactViewModel) {
        self.viewModel = viewModel
    }

    func updateState(isValid: Bool) {
        validStates.append(isValid)
    }
}

private final class CreateContactInteractorInputSpy: CreateContactInteractorInput {
    private(set) weak var output: CreateContactInteractorOutput?
    private(set) var validatedAddress: String?
    private(set) var validatedChain: ChainModel?
    private let isValidAddress: Bool

    init(isValidAddress: Bool = true) {
        self.isValidAddress = isValidAddress
    }

    func setup(with output: CreateContactInteractorOutput) {
        self.output = output
    }

    func validate(address: String, for chain: ChainModel) -> Bool {
        validatedAddress = address
        validatedChain = chain
        return isValidAddress
    }
}

private final class CreateContactRouterSpy: CreateContactRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) var presentedError: Error?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        return true
    }

    func present(
        viewModel _: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(
        message _: String?,
        title _: String,
        from _: ControllerBackedProtocol?
    ) {}
}

private final class CreateContactViewModelFactorySpy: CreateContactViewModelFactoryProtocol {
    private(set) var receivedAddress: String?
    private(set) var receivedChain: ChainModel?
    private let viewModel: CreateContactViewModel

    init(
        viewModel: CreateContactViewModel = CreateContactViewModel(
            address: nil,
            chainName: "Chain",
            iconViewModel: nil
        )
    ) {
        self.viewModel = viewModel
    }

    func buildViewModel(address: String?, chain: ChainModel) -> CreateContactViewModel {
        receivedAddress = address
        receivedChain = chain
        return viewModel
    }
}

private final class CreateContactModuleOutputSpy: CreateContactModuleOutput {
    private(set) var createdContact: Contact?

    func didCreate(contact: Contact) {
        createdContact = contact
    }
}
