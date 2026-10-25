import Foundation
import UIKit

final class SheetAletViewController: UIViewController, ViewHolder {
    typealias RootViewType = SheetAlertViewLayout

    var scrollableContent: Bool {
        viewModel.scrollableContent
    }

    var presentationID: UUID {
        viewModel.presentationID
    }

    private var dismissalStarted = false
    private let viewModel: SheetAlertPresentableViewModel
    private let externalDismissalCompletion: (() -> Void)?

    init(viewModel: SheetAlertPresentableViewModel, externalDismissalCompletion: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.externalDismissalCompletion = externalDismissalCompletion
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SheetAlertViewLayout(viewModel: viewModel)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard let externalDismissalCompletion, !dismissalStarted,
              isBeingDismissed || presentingViewController == nil else { return }
        dismissalStarted = true
        externalDismissalCompletion()
    }

    private func setup() {
        rootView.dismissAndHandle = { [weak self] handler in self?.dismissSheet(handler: handler) }
        rootView.closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
    }

    @objc private func dismissSelf() {
        dismissSheet(handler: nil)
    }

    private func dismissSheet(handler: (() -> Void)?) {
        guard !dismissalStarted else { return }
        dismissalStarted = true
        let completion = viewModel.dismissCompletion
        dismiss(animated: true) {
            completion?()
            handler?()
        }
    }
}
