import UIKit

final class StartupRecoveryViewLayout: UIView {
    let stack = UIStackView()
    private var boundActions: [StartupRecoveryViewModel.Action] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack() ?? .systemBackground
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(model: StartupRecoveryViewModel, action: @escaping (StartupRecoveryViewModel.Action) -> Void) {
        if boundActions == model.actions, stack.arrangedSubviews.count == model.actions.count + 2 {
            let labels = stack.arrangedSubviews.compactMap { $0 as? UILabel }
            labels[0].text = model.title
            labels[1].text = model.message
            let buttons = stack.arrangedSubviews.compactMap { $0 as? UIButton }
            for (button, item) in zip(buttons, model.actions) {
                button.configuration?.title = item.localizedTitle(locale: model.locale)
            }
            return
        }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        boundActions = model.actions
        for (text, style) in [(model.title, UIFont.TextStyle.title1), (model.message, .body)] {
            let label = UILabel()
            label.text = text
            label.textColor = R.color.colorWhite() ?? .label
            label.numberOfLines = 0
            label.font = .preferredFont(forTextStyle: style)
            label.adjustsFontForContentSizeCategory = true
            stack.addArrangedSubview(label)
        }
        for item in model.actions {
            var configuration = UIButton.Configuration.plain()
            configuration.title = item.localizedTitle(locale: model.locale)
            configuration.titleAlignment = .center
            configuration.titleLineBreakMode = .byWordWrapping
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
            let button = UIButton(configuration: configuration)
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
            button.addAction(UIAction { _ in action(item) }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
    }
}
