import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

/// The confirmation screen: presenter, view controller, layout, router, assembly, dependency container and the
/// interactor's fail-closed branches.
final class CovHCCConfirmPresenterTests: XCTestCase {
    private struct Context {
        let presenter: CrossChainConfirmationPresenter
        let view: CovHCCConfirmViewSpy
        let router: CovHCCConfirmRouterSpy
        let interactor: CovHCCConfirmInteractorSpy
        let authorizer: CovHCCConfirmSubmissionAuthorizer
        let feedback: CovHCCConfirmFeedback
        let data: CrossChainConfirmationData
    }

    private func makeContext(authorized: Bool = true, load: Bool = true) throws -> Context {
        let data = try CovHCCConfirmFixture.confirmationData()
        let view = CovHCCConfirmViewSpy()
        let router = CovHCCConfirmRouterSpy()
        let interactor = CovHCCConfirmInteractorSpy()
        let authorizer = CovHCCConfirmSubmissionAuthorizer(answer: authorized)
        let feedback = CovHCCConfirmFeedback()
        let presenter = CrossChainConfirmationPresenter(
            teleportData: data,
            viewModelFactory: CrossChainConfirmationViewModelFactory(),
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            submissionAuthorizer: authorizer,
            feedback: feedback
        )
        if load {
            presenter.didLoad(view: view)
        }
        return Context(
            presenter: presenter, view: view, router: router, interactor: interactor, authorizer: authorizer, feedback: feedback, data: data
        )
    }

    func testLoadBindsTheInteractorAndShowsTheConfirmationAndBackDismisses() throws {
        let context = try makeContext()
        XCTAssertTrue(context.interactor.output === context.presenter)
        XCTAssertEqual(context.view.viewModels.count, 1)
        XCTAssertEqual(context.view.viewModels.first?.sendTo, "recipient")
        XCTAssertEqual(context.view.viewModels.first?.destNetworkName, context.data.destChainModel.name)
        context.presenter.backButtonDidTapped()
        XCTAssertEqual(context.router.dismissed, 1)
        context.presenter.applyLocalization()
        XCTAssertEqual(context.view.viewModels.count, 1)
    }

    func testConfirmInABuildWithoutReviewedTrustExplainsTheRouteIsUnavailable() throws {
        let context = try makeContext()
        context.router.presentsErrors = false
        context.presenter.confirmButtonTapped()
        XCTAssertEqual(context.router.errors.count, 1)
        XCTAssertEqual(context.router.messages.map(\.title), ["Route unavailable"])
        XCTAssertEqual(context.router.messages.first?.message, ReviewedXcmExecutionAuthority.unavailableReason)
        XCTAssertEqual(context.authorizer.requests, 0, "Nothing is authorized for a route the build cannot send")
        XCTAssertTrue(context.interactor.submissions.isEmpty)

        context.router.presentsErrors = true
        context.presenter.confirmButtonTapped()
        XCTAssertEqual(context.router.errors.count, 2)
        XCTAssertEqual(context.router.messages.count, 1)

        let unloaded = try makeContext(load: false)
        unloaded.presenter.confirmButtonTapped()
        XCTAssertTrue(unloaded.router.errors.isEmpty)
    }

    func testAcceptedTransfersCompleteWithTheBridgeOrUnconfirmedExplanation() throws {
        let context = try makeContext()
        context.presenter.didTransfer(result: .success(.awaitingBridge(extrinsicHash: "0xhash")))
        context.presenter.didTransfer(result: .success(.unconfirmed(extrinsicHash: nil)))

        XCTAssertEqual(context.view.stops, 2)
        XCTAssertEqual(context.view.stages, [.accepted, .accepted])
        XCTAssertEqual(context.router.completions.map(\.title), ["Submitted, awaiting bridge", "Submitted, not yet confirmed"])
        XCTAssertEqual(context.router.completions.map(\.hash), ["0xhash", nil])
        let bridge = try XCTUnwrap(context.router.completions.first)
        XCTAssertTrue(bridge.description.contains(context.data.originChainAsset.chain.name))
        XCTAssertTrue(bridge.description.contains(context.data.destChainModel.name))
        XCTAssertEqual(bridge.chainAsset.chainAssetId, context.data.originChainAsset.chainAssetId)
        XCTAssertTrue(context.feedback.patterns.isEmpty)
    }

