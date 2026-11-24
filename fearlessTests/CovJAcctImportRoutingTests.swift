import XCTest
import UIKit
import SSFModels
import SoraFoundation
@testable import fearless

/// Unit-test launches skip the app's URL handlers, so factories that need the keystore import service get one here.
enum CovJAcctURLHandling {
    static func withKeystoreService<T>(_ body: () throws -> T) rethrows -> T {
        let installed: KeystoreImportServiceProtocol? = URLHandlingService.shared.findService()
        if installed == nil {
            URLHandlingService.shared.setup(children: [KeystoreImportService(logger: Logger.shared)])
        }
        defer {
            if installed == nil {
                URLHandlingService.shared.setup(children: [])
            }
        }
        return try body()
    }
}

final class CovJAcctImportRoutingTests: XCTestCase {
    private typealias PickerController = ModalPickerViewController<TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel>

    private let stepData = AccountCreationStep.SubstrateStepData(
        sourceType: .seed, source: "0x" + String(repeating: "11", count: 32), username: "Step",
        password: "", cryptoType: .sr25519, derivationPath: ""
    )

    private func onboardingView<F: AccountImportViewFactoryProtocol>(_: F.Type, source: AccountImportSource) -> AccountImportViewProtocol? {
        F.createViewForOnboarding(defaultSource: source)
    }

    func testViewFactoriesBuildControllersWhenKeystoreServiceIsInstalled() throws {
        try CovJAcctURLHandling.withKeystoreService {
            let onboarding = try XCTUnwrap(AccountImportViewFactory.createViewForOnboarding(
                defaultSource: .keystore, flow: .wallet(step: .substrate)
            ))
            XCTAssertTrue(onboarding.controller is AccountImportViewController)
            XCTAssertNotNil((onboarding.controller as? AccountImportViewController)?.localizationManager)

            let adding = try XCTUnwrap(AccountImportViewFactory.createViewForAdding(defaultSource: .seed, .wallet(step: .substrate)))
            XCTAssertTrue(adding.controller is AccountImportViewController)
            let switching = try XCTUnwrap(AccountImportViewFactory.createViewForSwitch())
            XCTAssertTrue(switching.controller is AccountImportViewController)
            let viaProtocol = try XCTUnwrap(onboardingView(AccountImportViewFactory.self, source: .seed))
            XCTAssertTrue(viaProtocol.controller is AccountImportViewController)
            XCTAssertFalse(viaProtocol.controller.isViewLoaded)
        }
    }

    func testOnboardingWireframePushesEthereumStepAndPresentsPickers() throws {
        let wireframe = AccountImportWireframe()
        let view = CovJAcctImportViewStub()
        let host = try CovJHostedView(controller: view)
        defer { host.close() }

        CovJAcctURLHandling.withKeystoreService {
            wireframe.showEthereumStep(from: view, with: stepData)
        }
        XCTAssertEqual(host.navigation.viewControllers.count, 2)
        XCTAssertTrue(host.top is AccountImportViewController)

        let sourceHost = try CovJHostedView(controller: CovJAcctImportViewStub())
        defer { sourceHost.close() }
        let sourceView = try XCTUnwrap(sourceHost.controller as? CovJAcctImportViewStub)
        wireframe.presentSourceTypeSelection(
            from: sourceView, availableSources: AccountImportSource.allCases, selectedSource: .seed, delegate: nil, context: nil
        )
        XCTAssertTrue(sourceHost.navigation.presentedViewController is PickerController)

        let cryptoHost = try CovJHostedView(controller: CovJAcctImportViewStub())
        defer { cryptoHost.close() }
        let cryptoView = try XCTUnwrap(cryptoHost.controller as? CovJAcctImportViewStub)
        wireframe.presentCryptoTypeSelection(
            from: cryptoView, availableTypes: CryptoType.allCases, selectedType: .ed25519, delegate: nil, context: nil
        )
        XCTAssertTrue(cryptoHost.navigation.presentedViewController is PickerController)

        let emptyHost = try CovJHostedView(controller: CovJAcctImportViewStub())
        defer { emptyHost.close() }
        let emptyView = try XCTUnwrap(emptyHost.controller as? CovJAcctImportViewStub)
        wireframe.presentSourceTypeSelection(from: emptyView, availableSources: [], selectedSource: .seed, delegate: nil, context: nil)
        wireframe.presentCryptoTypeSelection(from: emptyView, availableTypes: [], selectedType: .sr25519, delegate: nil, context: nil)
        XCTAssertNil(emptyHost.navigation.presentedViewController)
    }

