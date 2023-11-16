import UIKit

final class NFTContentControl: UIView {
    enum State {
        case collection
        case table
    }

    enum LayoutConstants {
        static let buttonSize: CGFloat = 30
    }

    let collectionButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconCollection(), for: .normal)
        button.isUserInteractionEnabled = false
        return button
    }()

    let tableButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconTable(), for: .normal)
        button.alpha = 0.3
        return button
    }()

    let filterButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconFilter(), for: .normal)
        return button
    }()

    let separator: UIView = UIFactory.default.createSeparatorView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(collectionButton)
        addSubview(tableButton)
        addSubview(filterButton)
        addSubview(separator)

        setupConstraints()
    }

    private func setupConstraints() {
        collectionButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.size.equalTo(LayoutConstants.buttonSize)
        }

        tableButton.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(collectionButton.snp.trailing).offset(UIConstants.defaultOffset)
            make.size.equalTo(LayoutConstants.buttonSize)
        }

        separator.snp.makeConstraints { make in
            make.leading.equalTo(tableButton.snp.trailing).offset(UIConstants.defaultOffset)
            make.trailing.equalTo(filterButton.snp.leading).offset(-UIConstants.defaultOffset)
            make.height.equalTo(LayoutConstants.buttonSize)
            make.width.equalTo(1)
        }

        filterButton.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.size.equalTo(LayoutConstants.buttonSize)
        }
    }

    func apply(state: State) {
        switch state {
        case .collection:
            collectionButton.alpha = 1
            collectionButton.isUserInteractionEnabled = false
            tableButton.alpha = 0.3
            tableButton.isUserInteractionEnabled = true
        case .table:
            collectionButton.alpha = 0.3
            collectionButton.isUserInteractionEnabled = true
            tableButton.alpha = 1
            tableButton.isUserInteractionEnabled = false
        }
    }
}
