import UIKit

class ChainSelectionCollectionCell: UICollectionViewCell {
    let iconBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorWhite8()
        return view
    }()

    let chainIconImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        chainIconImageView.image = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        iconBackgroundView.rounded()
    }

    func bind(viewModel: ChainSelectionCollectionCellModel?) {
        viewModel?.imageViewModel?.loadImage(on: chainIconImageView, targetSize: CGSize(width: 24, height: 24), animated: true, cornerRadius: 0, completionHandler: { [weak self] result in
            switch result {
            case let .success(imageResult):
                if viewModel?.selected == true {
                    self?.chainIconImageView.image = imageResult.image.withRenderingMode(.alwaysTemplate).invertedImage()
                } else {
                    self?.chainIconImageView.image = imageResult.image.withRenderingMode(.alwaysOriginal)
                }
            case .failure:
                break
            }
        })

        if viewModel?.selected == true {
            iconBackgroundView.backgroundColor = R.color.colorWhite()
        } else {
            iconBackgroundView.backgroundColor = R.color.colorWhite8()
        }
    }

    // MARK: - Private

    private func addSubviews() {
        addSubview(iconBackgroundView)
        addSubview(chainIconImageView)
    }

    private func setupConstraints() {
        chainIconImageView.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        iconBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
