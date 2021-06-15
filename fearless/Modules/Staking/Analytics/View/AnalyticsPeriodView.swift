import UIKit

protocol AnalyticsPeriodViewDelegate: AnyObject {
    func didSelect(period: AnalyticsPeriod)
}

final class AnalyticsPeriodView: UIView {
    weak var delegate: AnalyticsPeriodViewDelegate?

    private var periods: [AnalyticsPeriod] = []

    let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.estimatedItemSize = .init(width: 83, height: 24)
        layout.minimumInteritemSpacing = 8
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        return collectionView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        setupCollection()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupCollection() {
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            AnalyticsPeriodCell.self,
            forCellWithReuseIdentifier: AnalyticsPeriodCell.reuseIdentifier
        )
    }

    func configure(periods: [AnalyticsPeriod]) {
        self.periods = periods
        collectionView.reloadData()
    }
}

extension AnalyticsPeriodView: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        periods.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: AnalyticsPeriodCell.reuseIdentifier,
            for: indexPath
        ) as? AnalyticsPeriodCell else {
            return UICollectionViewCell()
        }
        cell.titleLabel.text = periods[indexPath.row].title(for: .current).uppercased()
        return cell
    }
}

extension AnalyticsPeriodView: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let period = periods[indexPath.row]
        delegate?.didSelect(period: period)
    }
}

private class AnalyticsPeriodCell: UICollectionViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.top.bottom.equalToSuperview().inset(5.5)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
