import UIKit
import PayWingsOAuthSDK
import PayWingsOnboardingKYC
import SoraFoundation

final class KYCOnboardingInteractor {
    // MARK: - Private properties

    private weak var output: KYCOnboardingInteractorOutput?
    private let data = SCKYCUserDataModel()
    private let service: SCKYCService
    private let storage: SCStorage

    private let getUserDataCallback = GetUserDataCallback()
    private var result = VerificationResult()

    init(service: SCKYCService, storage: SCStorage) {
        self.service = service
        self.storage = storage

        getUserDataCallback.delegate = self
        result.delegate = self
    }

    private func requestUserData() {
        service.getUserData(callback: getUserDataCallback)
    }

    private func requestReferenceNumber() {
        Task {
            let result = await service.referenceNumber(
                phone: data.phoneNumber,
                email: data.email
            )

            switch result {
            case let .success(response):
                data.referenceNumber = response.referenceNumber
                data.referenceId = response.referenceID

                prepareConfig()
            case let .failure(error):
                DispatchQueue.main.async { [weak self] in
                    self?.output?.didReceive(error: error)
                }
            }
        }
    }

    private func prepareConfig() {
        let credentials = KycCredentials(
            username: "BD6C35D9-68C9-437D-AA22-FFDBDAAFD195",
            password: "39DED46E-2E8D-46BA-902F-CA14CA990DBF",
            endpointUrl: "https://kyc-test.soracard.com/mobile"
        )

        let language = "en"

        let settings = KycSettings(
            referenceID: data.referenceId,
            referenceNumber: data.referenceNumber,
            language: language
        )

        let userData = KycUserData(
            firstName: data.name,
            middleName: "",
            lastName: data.lastname,
            address1: "",
            address2: "",
            address3: "",
            zipCode: "",
            city: "",
            state: "",
            countryCode: "",
            email: data.email,
            mobileNumber: data.phoneNumber
        )

        let config = KycConfig(credentials: credentials, settings: settings, userData: userData)

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.output?.didReceive(config: config, result: strongSelf.result)
        }
    }

    func set(kycId: String?) {
        guard let kycId = kycId else {
            return
        }

        data.kycId = kycId
        storage.add(kycId: kycId)
    }
}

// MARK: - KYCOnboardingInteractorInput

extension KYCOnboardingInteractor: KYCOnboardingInteractorInput {
    func requestKYCSettings() {
        requestUserData()
    }

    func setup(with output: KYCOnboardingInteractorOutput) {
        self.output = output
    }
}

extension KYCOnboardingInteractor: GetUserDataCallbackDelegate {
    func onUserData(
        userId: String,
        firstName: String?,
        lastName: String?,
        email: String?,
        emailConfirmed _: Bool,
        phoneNumber: String?
    ) {
        data.userId = userId
        data.name = firstName ?? ""
        data.lastname = lastName ?? ""
        data.email = email ?? ""
        data.phoneNumber = phoneNumber ?? ""

        requestReferenceNumber()
    }

    func onError(error: PayWingsOAuthSDK.OAuthErrorCode, errorMessage: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.output?.didReceive(oAuthError: error, message: errorMessage)
        }
    }
}

extension KYCOnboardingInteractor: VerificationResultDelegate {
    func success(result: PayWingsOnboardingKYC.SuccessEvent) {
        set(kycId: result.KycID)

        DispatchQueue.main.async { [weak self] in
            self?.output?.didReceive(result: result)
        }
    }

    func error(result: PayWingsOnboardingKYC.ErrorEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.output?.didReceive(kycError: result)
        }
    }
}
