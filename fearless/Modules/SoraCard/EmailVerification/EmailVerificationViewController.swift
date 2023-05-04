import UIKit
import SoraFoundation

final class EmailVerificationViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = EmailVerificationViewLayout

    // MARK: Private properties

    private let output: EmailVerificationViewOutput
    private var timer: Timer?
    private var remainingTime = 60

    // MARK: - Constructor

    init(
        output: EmailVerificationViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = EmailVerificationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        applyLocalization()
        rootView.set(state: .enter)
        configure()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.sendButton.addTarget(self, action: #selector(sendButtonClicked), for: .touchUpInside)
        rootView.changeEmailButton.addTarget(self, action: #selector(changeEmailButtonClicked), for: .touchUpInside)
        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
        rootView.closeButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
    }

    @objc private func updateTimer() {
        if remainingTime != 0 {
            remainingTime -= 1
            rootView.set(
                timerState: .inProgress(
                    timeRemaining: TimeFormatter.minutesSecondsString(from: remainingTime)
                )
            )
        } else {
            rootView.set(timerState: .finished)
            if let timer = self.timer {
                timer.invalidate()
                self.timer = nil
            }
        }
    }

    @objc private func sendButtonClicked() {
        guard let email = rootView.emailInputField.textField.text, !email.isEmpty else { return }
        rootView.set(state: .verify(email: email))
        output.didTapSendButton(with: email)
        resetTimer()
    }

    @objc private func changeEmailButtonClicked() {
        rootView.set(state: .enter)
        rootView.set(timerState: .finished)
        if let timer = self.timer {
            timer.invalidate()
            self.timer = nil
        }
    }

    private func resetTimer() {
        remainingTime = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateTimer),
            userInfo: nil,
            repeats: true
        )
        timer?.fire()
    }

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }

    @objc private func closeButtonClicked() {
        output.didTapCloseButton()
    }
}

// MARK: - EmailVerificationViewInput

extension EmailVerificationViewController: EmailVerificationViewInput {
    func didReceiveVerifyEmail(_ email: String) {
        rootView.set(state: .verify(email: email))
    }
}

// MARK: - Localizable

extension EmailVerificationViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
