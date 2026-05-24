import XCTest
import UIKit
import FearlessFoundation
@testable import fearless

final class OnboardingStartTests: XCTestCase {
    func testDidLoad_whenViewIsProvided_thenSetsUpInteractor() throws {
        let interactor = OnboardingStartInteractorInputSpy()
        let presenter = try createPresenter(interactor: interactor)
        let view = OnboardingStartViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
    }

    func testDidTapStartButton_whenTapped_thenStartsOnboardingWithConfig() throws {
        let expectedConfig = try Self.makeOnboardingConfig(minVersion: "2.0.0")
        let router = OnboardingStartRouterSpy()
        let presenter = try createPresenter(router: router, config: expectedConfig)

        presenter.didTapStartButton()

        XCTAssertEqual(router.startedConfig?.minVersion, expectedConfig.minVersion)
        XCTAssertEqual(router.startedConfig?.background, expectedConfig.background)
    }

    private func createPresenter(
        interactor: OnboardingStartInteractorInput = OnboardingStartInteractorInputSpy(),
        router: OnboardingStartRouterInput = OnboardingStartRouterSpy(),
        config: OnboardingConfigWrapper? = nil
    ) throws -> OnboardingStartPresenter {
        let resolvedConfig: OnboardingConfigWrapper
        if let config {
            resolvedConfig = config
        } else {
            resolvedConfig = try Self.makeOnboardingConfig()
        }

        return OnboardingStartPresenter(
            interactor: interactor,
            router: router,
            config: resolvedConfig,
            localizationManager: LocalizationManager.shared
        )
    }
}

private final class OnboardingStartViewSpy: OnboardingStartViewInput {
    let controller = UIViewController()
    let isSetup = false
}

private final class OnboardingStartInteractorInputSpy: OnboardingStartInteractorInput {
    private(set) weak var output: OnboardingStartInteractorOutput?

    func setup(with output: OnboardingStartInteractorOutput) {
        self.output = output
    }
}

private final class OnboardingStartRouterSpy: OnboardingStartRouterInput {
    private(set) var startedConfig: OnboardingConfigWrapper?

    func startOnboarding(config: OnboardingConfigWrapper) {
        startedConfig = config
    }
}

private extension OnboardingStartTests {
    static func makeOnboardingConfig(minVersion: String = "1.0.0") throws -> OnboardingConfigWrapper {
        let page: [String: Any] = [
            "title": [
                "text": "Own your crypto",
                "color": "#FFFFFF"
            ],
            "description": "Start safely.",
            "image": "https://fearlesswallet.io/onboarding.png"
        ]

        let config: [String: Any] = [
            "new": [page],
            "regular": [page]
        ]

        let wrapper: [String: Any] = [
            "en-EN": config,
            "minVersion": minVersion,
            "background": "https://fearlesswallet.io/background.png"
        ]

        let data = try JSONSerialization.data(withJSONObject: ["iOS": [wrapper]], options: [])
        let platform = try JSONDecoder().decode(OnboardingConfigPlatform.self, from: data)
        return try XCTUnwrap(platform.ios.first)
    }
}
