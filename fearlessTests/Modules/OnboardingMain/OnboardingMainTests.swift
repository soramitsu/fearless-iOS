import XCTest
@testable import fearless
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

        presenter.activateSignup()

        // then

        verify(wireframe, times(1)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(0)).showWeb(url: any(), from: any(), style: any())
    }

    func testAccountRestore() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.activateAccountRestore()

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(1)).showAccountRestore(from: any())
        verify(wireframe, times(0)).showWeb(url: any(), from: any(), style: any())
    }

    func testTermsAndConditions() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.activateTerms()

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(1)).showWeb(url: ParameterMatcher { $0 == self.dummyLegalData.termsUrl },
                                            from: any(),
                                            style: any())
    }

    func testPrivacyPolicy() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.activatePrivacy()

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(1)).showWeb(url: ParameterMatcher { $0 == self.dummyLegalData.privacyPolicyUrl },
                                            from: any(),
                                            style: any())
    }

    // MARK: Private

    private func setupPresenterForWireframe(_ wireframe: MockOnboardingMainWireframeProtocol,
                                            view: MockOnboardingMainViewProtocol,
                                            legal: LegalData) -> OnboardingMainPresenter {
        let presenter = OnboardingMainPresenter(legalData: legal, locale: Locale.current)

        presenter.view = view
        presenter.wireframe = wireframe

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)
        }

        stub(wireframe) { stub in
            when(stub).showAccountRestore(from: any()).thenDoNothing()
            when(stub).showSignup(from: any()).thenDoNothing()
            when(stub).showWeb(url: any(), from: any(), style: any()).thenDoNothing()
        }

        return presenter
    }
}
