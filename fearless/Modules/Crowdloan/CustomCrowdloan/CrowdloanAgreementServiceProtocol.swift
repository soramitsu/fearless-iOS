import Foundation

protocol CrowdloanAgreementServiceProtocol {
    var termsURL: URL { get }

    func fetchAgreementContent(
        from url: URL,
        with closure: @escaping (Result<Data, Error>
        ) -> Void
    )

    func checkRemark(
        with closure: @escaping (Result<Bool, Error>
        ) -> Void)

    func agreeRemark(
        agreementData: Data,
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
