import Foundation
import UIKit

struct BannerCellViewModel {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let image: UIImage
    let dismissable: Bool
    let fullsizeImage: Bool
    let bannerType: Banners
}

protocol BannerCellectionCellDelegate: AnyObject {
    func didActionButtonTapped(banner: Banners)
    func didCloseButtonTapped(banner: Banners)
}

final class BannerCollectionViewCell: UICollectionViewCell {
    weak var delegate: BannerCellectionCellDelegate?
    private var viewModel: BannerCellViewModel?

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h3Title
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p2Paragraph
        label.numberOfLines = 0
        return label
    }()

    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()

    let actionButton: TriangularedButton = {
        let button = UIFactory.default.createMainActionButton()
        button.triangularedView?.shadowOpacity = 0
        button.triangularedView?.fillColor = .clear
        button.triangularedView?.highlightedFillColor = .clear
        button.triangularedView?.strokeColor = R.color.colorWhite8()!
        button.triangularedView?.highlightedStrokeColor = R.color.colorWhite8()!
        button.triangularedView?.strokeWidth = 1

        button.imageWithTitleView?.titleColor = R.color.colorWhite()
        button.imageWithTitleView?.titleFont = .h6Title
        return button
    }()

    let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconClose(), for: .normal)
        button.backgroundColor = R.color.colorWhite8()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorWhite8()
        layer.cornerRadius = 15
        clipsToBounds = true
        setupLayout()
        bindActions()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        closeButton.rounded()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: BannerCellViewModel) {
        self.viewModel = viewModel

        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        actionButton.imageWithTitleView?.title = viewModel.buttonTitle
        imageView.image = viewModel.image
        closeButton.isHidden = !viewModel.dismissable

        updateImageConstraints(fullsizeImage: viewModel.fullsizeImage)
    }

    private func bindActions() {
        actionButton.addAction { [weak self] in
            guard let banner = self?.viewModel?.bannerType else {
                return
            }

            self?.delegate?.didActionButtonTapped(banner: banner)
        }

        closeButton.addAction { [weak self] in

            guard let banner = self?.viewModel?.bannerType else {
                return
            }

            self?.delegate?.didCloseButtonTapped(banner: banner)
        }
    }

    private func updateImageConstraints(fullsizeImage: Bool) {
        if fullsizeImage {
            imageView.snp.remakeConstraints { make in
                make.leading.trailing.bottom.equalToSuperview()
            }
        } else {
            imageView.snp.remakeConstraints { make in
                make.trailing.bottom.equalToSuperview()
            }
        }
    }

    private func setupLayout() {
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview()
        }

        addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(UIConstants.defaultOffset)
            make.size.equalTo(UIConstants.roundedCloseButtonSize)
        }

        addSubview(titleLabel)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalTo(closeButton.snp.leading).inset(16)
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalTo(closeButton.snp.leading).inset(16)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(subtitleLabel.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.height.equalTo(32)
            make.width.greaterThanOrEqualTo(102)
        }
    }
}
