import Foundation
import UIKit
import SoraUI

final class SelectedNetworkButton: UIControl {
    private enum Constants {
        static let insets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 8)
        static let imageVerticalPosition: CGFloat = 3
        static let imageWidth: CGFloat = 12
        static let imageHeight: CGFloat = 6
    }

    private let iconImageView = UIImageView()

    private let title: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    private let dropTraingleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.dropTriangle()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        clipsToBounds = true
    }

    func set(text: String, image: ImageViewModelProtocol?) {
        title.text = text
        if let imageViewModel = image {
            imageViewModel.loadImage(on: iconImageView, targetSize: CGSize(width: 16, height: 16), animated: false)
        } else {
            iconImageView.image = nil
        }
    }

    func applySelectableStyle(_ selectable: Bool) {
        dropTraingleImageView.isHidden = !selectable
    }

    private func setup() {
        backgroundColor = R.color.colorWhite8()
        let container = UIFactory.default.createHorizontalStackView(spacing: 4)
        container.alignment = .center
        addSubview(container)
        container.addArrangedSubview(iconImageView)
        container.addArrangedSubview(title)
        container.addArrangedSubview(dropTraingleImageView)

        [container, iconImageView, title, dropTraingleImageView].forEach {
            $0.isUserInteractionEnabled = false
        }

        container.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Constants.insets)
        }

        iconImageView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }

        dropTraingleImageView.snp.makeConstraints { make in
            make.size.equalTo(10)
        }
    }
}
