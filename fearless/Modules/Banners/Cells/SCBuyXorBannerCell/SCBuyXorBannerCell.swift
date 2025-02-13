import SnapKit
import SCard

final class SCBuyXorBannerCell: UICollectionViewCell {
    private let buyXor = UIView()
    private var viewModel: SCBuyXorItem?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayout() {
        contentView.addSubview(buyXor)
        buyXor.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
    
    private func bind(viewModel: SCBuyXorItem) {
        self.viewModel = viewModel
    }
}

extension SCBuyXorBannerCell: CollectionViewCell {
    func bind(viewModel: CollectionViewModel) {
        guard let viewModel = viewModel as? SCBuyXorItem else { return }
        bind(viewModel: viewModel)
    }
}
