import SnapKit
import SCard

final class SCardBannerCell: UICollectionViewCell {
    private let cardView = SCCardView(frame: .zero)
    private var viewModel: SCCardItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupLayout() {
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
    
    private func bind(viewModel: SCCardItem) {
        self.viewModel = viewModel
        self.cardView.onClose = viewModel.onClose
        self.cardView.onCard = viewModel.onCard
        
        viewModel.onUpdate = { [weak self] status, availableBalance in
            self?.cardView.update(status: status, availableBalance: availableBalance, needUpdate: viewModel.needUpdate)
        }
        
        self.cardView.update(status: viewModel.userStatus, availableBalance: viewModel.availableBalance, needUpdate: viewModel.needUpdate)
    }
}

extension SCardBannerCell: CollectionViewCell {
    func bind(viewModel: CollectionViewModel) {
        guard let viewModel = viewModel as? SCCardItem else { return }
        bind(viewModel: viewModel)
    }
}