    func testFailuresNameTheReviewedReasonOrFallBackToTheGenericError() throws {
        let context = try makeContext()
        context.presenter.didTransfer(result: .failure(ReviewedCrossChainSubmissionError.destinationFeeChanged))
        context.presenter.didTransfer(result: .failure(ReviewedCrossChainDispatchError.submissionInDoubt))
        XCTAssertEqual(context.router.messages.map(\.title), ["Transfer not completed", "Transfer not completed"])
        XCTAssertEqual(
            context.router.messages.first?.message,
            ReviewedCrossChainSubmissionError.destinationFeeChanged.errorDescription
        )
        XCTAssertNotNil(context.router.messages.first?.closeAction)

        context.router.presentsErrors = false
        context.presenter.didTransfer(result: .failure(CovHCCConfirmError.stub))
        XCTAssertEqual(context.router.errors.count, 1)
        XCTAssertEqual(context.router.extrinsicFailures, 1)

        context.router.presentsErrors = true
        context.presenter.didTransfer(result: .failure(CovHCCConfirmError.stub))
        XCTAssertEqual(context.router.extrinsicFailures, 1)
        XCTAssertEqual(context.feedback.patterns, [.failure, .failure, .failure, .failure])
        XCTAssertEqual(context.view.breaks, 4)

        let unloaded = try makeContext(load: false)
        unloaded.presenter.didTransfer(result: .failure(CovHCCConfirmError.stub))
        XCTAssertTrue(unloaded.feedback.patterns.isEmpty)
        XCTAssertTrue(unloaded.router.errors.isEmpty)
    }

    func testAnUnresolvedEarlierAttemptAsksBeforeSendingAgain() throws {
        let context = try makeContext()
        context.presenter.didFindUnresolvedSubmission([])
        XCTAssertTrue(context.router.sheets.isEmpty)
        XCTAssertEqual(context.view.stops, 1)

        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let records = [
            CovHCCConfirmFixtureRecords.record(hash: "0xfirst", summary: "2 LLD Liberland → SORA", createdAt: created),
            CovHCCConfirmFixtureRecords.record(hash: "0xsecond", summary: "older", createdAt: created)
        ]
        context.presenter.didFindUnresolvedSubmission(records)
        let sheet = try XCTUnwrap(context.router.sheets.last)
        XCTAssertEqual(sheet.title, "This transfer may already be on its way")
        let message = try XCTUnwrap(sheet.message)
        XCTAssertTrue(message.contains("2 LLD Liberland → SORA"))
        XCTAssertTrue(message.contains("0xfirst\n0xsecond"))
        XCTAssertEqual(sheet.actions.count, 1)

        // Closing the sheet without choosing to send again does nothing.
        sheet.dismissCompletion?()
        XCTAssertEqual(context.authorizer.requests, 0)

        context.presenter.didFindUnresolvedSubmission([CovHCCConfirmFixtureRecords.record(hash: nil, summary: "s", createdAt: created)])
        let again = try XCTUnwrap(context.router.sheets.last)
        XCTAssertTrue(again.message?.contains("No transaction hash was returned.") == true)
        again.actions.first?.handler?()
        again.dismissCompletion?()
        XCTAssertEqual(context.authorizer.requests, 1)
        XCTAssertEqual(context.interactor.submissions, [true])
        XCTAssertEqual(context.view.starts, 1)
        XCTAssertEqual(context.view.stages, [.ready])
    }

    func testSendingAgainNeedsAFreshAuthorization() throws {
        let context = try makeContext(authorized: false)
        context.presenter.didFindUnresolvedSubmission([CovHCCConfirmFixtureRecords.record(hash: "0x1", summary: "s", createdAt: Date())])
        let sheet = try XCTUnwrap(context.router.sheets.last)
        sheet.actions.first?.handler?()
        sheet.dismissCompletion?()
        XCTAssertEqual(context.authorizer.requests, 1)
        XCTAssertTrue(context.interactor.submissions.isEmpty)
        XCTAssertEqual(context.view.starts, 0)
    }
}

