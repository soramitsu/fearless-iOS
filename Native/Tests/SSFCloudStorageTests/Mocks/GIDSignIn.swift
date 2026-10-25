import SSFCloudStorage

@testable import GoogleSignIn

class GIDSignInMock: GIDSignIn {
    override var currentUser: GIDGoogleUser? {
        _currentUser
    }

    var _currentUser: GIDGoogleUser?

    // MARK: - signIn

    var signInCallsCount: Int = 0
    var signInCalled: Bool {
        signInCallsCount > 0
    }

    var signInReceivedArguments: (
        withPresenting: UIViewController,
        hint: String?,
        additionalScopes: [String]?,
        completion: ((GIDSignInResult?, Error?) -> Void)?
    )?
    var signInClosure: ((
        UIViewController,
        String?,
        [String]?,
        ((GIDSignInResult?, Error?) -> Void)?
    ) -> Void)?

    override func signIn(
        withPresenting presentingViewController: UIViewController,
        hint: String?,
        additionalScopes: [String]?,
        completion: ((GIDSignInResult?, Error?) -> Void)?
    ) {
        signInCallsCount += 1
        signInReceivedArguments = (
            withPresenting: presentingViewController,
            hint: hint,
            additionalScopes: additionalScopes,
            completion: completion
        )
        signInClosure?(presentingViewController, hint, additionalScopes, completion)
    }

    // MARK: - signOut

    var signOutCallsCount: Int = 0
    var signOutCalled: Bool {
        signOutCallsCount > 0
    }

    var signOutClosure: (() -> Void)?

    override func signOut() {
        signOutCallsCount += 1
        signOutClosure?()
    }

    // MARK: - disconnect

    var disconnectCompletionCallsCount: Int = 0
    var disconnectCompletionCalled: Bool {
        disconnectCompletionCallsCount > 0
    }

    var disconnectCompletionClosure: ((((Error?) -> Void)?) -> Void)?

    override func disconnect(completion: ((Error?) -> Void)? = nil) {
        disconnectCompletionCallsCount += 1
        disconnectCompletionClosure?(completion)
    }
}
