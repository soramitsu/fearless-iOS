import XCTest
@testable import fearless
import FearlessUtils
import Cuckoo

class OnboardingMainTests: XCTestCase {

    let dummyLegalData = LegalData(termsUrl: URL(string: "https://google.com")!,
                                   privacyPolicyUrl: URL(string: "https://github.com")!)

    func testSignup() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.setup()
        presenter.activateSignup()

        // then

        verify(wireframe, times(1)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(0)).showWeb(url: any(), from: any(), style: any())
        verify(wireframe, times(0)).showKeystoreImport(from: any())
    }

    func testAccountRestore() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.setup()
        presenter.activateAccountRestore()

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(1)).showAccountRestore(from: any())
        verify(wireframe, times(0)).showWeb(url: any(), from: any(), style: any())
        verify(wireframe, times(0)).showKeystoreImport(from: any())
    }

    func testTermsAndConditions() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.setup()
        presenter.activateTerms()

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(1)).showWeb(url: ParameterMatcher { $0 == self.dummyLegalData.termsUrl },
                                            from: any(),
                                            style: any())
        verify(wireframe, times(0)).showKeystoreImport(from: any())
    }

    func testPrivacyPolicy() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.setup()
        presenter.activatePrivacy()

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(1)).showWeb(url: ParameterMatcher { $0 == self.dummyLegalData.privacyPolicyUrl },
                                            from: any(),
                                            style: any())
        verify(wireframe, times(0)).showKeystoreImport(from: any())
    }

    func testKeystoreImportSuggestion() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let keystoreImportService = KeystoreImportService(logger: Logger.shared)

        let presenter = setupPresenterForWireframe(wireframe,
                                                   view: view,
                                                   legal: dummyLegalData,
                                                   keystoreImportService: keystoreImportService)

        // when

        presenter.setup()

        XCTAssertTrue(keystoreImportService.handle(url: KeystoreDefinition.validURL))

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(0)).showWeb(url: any(),
                                            from: any(),
                                            style: any())
        verify(wireframe, times(1)).showKeystoreImport(from: any())
    }

    // MARK: Private

    private func setupPresenterForWireframe(_ wireframe: MockOnboardingMainWireframeProtocol,
                                            view: MockOnboardingMainViewProtocol,
                                            legal: LegalData,
                                            keystoreImportService: KeystoreImportServiceProtocol = KeystoreImportService(logger: Logger.shared))
        -> OnboardingMainPresenter {
        let presenter = OnboardingMainPresenter(legalData: legal, locale: Locale.current)

        presenter.view = view
        presenter.wireframe = wireframe

        let interactor = OnboardingMainInteractor(keystoreImportService: keystoreImportService)
        interactor.presenter = presenter
        presenter.interactor = interactor

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)
        }

        stub(wireframe) { stub in
            when(stub).showAccountRestore(from: any()).thenDoNothing()
            when(stub).showSignup(from: any()).thenDoNothing()
            when(stub).showWeb(url: any(), from: any(), style: any()).thenDoNothing()
            when(stub).showKeystoreImport(from: any()).thenDoNothing()
        }

        return presenter
    }
}
