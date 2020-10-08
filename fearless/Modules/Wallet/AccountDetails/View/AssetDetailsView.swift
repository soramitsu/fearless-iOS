import UIKit
import CommonWallet

final class AssetDetailsView: BaseAccountDetailsContainingView {
    var contentInsets: UIEdgeInsets = .zero

    var preferredContentHeight: CGFloat { safeAreaInsets.top + 205.0 }

    @IBOutlet private var balanceLabel: UILabel!
    @IBOutlet private var priceLabel: UILabel!
    @IBOutlet private var priceChangeLabel: UILabel!
    @IBOutlet private var totalVolumeLabel: UILabel!
    @IBOutlet private var leftTitleLabel: UILabel!
    @IBOutlet private var leftDetailsLabel: UILabel!
    @IBOutlet private var rightTitleLabel: UILabel!
    @IBOutlet private var rightDetailsLabel: UILabel!
    @IBOutlet private var sendButton: TriangularedButton!
    @IBOutlet private var receiveButton: TriangularedButton!

    private var actionsViewModel: ActionsViewModelProtocol?
    private var assetViewModel: AssetDetailsViewModel?

    func setContentInsets(_ contentInsets: UIEdgeInsets, animated: Bool) {
        self.contentInsets = contentInsets
    }

    func bind(viewModels: [WalletViewModelProtocol]) {
        if let assetViewModel = viewModels
            .first(where: { $0 is AssetDetailsViewModel }) as? AssetDetailsViewModel {
            bind(assetViewModel: assetViewModel)
        }

        if let actionsViewModel = viewModels
            .first(where: { $0 is ActionsViewModelProtocol }) as? ActionsViewModelProtocol {
            bind(actionsViewModel: actionsViewModel)
        }

        setNeedsLayout()
    }

    private func bind(assetViewModel: AssetDetailsViewModel) {
        self.assetViewModel = assetViewModel

        balanceLabel.text = assetViewModel.amount
        priceLabel.text = assetViewModel.price
        priceChangeLabel.text = assetViewModel.priceChange
        totalVolumeLabel.text = assetViewModel.totalVolume
        leftTitleLabel.text = assetViewModel.leftTitle
        leftDetailsLabel.text = assetViewModel.leftDetails
        rightTitleLabel.text = assetViewModel.rightTitle
        rightDetailsLabel.text = assetViewModel.rightDetails
    }

    private func bind(actionsViewModel: ActionsViewModelProtocol) {
        self.actionsViewModel = actionsViewModel

        sendButton.imageWithTitleView?.title = actionsViewModel.send.title
        sendButton.invalidateLayout()

        receiveButton.imageWithTitleView?.title = actionsViewModel.receive.title
        receiveButton.invalidateLayout()
    }

    @IBAction private func actionSend() {
        try? actionsViewModel?.send.command.execute()
    }

    @IBAction private func actionReceive() {
        try? actionsViewModel?.receive.command.execute()
    }
}
