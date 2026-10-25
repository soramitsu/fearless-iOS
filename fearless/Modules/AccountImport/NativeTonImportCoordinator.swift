import Foundation
import SoraFoundation
import UIKit

/// Owns address discovery and the choice before any wallet or Keychain write is issued.
final class NativeTonImportCoordinator {
    typealias Preparation = (String, @escaping (Result<[LegacyTonImportCandidate], Error>) -> Void) -> Operation

    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private let prepare: Preparation
    private var requestId: UUID?
    private var operation: Operation?
    private weak var sheet: UIViewController?
    private var confirmed = false
    private var backgroundObserver: NSObjectProtocol?

    var isPending: Bool {
        requestId != nil
    }

    init(prepare: @escaping Preparation = NativeTonImportCoordinator.prepareCandidates) {
        self.prepare = prepare
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.cancel() }
    }

    deinit {
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
        operation?.cancel()
    }

    static func prepareCandidates(
        _ phrase: String, completion: @escaping (Result<[LegacyTonImportCandidate], Error>) -> Void
    ) -> Operation {
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation] in
            guard operation?.isCancelled == false else { return }
            let result = Result { try LegacyTonMnemonic.importCandidates(phrase) }
            guard operation?.isCancelled == false else { return }
            completion(result)
        }
        queue.addOperation(operation)
        return operation
    }

    private func clearPending() {
        requestId = nil
        confirmed = false
        operation?.cancel()
        operation = nil
        sheet = nil
    }

    func cancel() {
        let ownedSheet = sheet
        clearPending()
        ownedSheet?.dismiss(animated: false)
    }

    func start(
        phrase: String, locale: Locale, from owner: UIViewController,
        isCurrent: @escaping () -> Bool,
        completion: @escaping (Result<LegacyTonMnemonic, Error>) -> Void
    ) {
        guard !isPending, isAvailable(owner), owner.presentedViewController == nil else { return }
        let id = UUID()
        requestId = id
        operation = prepare(phrase) { [weak self, weak owner] result in
            DispatchQueue.main.async {
                guard let self, self.requestId == id else { return }
                self.operation = nil
                guard let owner, self.isAvailable(owner), owner.presentedViewController == nil,
                      isCurrent() else {
                    self.cancel()
                    return
                }
                switch result {
                case let .failure(error):
                    self.requestId = nil
                    completion(.failure(error))
                case let .success(candidates):
                    guard let candidate = candidates.first else {
                        self.requestId = nil
                        completion(.failure(AccountCreateError.invalidMnemonicFormat))
                        return
                    }
                    if candidates.count == 1 {
                        self.requestId = nil
                        completion(.success(candidate.mnemonic))
                    } else {
                        self.present(
                            candidates,
                            id: id,
                            locale: locale,
                            from: owner,
                            isCurrent: isCurrent,
                            completion: completion
                        )
                    }
                }
            }
        }
    }

    private func isAvailable(_ owner: UIViewController) -> Bool {
        owner.viewIfLoaded?.window != nil && !owner.isBeingDismissed && !owner.isMovingFromParent &&
            !((owner.navigationController?.isBeingDismissed) ?? false) &&
            (owner.navigationController == nil || owner.navigationController?.topViewController === owner) &&
            UIApplication.shared.applicationState != .background
    }

    // swiftlint:disable:next function_parameter_count
    private func present(
        _ candidates: [LegacyTonImportCandidate], id: UUID, locale: Locale, from owner: UIViewController,
        isCurrent: @escaping () -> Bool, completion: @escaping (Result<LegacyTonMnemonic, Error>) -> Void
    ) {
        let actions = candidates.map { candidate in
            let label = candidate.form == .asTyped
                ? R.string.localizable.importTonAs_typed(preferredLanguages: locale.rLanguages)
                : R.string.localizable.importTonNormalized(preferredLanguages: locale.rLanguages)
            let button = UIFactory.default.createMainActionButton()
            button.accessibilityIdentifier = candidate.form == .asTyped
                ? "ton-import-as-typed" : "ton-import-normalized"
            return SheetAlertPresentableAction(
                title: label + "\n" + candidate.address, button: button, handlerAfterDismissal: true,
                beforeDismissal: { [weak self] in
                    guard self?.requestId == id, self?.sheet?.isBeingDismissed == false else { return }
                    self?.confirmed = true
                }, handler: { [weak self, weak owner] in
                    guard let self, self.requestId == id, self.confirmed else { return }
                    self.requestId = nil
                    self.confirmed = false
                    self.sheet = nil
                    guard let owner, self.isAvailable(owner), owner.presentedViewController == nil,
                          isCurrent() else { return }
                    completion(.success(candidate.mnemonic))
                }
            )
        }
        let model = SheetAlertPresentableViewModel(
            title: R.string.localizable.importTonChoose_address(preferredLanguages: locale.rLanguages),
            message: R.string.localizable.importTonSpacing_warning(preferredLanguages: locale.rLanguages),
            actions: actions,
            closeAction: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages),
            dismissCompletion: { [weak self] in
                guard let self, self.requestId == id, !self.confirmed else { return }
                self.cancel()
            }, scrollableContent: true
        )
        let sheet = SheetAletViewController(viewModel: model, externalDismissalCompletion: { [weak self] in
            guard self?.requestId == id else { return }
            self?.cancel()
        })
        sheet.modalPresentationStyle = .custom
        sheet.modalTransitioningFactory = ModalSheetBlurPresentationFactory(
            configuration: .fearlessBlur, shouldDissmissWhenTapOnBlurArea: false
        )
        self.sheet = sheet
        sheet.loadViewIfNeeded()
        sheet.rootView.closeButton.addAction { [weak self] in
            // Fence queued candidate taps immediately, before the dismissal animation ends.
            guard self?.requestId == id else { return }
            self?.clearPending()
        }
        owner.view.endEditing(true)
        owner.present(sheet, animated: true)
    }
}

protocol NativeTonImportLifecycleOwning: AnyObject {
    func cancelPendingNativeTonImport()
}
