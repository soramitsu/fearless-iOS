import UIKit
import RobinHood
import BigInt
import IrohaCrypto
import FearlessUtils

final class AcalaBonusService: CrowdloanBonusServiceProtocol {
    static let defaultReferralCode = "0x9642d0db9f3b301b44df74b63b0b930011e3f52154c5ca24b4dc67b3c7322f15"

    #if F_RELEASE
        static let baseURL = URL(string: "https://crowdloan.aca-dev.network")!
    #else
        static let baseURL = URL(string: "https://crowdloan.aca-dev.network")!
    #endif

    var bonusRate: Decimal { 0.05 }
    var termsURL: URL { URL(string: "https://acala.network/acala/terms")! }
    private(set) var referralCode: String?

    let signingWrapper: SigningWrapperProtocol
    let address: AccountAddress
    let chain: Chain
    let operationManager: OperationManagerProtocol
    let requestBuilder: HTTPRequestBuilderProtocol

    init(
        address: AccountAddress,
        chain: Chain,
        signingWrapper: SigningWrapperProtocol,
        operationManager: OperationManagerProtocol,
        requestBuilder: HTTPRequestBuilderProtocol
    ) {
        self.address = address
        self.chain = chain
        self.signingWrapper = signingWrapper
        self.operationManager = operationManager
        self.requestBuilder = requestBuilder
    }

    func createStatementFetchOperation() -> BaseOperation<String> {
        let requestFactory = BlockNetworkRequestFactory {
            let request = try self.requestBuilder.buildRequest(with: AcalaStatementRequest())
            return request
        }

        let resultFactory = AnyNetworkResultFactory<String> { data in
            let resultData = try JSONDecoder().decode(
                AcalaStatementData.self,
                from: data
            )

            return resultData.statement
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createTransferOperation(
        dependingOn infoOperation: BaseOperation<AcalaTransferInfo>
    ) -> BaseOperation<AcalaTransferData> {
        let requestFactory = BlockNetworkRequestFactory {
            let info = try infoOperation.extractNoCancellableResultData()
            let request = try self.requestBuilder.buildRequest(with: AcalaTransferRequest(transferInfo: info))
            return request
        }

        let resultFactory = AnyNetworkResultFactory<AcalaTransferData> { data in
            let resultData = try JSONDecoder().decode(
                AcalaTransferData.self,
                from: data
            )

            return resultData
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createContributeOperation(
        dependingOn infoOperation: BaseOperation<AcalaContributeInfo>
    ) -> BaseOperation<AcalaContributeData> {
        let requestFactory = BlockNetworkRequestFactory {
            let info = try infoOperation.extractNoCancellableResultData()
            let request = try self.requestBuilder.buildRequest(with: AcalaContributeRequest(contributeInfo: info))
            return request
        }

        let resultFactory = AnyNetworkResultFactory<AcalaContributeData> { data in
            let resultData = try JSONDecoder().decode(
                AcalaContributeData.self,
                from: data
            )

            return resultData
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}

extension AcalaBonusService: AcalaSpecificBonusServiceProtocol {
    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void) {
        let requestFactory = BlockNetworkRequestFactory {
            var request = try self.requestBuilder.buildRequest(with: AcalaReferralRequest(referralCode: referralCode))
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { data in
            let resultData = try JSONDecoder().decode(
                AcalaReferralData.self,
                from: data
            )

            return resultData.result
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try operation.extractNoCancellableResultData()

                    if result {
                        self?.referralCode = referralCode
                        closure(.success(()))
                    } else {
                        // TODO: proper error handling
                        closure(.failure(CrowdloanBonusServiceError.invalidReferral))
                    }

                } catch {
                    if let responseError = error as? NetworkResponseError, case .invalidParameters = responseError {
                        // TODO: proper error handling
                        closure(.failure(CrowdloanBonusServiceError.invalidReferral))
                    } else {
                        // TODO: proper error handling
                        closure(.failure(CrowdloanBonusServiceError.internalError))
                    }
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func applyOffchainBonusForTransfer(
        amount: BigUInt,
        email: String?,
        receiveEmails: Bool?,
        with closure: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let referralCode = referralCode else {
            DispatchQueue.main.async {
                closure(.failure(CrowdloanBonusServiceError.veficationFailed))
            }

            return
        }

        let infoOperation = ClosureOperation<AcalaTransferInfo> {
            let addressFactory = SS58AddressFactory()
            let accountId = try addressFactory.accountId(from: self.address)
            let addressType = self.chain == .rococo ? SNAddressType.genericSubstrate : self.chain.addressType
            let finalAddress = try addressFactory.addressFromAccountId(data: accountId, type: addressType)

            return AcalaTransferInfo(
                address: finalAddress,
                amount: String(amount),
                referral: referralCode,
                email: email,
                receiveEmail: receiveEmails
            )
        }

        let verifyOperation = createTransferOperation(dependingOn: infoOperation)
        verifyOperation.addDependency(infoOperation)

        verifyOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    _ = try verifyOperation.extractNoCancellableResultData()
                    closure(.success(()))
                } catch {
                    if let responseError = error as? NetworkResponseError, case .invalidParameters = responseError {
                        // TODO: proper error handling
                        closure(.failure(CrowdloanBonusServiceError.veficationFailed))
                    } else {
                        closure(.failure(error))
                    }
                }
            }
        }

        operationManager.enqueue(operations: [infoOperation, verifyOperation], in: .transient)
    }

    func applyOffchainBonusForContribution(amount: BigUInt, with closure: @escaping (Result<Void, Error>) -> Void) {
        applyOffchainBonusForContribution(amount: amount, email: nil, receiveEmails: nil, with: closure)
    }

    func applyOffchainBonusForContribution(
        amount: BigUInt,
        email: String?,
        receiveEmails: Bool?,
        with closure: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let referralCode = referralCode else {
            DispatchQueue.main.async {
                closure(.failure(CrowdloanBonusServiceError.veficationFailed))
            }

            return
        }

        let statementOperation = createStatementFetchOperation()

        let infoOperation = ClosureOperation<AcalaContributeInfo> {
            guard
                let statement = try statementOperation.extractNoCancellableResultData().data(using: .utf8) else {
                // TODO: proper error handling
                throw CrowdloanBonusServiceError.veficationFailed
            }

            let signedData = try self.signingWrapper.sign(statement)

            let addressFactory = SS58AddressFactory()
            let accountId = try addressFactory.accountId(from: self.address)
            let addressType = self.chain == .rococo ? SNAddressType.genericSubstrate : self.chain.addressType
            let finalAddress = try addressFactory.addressFromAccountId(data: accountId, type: addressType)

            return AcalaContributeInfo(
                address: finalAddress,
                amount: String(amount),
                signature: signedData.rawData().toHex(includePrefix: true),
                referral: referralCode,
                email: email,
                receiveEmail: receiveEmails
            )
        }

        infoOperation.addDependency(statementOperation)

        let verifyOperation = createContributeOperation(dependingOn: infoOperation)
        verifyOperation.addDependency(infoOperation)

        verifyOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    _ = try verifyOperation.extractNoCancellableResultData()
                    closure(.success(()))
                } catch {
                    if let responseError = error as? NetworkResponseError, case .invalidParameters = responseError {
                        // TODO: proper error handling
                        closure(.failure(CrowdloanBonusServiceError.veficationFailed))
                    } else {
                        closure(.failure(error))
                    }
                }
            }
        }

        operationManager.enqueue(operations: [statementOperation, infoOperation, verifyOperation], in: .transient)
    }

    func applyOnchainBonusForContribution(
        amount _: BigUInt,
        using builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        builder
    }
}
