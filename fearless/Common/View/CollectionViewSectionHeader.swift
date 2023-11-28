import UIKit

class CollectionViewSectionHeader: UICollectionReusableView {
    var label: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .h5Title
        label.sizeToFit()
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.hugeOffset)
            make.trailing.equalToSuperview().inset(UIConstants.hugeOffset)
            make.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
