import Foundation
import UIKit

final class SheetAletViewController: UIViewController, ViewHolder {
    typealias RootViewType = SheetAlertViewLayout

    private let viewModel: SheetAlertPresentableViewModel

    init(viewModel: SheetAlertPresentableViewModel) {
        self.viewModel = viewModel
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

    private func setup() {
        rootView.closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}
