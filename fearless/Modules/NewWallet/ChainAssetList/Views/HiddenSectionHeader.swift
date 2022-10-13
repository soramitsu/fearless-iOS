import UIKit

struct HiddenSectionViewModel {
    let title: String
    let expandTapHandler: () -> Void
}

final class HiddenSectionHeader: UITableViewHeaderFooterView {
    enum LayoutConstants {
        static let imageSize: CGFloat = 32
    }

    let expandButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        return button
    }()

    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconExpandableInverted()
        imageView.backgroundColor = R.color.colorWhite8()
        imageView.layer.cornerRadius = LayoutConstants.imageSize / 2
        imageView.contentMode = .center
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        return label
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = UIConstants.bigOffset
        return stackView
    }()

    private var expandTapHandler: (() -> Void)?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        expandButton.addTarget(self, action: #selector(expandButtonTapped), for: .touchUpInside)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: HiddenSectionViewModel) {
        titleLabel.text = viewModel.title
        expandTapHandler = viewModel.expandTapHandler
    }

    @objc
    private func expandButtonTapped() {
        expandTapHandler?()
    }

    private func setupLayout() {
        imageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.imageSize)
        }

        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(titleLabel)
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        addSubview(expandButton)
        expandButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