final class CovHCCConfirmViewTests: XCTestCase {
    private func viewModel(note: String? = nil, total: String? = nil) -> CrossChainConfirmationViewModel {
        CrossChainConfirmationViewModel(
            sendTo: "cnVk…recipient",
            doubleImageViewViewModel: PolkaswapDoubleSymbolViewModel(
                leftViewModel: nil, rightViewModel: nil, leftShadowColor: nil, rightShadowColor: nil
            ),
            originalNetworkName: "Liberland",
            destNetworkName: "SORA Mainnet",
            amount: "2 LLD",
            originalChainFee: BalanceViewModel(amount: "0.01 LLD", price: "$0.01"),
            destChainFee: BalanceViewModel(amount: "0 LLD", price: nil),
            originPreservationNote: note,
            totalBurned: total
        )
    }

    func testControllerForwardsLoadBackAndConfirmAndBindsEveryRow() throws {
        let output = CovHCCConfirmViewOutputSpy()
        let controller = CrossChainConfirmationViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()

        XCTAssertEqual(output.loads, 1)
        let root = controller.rootView
        let languages = LocalizationManager.shared.selectedLocale.rLanguages
        XCTAssertEqual(root.confirmButton.imageWithTitleView?.title, R.string.localizable.commonConfirm(preferredLanguages: languages))
        XCTAssertEqual(root.navigationBar.titleLabel.text, R.string.localizable.commonPreview(preferredLanguages: languages))
        XCTAssertEqual(root.originalNetworkView.titleLabel.text, R.string.localizable.xcmOriginNetworkTitle(preferredLanguages: languages))

        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        root.confirmButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.backs, 1)
        XCTAssertEqual(output.confirms, 1)

        controller.didReceive(viewModel: viewModel())
        XCTAssertEqual(root.amountLabel.text, "2 LLD")
        XCTAssertEqual(root.sendToView.valueTop.text, "cnVk…recipient")
        XCTAssertEqual(root.originalNetworkView.valueTop.text, "Liberland")
        XCTAssertEqual(root.destNetworkView.valueTop.text, "SORA Mainnet")
        XCTAssertTrue(root.originPreservationView.isHidden)
        XCTAssertNil(root.originPreservationView.titleLabel.text)

        controller.didReceive(viewModel: viewModel(note: "Origin preserved via reserve transfer"))
        XCTAssertFalse(root.originPreservationView.isHidden)
        XCTAssertEqual(root.originPreservationView.titleLabel.text, "XCM Origin Preservation")
        XCTAssertEqual(root.originPreservationView.valueTop.text, "Origin preserved via reserve transfer")

        controller.didReceive(viewModel: viewModel(total: "2.5 LLD"))
        XCTAssertEqual(root.originPreservationView.titleLabel.text, "Total burned on Liberland")
        XCTAssertEqual(root.originPreservationView.valueTop.text, "2.5 LLD")
    }

    func testLoadingAndTheSealFollowTheTransfer() {
        let controller = CrossChainConfirmationViewController(output: CovHCCConfirmViewOutputSpy(), localizationManager: nil)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

        controller.didStartLoading()
        XCTAssertFalse(controller.rootView.confirmButton.isUserInteractionEnabled)

        controller.didReachTransferStage(.ready)
        let overlay = FWTransferSeal.overlay(in: controller.view)
        XCTAssertNotNil(overlay)
        XCTAssertNotNil(FWTransferSeal.sealView(in: controller.view))
        controller.didBreakTransfer()
        XCTAssertEqual(overlay?.isBreaking, true)

        controller.didStopLoading()
        XCTAssertTrue(controller.rootView.confirmButton.isUserInteractionEnabled)
    }

    func testRouterDismissesTheFlowThenShowsTheResultFromThePresentingScreen() throws {
        let presenting = CovHCCConfirmPresentingSpy()
        let screen = CovHCCConfirmScreen()
        let navigation = CovHCCConfirmNavigationSpy(rootViewController: screen)
        navigation.presenting = presenting
        let chainAsset = try CovHCCConfirmFixture.origin(CovHCCConfirmFixture.route("LLD"))

        CrossChainConfirmationRouter().complete(on: screen, hash: "0xhash", title: "Done", description: "Sent", chainAsset: chainAsset)

        XCTAssertEqual(navigation.dismissals, 1)
        let presented = try XCTUnwrap(presenting.presented.first)
        XCTAssertEqual(presented.modalPresentationStyle, .custom)
        XCTAssertNotNil(presented.transitioningDelegate)

        CrossChainConfirmationRouter().complete(on: nil, hash: nil, title: "", description: "", chainAsset: chainAsset)
        XCTAssertEqual(presenting.presented.count, 1)
    }

    func testAssemblyBuildsTheReviewedScreen() throws {
        let data = try CovHCCConfirmFixture.confirmationData()
        let module = try XCTUnwrap(CrossChainConfirmationAssembly.configureModule(with: data))
        let controller = try XCTUnwrap(module.view as? CrossChainConfirmationViewController)
        XCTAssertTrue(module.input is CrossChainConfirmationPresenter)
        controller.loadViewIfNeeded()
        XCTAssertEqual(controller.rootView.amountLabel.text, "2 LLD")
        XCTAssertEqual(controller.rootView.sendToView.valueTop.text, "recipient")
    }
}

