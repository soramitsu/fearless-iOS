import UIKit
import SoraFoundation

final class NftSendConfirmViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = NftSendConfirmViewLayout

    // MARK: Private properties

    private let output: NftSendConfirmViewOutput

    // MARK: - Constructor

    init(
        output: NftSendConfirmViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = NftSendConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didBackButtonTapped()
        }
        rootView.confirmButton.addAction { [weak self] in
            self?.output.didConfirmButtonTapped()
        }
    }

    func didStartLoading() {
        rootView.confirmButton.set(loading: true)
    }

    func didStopLoading() {
        rootView.confirmButton.set(loading: false)
    }

    // MARK: - Private methods
}

// MARK: - NftSendConfirmViewInput

extension NftSendConfirmViewController: NftSendConfirmViewInput {
    func didReceive(nftViewModel: NftSendConfirmViewModel) {
        rootView.bind(nftViewModel: nftViewModel)
    }

    func didReceive(feeViewModel: BalanceViewModelProtocol?) {
        rootView.bind(feeViewModel: feeViewModel)
    }

    func didReceive(senderViewModel: AccountViewModel?) {
        rootView.bind(senderViewModel: senderViewModel)
    }

    func didReceive(receiverViewModel: AccountViewModel?) {
        rootView.bind(receiverViewModel: receiverViewModel)
    }
}

// MARK: - Localizable

extension NftSendConfirmViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
