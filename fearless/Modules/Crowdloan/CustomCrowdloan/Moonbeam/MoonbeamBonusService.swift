import Foundation
import RobinHood

final class MoonbeamBonusService {
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
                address: info.address,
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
}
