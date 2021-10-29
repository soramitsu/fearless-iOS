import Foundation
import RobinHood
import IrohaCrypto

final class MoonbeamService {
    let signingWrapper: SigningWrapperProtocol
    let address: AccountAddress
    let chain: Chain
    let operationManager: OperationManagerProtocol
    let requestBuilder: HTTPRequestBuilderProtocol
    let dataOperationFactory: DataOperationFactoryProtocol

    init(
        address: AccountAddress,
        chain: Chain,
        signingWrapper: SigningWrapperProtocol,
        operationManager: OperationManagerProtocol,
        requestBuilder: HTTPRequestBuilderProtocol,
        dataOperationFactory: DataOperationFactoryProtocol
    ) {
        self.address = address
        self.chain = chain
        self.signingWrapper = signingWrapper
        self.operationManager = operationManager
        self.requestBuilder = requestBuilder
        self.dataOperationFactory = dataOperationFactory
    }

    func createFetchAgreementContentOperation(with url: URL) -> BaseOperation<Data> {
        dataOperationFactory.fetchData(from: url)
    }

    func createHealthOperation() -> BaseOperation<Void> {
        let requestFactory = BlockNetworkRequestFactory {
            let request = try self.requestBuilder.buildRequest(with: MoonbeamHealthRequest())
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Void> {}

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createCheckRemarkOperation(
        dependingOn infoOperation: BaseOperation<MoonbeamCheckRemarkInfo>
    ) -> BaseOperation<MoonbeamCheckRemarkData> {
        let requestFactory = BlockNetworkRequestFactory {
            let info = try infoOperation.extractNoCancellableResultData()
            let request = try self.requestBuilder.buildRequest(with: MoonbeamCheckRemarkRequest(address: info.address))

            return request
        }

        let resultFactory = AnyNetworkResultFactory<MoonbeamCheckRemarkData> { data in
            let resultData = try MoonbeamJSONDecoder().decode(
                MoonbeamCheckRemarkData.self,
                from: data
            )

            return resultData
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createAgreeRemarkOperation(
        dependingOn infoOperation: BaseOperation<MoonbeamAgreeRemarkInfo>
    ) -> BaseOperation<MoonbeamAgreeRemarkData> {
        let requestFactory = BlockNetworkRequestFactory {
            let info = try infoOperation.extractNoCancellableResultData()
            let request = try self.requestBuilder.buildRequest(with: MoonbeamAgreeRemarkRequest(
                info: infoOperation.extractNoCancellableResultData()
            ))

            return request
        }

        let resultFactory = AnyNetworkResultFactory<MoonbeamAgreeRemarkData> { data in
            let resultData = try MoonbeamJSONDecoder().decode(
                MoonbeamAgreeRemarkData.self,
                from: data
            )

            return resultData
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createVerifyRemarkOpeartion(
        dependingOn infoOperation: BaseOperation<MoonbeamVerifyRemarkInfo>
    ) -> BaseOperation<MoonbeamVerifyRemarkData> {
        let requestFactory = BlockNetworkRequestFactory {
            let info = try infoOperation.extractNoCancellableResultData()
            let request = try self.requestBuilder.buildRequest(with: MoonbeamVerifyRemarkRequest(
                address: info.address,
                info: info
            ))

            return request
        }

        let resultFactory = AnyNetworkResultFactory<MoonbeamVerifyRemarkData> { data in
            let resultData = try MoonbeamJSONDecoder().decode(
                MoonbeamVerifyRemarkData.self,
                from: data
            )

            return resultData
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createMakeSignatureOperation(
        dependingOn infoOperation: BaseOperation<MoonbeamMakeSignatureInfo>
    ) -> BaseOperation<MoonbeamMakeSignatureData> {
        let requestFactory = BlockNetworkRequestFactory {
            let info = try infoOperation.extractNoCancellableResultData()
            let request = try self.requestBuilder.buildRequest(with: MoonbeamMakeSignatureRequest(
                address: info.address,
                info: info
            ))

            return request
        }

        let resultFactory = AnyNetworkResultFactory<MoonbeamMakeSignatureData> { data in
            let resultData = try MoonbeamJSONDecoder().decode(
                MoonbeamMakeSignatureData.self,
                from: data
            )

            return resultData
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createGuidInfoOperation(
        dependingOn infoOperation: BaseOperation<MoonbeamGuidinfoInfo>
    ) -> BaseOperation<MoonbeamMakeSignatureData> {
        let requestFactory = BlockNetworkRequestFactory {
            let info = try infoOperation.extractNoCancellableResultData()
            let request = try self.requestBuilder.buildRequest(with: MoonbeamGuidInfoRequest(
                address: info.address,
                guid: info.guid
            ))

            return request
        }

        let resultFactory = AnyNetworkResultFactory<MoonbeamMakeSignatureData> { data in
            let resultData = try MoonbeamJSONDecoder().decode(
                MoonbeamMakeSignatureData.self,
                from: data
            )

            return resultData
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func makeAccountAddress() throws -> String {
        let addressFactory = SS58AddressFactory()
        let accountId = try addressFactory.accountId(from: address)
        let addressType = chain.addressType
        let finalAddress = try addressFactory.addressFromAccountId(data: accountId, type: addressType)

        return finalAddress
    }
}

extension MoonbeamService: MoonbeamServiceProtocol {
    var termsURL: URL {
        // TODO: attestation url from utils
        URL(string: "https://github.com/moonbeam-foundation/crowdloan-self-attestation/tree/main/moonbeam")!
    }

    func fetchAgreementContent(
        from url: URL,
        with closure: @escaping (Result<Data, Error>
        ) -> Void
    ) {
        let fetchOperation = createFetchAgreementContentOperation(with: url)
        fetchOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let resultData: Data = try fetchOperation.extractNoCancellableResultData()
                    closure(.success(resultData))
                } catch {
                    if let responseError = error as? NetworkResponseError, responseError == .unexpectedStatusCode {
                        closure(.failure(CrowdloanAgreementServiceError.moonbeamForbidden))
                    } else {
                        closure(.failure(CommonError.network))
                    }
                }
            }
        }
        operationManager.enqueue(operations: [fetchOperation], in: .transient)
    }

    func agreeRemark(
        agreementData: Data,
        with closure: @escaping (Result<MoonbeamAgreeRemarkData, Error>
        ) -> Void
    ) {
        let infoOperation = ClosureOperation<MoonbeamAgreeRemarkInfo> {
            guard let sha256 = agreementData.sha256().toHex().data(using: .utf8) else {
                throw CommonError.internal
            }

            let signedSHA256 = try self.signingWrapper.sign(sha256).rawData().toHex(includePrefix: true)

            return MoonbeamAgreeRemarkInfo(
                address: try self.makeAccountAddress(),
                signedMessage: signedSHA256
            )
        }

        let agreeRemarkOperation = createAgreeRemarkOperation(dependingOn: infoOperation)

        agreeRemarkOperation.addDependency(infoOperation)

        agreeRemarkOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let resultData: MoonbeamAgreeRemarkData = try agreeRemarkOperation.extractNoCancellableResultData()
                    closure(.success(resultData))
                } catch {
                    if let responseError = error as? NetworkResponseError, responseError == .unexpectedStatusCode {
                        closure(.failure(CrowdloanAgreementServiceError.moonbeamForbidden))
                    } else {
                        closure(.failure(CommonError.network))
                    }
                }
            }
        }

        operationManager.enqueue(operations: [infoOperation, agreeRemarkOperation], in: .transient)
    }

    func verifyRemark(
        extrinsicHash: String,
        blockHash: String,
        with closure: @escaping (Result<MoonbeamVerifyRemarkData, Error>
        ) -> Void
    ) {
        let verifyRemarkInfoOperation = ClosureOperation<MoonbeamVerifyRemarkInfo> {
            MoonbeamVerifyRemarkInfo(
                address: try self.makeAccountAddress(),
                extrinsicHash: extrinsicHash,
                blockHash: blockHash
            )
        }

        let verifyRemarkOperation = createVerifyRemarkOpeartion(dependingOn: verifyRemarkInfoOperation)

        verifyRemarkOperation.addDependency(verifyRemarkInfoOperation)

        verifyRemarkOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let resultData: MoonbeamVerifyRemarkData = try verifyRemarkOperation.extractNoCancellableResultData()

                    closure(.success(resultData))
                } catch {
                    if let responseError = error as? NetworkResponseError, responseError == .unexpectedStatusCode {
                        closure(.failure(CrowdloanAgreementServiceError.moonbeamForbidden))
                    } else {
                        closure(.failure(CommonError.network))
                    }
                }
            }
        }

        operationManager.enqueue(
            operations: [verifyRemarkInfoOperation, verifyRemarkOperation],
            in: .transient
        )
    }

    func verifyRemarkAndContribute(
        contribution: String,
        extrinsicHash: String,
        blockHash: String, with closure: @escaping (Result<MoonbeamMakeSignatureData, Error>
        ) -> Void
    ) {
        let verifyRemarkInfoOperation = ClosureOperation<MoonbeamVerifyRemarkInfo> {
            MoonbeamVerifyRemarkInfo(
                address: try self.makeAccountAddress(),
                extrinsicHash: extrinsicHash,
                blockHash: blockHash
            )
        }

        let verifyRemarkOperation = createVerifyRemarkOpeartion(dependingOn: verifyRemarkInfoOperation)

        verifyRemarkOperation.addDependency(verifyRemarkInfoOperation)

        verifyRemarkOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let resultData: MoonbeamVerifyRemarkData = try verifyRemarkOperation.extractNoCancellableResultData()

                    if !resultData.verified {
                        closure(.failure(CrowdloanBonusServiceError.veficationFailed))
                        return
                    }
                } catch {
                    if let responseError = error as? NetworkResponseError, responseError == .unexpectedStatusCode {
                        closure(.failure(CrowdloanAgreementServiceError.moonbeamForbidden))
                    } else {
                        closure(.failure(CommonError.network))
                    }
                }
            }
        }

        let makeSignatureInfoOperation = ClosureOperation<MoonbeamMakeSignatureInfo> {
            MoonbeamMakeSignatureInfo(
                address: try self.makeAccountAddress(),
                previousTotalContribution: "",
                contribution: contribution,
                guid: UUID().uuidString
            )
        }

        let makeSignatureOperation = createMakeSignatureOperation(dependingOn: makeSignatureInfoOperation)

        makeSignatureOperation.addDependency(makeSignatureInfoOperation)

        makeSignatureOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let resultData: MoonbeamMakeSignatureData = try makeSignatureOperation.extractNoCancellableResultData()
                    closure(.success(resultData))
                } catch {
                    if let responseError = error as? NetworkResponseError, responseError == .unexpectedStatusCode {
                        closure(.failure(CrowdloanAgreementServiceError.moonbeamForbidden))
                    } else {
                        closure(.failure(CommonError.network))
                    }
                }
            }
        }

        operationManager.enqueue(
            operations: [verifyRemarkInfoOperation, verifyRemarkOperation, makeSignatureInfoOperation, makeSignatureOperation],
            in: .transient
        )
    }

    func confirmContribution(
        previousTotalContribution _: String,
        contribution _: String,
        with _: @escaping (Result<MoonbeamMakeSignatureData, Error>
        ) -> Void
    ) {}

    func checkRemark(
        with closure: @escaping (Result<Bool, Error>) -> Void
    ) {
        let infoOperation = ClosureOperation<MoonbeamCheckRemarkInfo> {
            MoonbeamCheckRemarkInfo(
                address: try self.makeAccountAddress()
            )
        }

        let checkRemarkOperation = createCheckRemarkOperation(dependingOn: infoOperation)

        checkRemarkOperation.addDependency(infoOperation)

        checkRemarkOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let resultData: MoonbeamCheckRemarkData = try checkRemarkOperation.extractNoCancellableResultData()
                    closure(.success(resultData.verified))
                } catch {
                    if let responseError = error as? NetworkResponseError, responseError == .unexpectedStatusCode {
                        closure(.failure(CrowdloanAgreementServiceError.moonbeamForbidden))
                    } else {
                        closure(.failure(CommonError.network))
                    }
                }
            }
        }

        operationManager.enqueue(operations: [infoOperation, checkRemarkOperation], in: .transient)
    }
}
