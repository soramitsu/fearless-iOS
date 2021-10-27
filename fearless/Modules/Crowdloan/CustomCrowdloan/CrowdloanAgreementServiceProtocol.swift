import Foundation

protocol CrowdloanAgreementServiceProtocol {
    var termsURL: URL { get }

    func checkRemark(
        with closure: @escaping (Result<Bool, Error>
        ) -> Void)

    func agreeRemark(
        signedMessage: Data,
        with closure: @escaping (Result<MoonbeamAgreeRemarkData, Error>
        ) -> Void
    )

    func verifyRemarkAndContribute(
        contribution: String,
        extrinsicHash: String,
        blockHash: String,
        with closure: @escaping (Result<MoonbeamMakeSignatureData, Error>
        ) -> Void
    )

    func confirmContribution(
        previousTotalContribution: String,
        contribution: String,
        with closure: @escaping (Result<MoonbeamMakeSignatureData, Error>
        ) -> Void
    )
}
