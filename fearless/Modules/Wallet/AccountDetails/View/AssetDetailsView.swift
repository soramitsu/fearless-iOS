import UIKit
import CommonWallet
import SoraUI

final class AssetDetailsView: BaseAccountDetailsContainingView {
    var contentInsets: UIEdgeInsets = .zero

    var preferredContentHeight: CGFloat { 227.0 }

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconView: UIImageView!
    @IBOutlet private var balanceLabel: UILabel!
    @IBOutlet private var priceLabel: UILabel!
    @IBOutlet private var priceChangeLabel: UILabel!
    @IBOutlet private var totalVolumeLabel: UILabel!
    @IBOutlet private var leftTitleLabel: UILabel!
    @IBOutlet private var leftDetailsLabel: UILabel!
    @IBOutlet private var rightTitleLabel: UILabel!
    @IBOutlet private var rightDetailsLabel: UILabel!
    @IBOutlet private var sendButton: RoundedButton!
    @IBOutlet private var receiveButton: RoundedButton!
    @IBOutlet private var buyButton: RoundedButton!

    private var actionsViewModel: WalletActionsViewModelProtocol?
    private var assetViewModel: AssetDetailsViewModel?

    func setContentInsets(_ contentInsets: UIEdgeInsets, animated _: Bool) {
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
        self.assetViewModel?.imageViewModel?.cancel()

        self.assetViewModel = assetViewModel

        titleLabel.text = assetViewModel.title

        iconView.image = nil

        assetViewModel.imageViewModel?.loadImage { [weak self] image, _ in
            self?.iconView.image = image
        }

        balanceLabel.text = assetViewModel.amount
        priceLabel.text = assetViewModel.price
        totalVolumeLabel.text = assetViewModel.totalVolume
        leftTitleLabel.text = assetViewModel.leftTitle
        leftDetailsLabel.text = assetViewModel.leftDetails
        rightTitleLabel.text = assetViewModel.rightTitle
        rightDetailsLabel.text = assetViewModel.rightDetails

        switch assetViewModel.priceChangeViewModel {
        case let .goingUp(displayString):
            priceChangeLabel.text = displayString
            priceChangeLabel.textColor = R.color.colorGreen()!
        case let .goingDown(displayString):
            priceChangeLabel.text = displayString
            priceChangeLabel.textColor = R.color.colorRed()!
        }
    }

    private func bind(actionsViewModel: ActionsViewModelProtocol) {
        if let viewModel = actionsViewModel as? WalletActionsViewModelProtocol {
            self.actionsViewModel = viewModel

            sendButton.imageWithTitleView?.title = viewModel.send.title
            sendButton.invalidateLayout()

            receiveButton.imageWithTitleView?.title = viewModel.receive.title
            receiveButton.invalidateLayout()

            buyButton.imageWithTitleView?.title = viewModel.buy.title
            buyButton.invalidateLayout()

            buyButton.isEnabled = (viewModel.buy.command != nil)
        }
    }

    @IBAction private func actionSend() {
        try? actionsViewModel?.send.command.execute()
    }

    @IBAction private func actionReceive() {
        try? actionsViewModel?.receive.command.execute()
    }

    @IBAction private func actionBuy() {
        try? actionsViewModel?.buy.command?.execute()
    }

    @IBAction private func actionFrozen() {
        try? assetViewModel?.infoDetailsCommand.execute()
    }
}