final class CovHCCConfirmInteractorAndDepsTests: XCTestCase {
    private func makeInteractor(
        journal: ReviewedCrossChainSubmissionJournaling,
        mutationsEnabled: @escaping () -> Bool
    ) throws -> (CrossChainConfirmationInteractor, CovHCCConfirmInteractorOutputSpy, CovHCCConfirmExtrinsicExecutorSpy) {
        let executor = CovHCCConfirmExtrinsicExecutorSpy()
        let interactor = CrossChainConfirmationInteractor(
            teleportData: try CovHCCConfirmFixture.confirmationData(),
            submissionAuthorizer: CovHCCConfirmFixedAuthorizer(
                submission: ReviewedCrossChainAuthorizedSubmission(
                    builder: { $0 },
                    executor: executor,
                    finalGuard: {},
                    transferKey: "transfer-\(UUID().uuidString)",
                    intentSha256: String(repeating: "c", count: 64)
                )
            ),
            journal: journal,
            operationQueue: OperationQueue(),
            logger: Logger.shared,
            mutationsEnabled: mutationsEnabled
        )
        let output = CovHCCConfirmInteractorOutputSpy()
        interactor.setup(with: output)
        return (interactor, output, executor)
    }

    func testAPausedSwitchAfterAuthorizationAndAnUnwritableJournalSendNothing() throws {
        let paused = try makeInteractor(journal: CovHCCConfirmJournal(), mutationsEnabled: { false })
        paused.0.submit(confirmingRepeat: false)
        CovHCCConfirmFixture.spin { paused.1.results.count == 1 }
        XCTAssertEqual(paused.1.errors.first as? ReviewedCrossChainSubmissionError, .actionsPaused)
        XCTAssertEqual(paused.2.submits, 0)

        let journal = CovHCCConfirmJournal()
        journal.saveError = CovHCCConfirmError.stub
        let unwritable = try makeInteractor(journal: journal, mutationsEnabled: { true })
        unwritable.0.submit(confirmingRepeat: false)
        CovHCCConfirmFixture.spin { unwritable.1.results.count == 1 }
        XCTAssertEqual(unwritable.1.errors.first as? ReviewedCrossChainDispatchError, .journalUnavailable)
        XCTAssertEqual(unwritable.2.submits, 0)

        let unreadable = CovHCCConfirmJournal()
        unreadable.unresolvedError = CovHCCConfirmError.stub
        let fenced = try makeInteractor(journal: unreadable, mutationsEnabled: { true })
        fenced.0.submit(confirmingRepeat: false)
        CovHCCConfirmFixture.spin { fenced.1.results.count == 1 }
        XCTAssertEqual(fenced.1.errors.first as? ReviewedCrossChainDispatchError, .journalUnreadable)
    }