    func testOnboardingWireframeClosesChainImportByPopping() throws {
        let wireframe = AccountImportWireframe()
        let host = try CovJHostedView()
        defer { host.close() }
        let view = CovJAcctImportViewStub()
        host.navigation.pushViewController(view, animated: false)
        let model = UniqueChainModel(meta: AccountGenerator.generateMetaAccount(), chain: CovJFixture.chain())

        wireframe.proceed(from: view, flow: .chain(model: model))

        XCTAssertTrue(CovJWait.until { host.navigation.viewControllers.count == 1 })
        XCTAssertTrue(host.top === host.controller)
    }

    func testAddAccountWireframePushesEthereumStepAndPresentsPickers() throws {
        let wireframe = AddAccount.AccountImportWireframe()
        let view = CovJAcctImportViewStub()
        let host = try CovJHostedView(controller: view)
        defer { host.close() }

        wireframe.proceed(from: nil, flow: .wallet(step: .substrate))
        CovJAcctURLHandling.withKeystoreService {
            wireframe.showEthereumStep(from: view, with: stepData)
        }
        XCTAssertEqual(host.navigation.viewControllers.count, 2)
        XCTAssertTrue(host.top is AccountImportViewController)

        let sourceHost = try CovJHostedView(controller: CovJAcctImportViewStub())
        defer { sourceHost.close() }
        let sourceView = try XCTUnwrap(sourceHost.controller as? CovJAcctImportViewStub)
        wireframe.presentSourceTypeSelection(
            from: sourceView, availableSources: [.mnemonic, .seed], selectedSource: .mnemonic, delegate: nil, context: nil
        )
        XCTAssertTrue(sourceHost.navigation.presentedViewController is PickerController)

        let cryptoHost = try CovJHostedView(controller: CovJAcctImportViewStub())
        defer { cryptoHost.close() }
        let cryptoView = try XCTUnwrap(cryptoHost.controller as? CovJAcctImportViewStub)
        wireframe.presentCryptoTypeSelection(
            from: cryptoView, availableTypes: [.sr25519, .ecdsa], selectedType: .ecdsa, delegate: nil, context: nil
        )
        XCTAssertTrue(cryptoHost.navigation.presentedViewController is PickerController)

        wireframe.presentSourceTypeSelection(from: cryptoView, availableSources: [], selectedSource: .seed, delegate: nil, context: nil)
        wireframe.presentCryptoTypeSelection(from: sourceView, availableTypes: [], selectedType: .ecdsa, delegate: nil, context: nil)
        XCTAssertEqual(host.navigation.viewControllers.count, 2)
    }

    func testSwitchAccountWireframePopsToRootAndPresentsPickers() throws {
        let wireframe = SwitchAccount.AccountImportWireframe()
        let host = try CovJHostedView()
        defer { host.close() }
        let view = CovJAcctImportViewStub()
        host.navigation.pushViewController(UIViewController(), animated: false)
        host.navigation.pushViewController(view, animated: false)

        wireframe.showEthereumStep(from: view, with: stepData)
        XCTAssertEqual(host.navigation.viewControllers.count, 3, "Switching accounts has no Ethereum step")
        wireframe.proceed(from: nil, flow: .wallet(step: .substrate))
        XCTAssertEqual(host.navigation.viewControllers.count, 3)
        wireframe.proceed(from: view, flow: .wallet(step: .substrate))
        XCTAssertTrue(CovJWait.until { host.navigation.viewControllers.count == 1 })

        let sourceHost = try CovJHostedView(controller: CovJAcctImportViewStub())
        defer { sourceHost.close() }
        let sourceView = try XCTUnwrap(sourceHost.controller as? CovJAcctImportViewStub)
        wireframe.presentSourceTypeSelection(
            from: sourceView, availableSources: [.keystore], selectedSource: .keystore, delegate: nil, context: nil
        )
        XCTAssertTrue(sourceHost.navigation.presentedViewController is PickerController)

        let cryptoHost = try CovJHostedView(controller: CovJAcctImportViewStub())
        defer { cryptoHost.close() }
        let cryptoView = try XCTUnwrap(cryptoHost.controller as? CovJAcctImportViewStub)
        wireframe.presentCryptoTypeSelection(
            from: cryptoView, availableTypes: [.sr25519], selectedType: .sr25519, delegate: nil, context: nil
        )
        XCTAssertTrue(cryptoHost.navigation.presentedViewController is PickerController)
        wireframe.presentSourceTypeSelection(from: cryptoView, availableSources: [], selectedSource: .seed, delegate: nil, context: nil)
        wireframe.presentCryptoTypeSelection(from: sourceView, availableTypes: [], selectedType: .ecdsa, delegate: nil, context: nil)
    }
}
