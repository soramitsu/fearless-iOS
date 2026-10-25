// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFQRService

public class QRServiceMock: QRService {
public init() {}

    //MARK: - extractQrCode

    public var extractQrCodeFromThrowableError: Error?
    public var extractQrCodeFromCallsCount = 0
    public var extractQrCodeFromCalled: Bool {
        return extractQrCodeFromCallsCount > 0
    }
    public var extractQrCodeFromReceivedImage: UIImage?
    public var extractQrCodeFromReceivedInvocations: [UIImage] = []
    public var extractQrCodeFromReturnValue: QRMatcherType!
    public var extractQrCodeFromClosure: ((UIImage) throws -> QRMatcherType)?

    public func extractQrCode(from image: UIImage) throws -> QRMatcherType {
        if let error = extractQrCodeFromThrowableError {
            throw error
        }
        extractQrCodeFromCallsCount += 1
        extractQrCodeFromReceivedImage = image
        extractQrCodeFromReceivedInvocations.append(image)
        return try extractQrCodeFromClosure.map({ try $0(image) }) ?? extractQrCodeFromReturnValue
    }

    //MARK: - generate

    public var generateWithQrSizeThrowableError: Error?
    public var generateWithQrSizeCallsCount = 0
    public var generateWithQrSizeCalled: Bool {
        return generateWithQrSizeCallsCount > 0
    }
    public var generateWithQrSizeReceivedArguments: (qrType: QRType, qrSize: CGSize)?
    public var generateWithQrSizeReceivedInvocations: [(qrType: QRType, qrSize: CGSize)] = []
    public var generateWithQrSizeReturnValue: UIImage!
    public var generateWithQrSizeClosure: ((QRType, CGSize) throws -> UIImage)?

    public func generate(with qrType: QRType, qrSize: CGSize) throws -> UIImage {
        if let error = generateWithQrSizeThrowableError {
            throw error
        }
        generateWithQrSizeCallsCount += 1
        generateWithQrSizeReceivedArguments = (qrType: qrType, qrSize: qrSize)
        generateWithQrSizeReceivedInvocations.append((qrType: qrType, qrSize: qrSize))
        return try generateWithQrSizeClosure.map({ try $0(qrType, qrSize) }) ?? generateWithQrSizeReturnValue
    }

}