    func testDefaultSwitchIsReadFromTheFeaturePolicy() throws {
        let interactor = CrossChainConfirmationInteractor(
            teleportData: try CovHCCConfirmFixture.confirmationData(),
            submissionAuthorizer: CovHCCConfirmFixedAuthorizer(
                submission: ReviewedCrossChainAuthorizedSubmission(
                    builder: { $0 }, executor: CovHCCConfirmExtrinsicExecutorSpy(), finalGuard: {},
                    transferKey: "transfer-\(UUID().uuidString)", intentSha256: String(repeating: "d", count: 64)
                )
            ),
            journal: CovHCCConfirmJournal(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
        let output = CovHCCConfirmInteractorOutputSpy()
        interactor.setup(with: output)
        interactor.submit(confirmingRepeat: false)
        CovHCCConfirmFixture.spin { output.results.count == 1 }
        XCTAssertEqual(output.results.count, 1)
        if !MultiChainFeaturePolicy.current.crossChainMutationsEnabled {
            XCTAssertEqual(output.errors.first as? ReviewedCrossChainSubmissionError, .actionsPaused)
        }
    }

    func testJournalSetAsideWithoutATimeStartsItsWindowNow() throws {
        let suite = "CovHCCConfirmJournal.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data([1, 2, 3]), forKey: "cross_chain.submission_journal.v1.unreadable")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        defaults.set(now.addingTimeInterval(3600), forKey: "cross_chain.submission_journal.v1.unreadable_since")
        let journal = ReviewedCrossChainSubmissionJournal(userDefaults: defaults, logger: nil)

        XCTAssertThrowsError(try journal.unresolved(for: "transfer", now: now)) { error in
            XCTAssertEqual(error as? ReviewedCrossChainDispatchError, .journalUnreadable)
        }
        XCTAssertEqual(defaults.object(forKey: "cross_chain.submission_journal.v1.unreadable_since") as? Date, now)
        XCTAssertEqual(try journal.unresolved(for: "transfer", now: now.addingTimeInterval(ReviewedCrossChainSubmissionJournal.confirmationWindow)), [])
    }

    func testDependencyContainerNeedsTheOriginAccountAndReusesOneGraphPerRoute() throws {
        let liberland = try CovHCCConfirmFixture.liberland()
        let sora = try CovHCCConfirmFixture.sora()
        let origin = try CovHCCConfirmFixture.origin(CovHCCConfirmFixture.route("LLD"))
        let emptyWallet = MetaAccountModel(
            metaId: "cov-h-empty",
            name: "Empty",
            substrateAccountId: nil,
            substrateCryptoType: 0,
            substratePublicKey: nil,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            assetKeysOrder: nil,
            canExportEthereumMnemonic: false,
            unusedChainIds: nil,
            selectedCurrency: .defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: true,
            favouriteChainIds: []
        )
        XCTAssertNil(emptyWallet.fetch(for: liberland.accountRequest()))
        XCTAssertThrowsError(
            try CrossChainDepsContainer(wallet: emptyWallet).prepareDepsFor(
                originalChainAsset: origin, originalRuntimeMetadataItem: nil, destChainModel: sora
            )
        ) { error in
            guard case CrossChainDepsContainer.DepsError.missingChainResponse = error else {
                return XCTFail("Expected the missing account to be named, got \(error)")
            }
        }

        let container = CrossChainDepsContainer(wallet: AccountGenerator.generateMetaAccount())
        let withoutDestination = try container.prepareDepsFor(originalChainAsset: origin, originalRuntimeMetadataItem: nil, destChainModel: nil)
        XCTAssertNil(withoutDestination.destinationExistentialDepositService)
        XCTAssertNil(withoutDestination.destinationStorageRequestPerformer)

        let first = try container.prepareDepsFor(originalChainAsset: origin, originalRuntimeMetadataItem: nil, destChainModel: sora)
        let cached = try container.prepareDepsFor(originalChainAsset: origin, originalRuntimeMetadataItem: nil, destChainModel: sora)
        let firstService = try XCTUnwrap(first.destinationExistentialDepositService as AnyObject?)
        let cachedService = try XCTUnwrap(cached.destinationExistentialDepositService as AnyObject?)
        XCTAssertTrue(firstService === cachedService, "One form reuses the graph it built for the same route")

        let metadata = fearless.RuntimeMetadataItem(chain: liberland.chainId, version: 34, txVersion: 2, metadata: Data())
        let rebuilt = try container.prepareDepsFor(originalChainAsset: origin, originalRuntimeMetadataItem: metadata, destChainModel: sora)
        let rebuiltService = try XCTUnwrap(rebuilt.destinationExistentialDepositService as AnyObject?)
        XCTAssertFalse(firstService === rebuiltService, "A new runtime version builds a new graph")
    }
}
