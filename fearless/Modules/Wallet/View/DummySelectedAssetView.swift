import Foundation
import CommonWallet
import SoraUI

final class DummySelectedAssetView: UIControl {
    weak var delegate: SelectedAssetViewDelegate?
    var activated: Bool = false
    var borderType: BorderType = .none

    init() {
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DummySelectedAssetView: SelectedAssetViewProtocol {
    func bind(viewModel _: AssetSelectionViewModelProtocol) {}
}

extension DummySelectedAssetView: WalletFormBordering {}
