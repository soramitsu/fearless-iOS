import Foundation

enum PasskeyBackupVerifiedPRFKeyProviderError: Error, Equatable {
    case bindingMismatch
}

/// One local unwrap for a verified native PRF result and an independently supplied owner context.
/// This is only the key-access boundary; the caller must authenticate the owner head and generation.
actor PasskeyBackupVerifiedPRFKeyProvider: RecoverablePasskeyBackupKeyProvider,
    CustomStringConvertible, CustomReflectable {
        private var verifiedPRF: PasskeyBackupVerifiedLocalPRF?
        private let record: PasskeyBackupCredentialKeyWrapperRecord
        private let expectedContext: PasskeyBackupKeyWrapperContext
        private let keyWrapper: PasskeyBackupCredentialKeyWrapper

        init(
            verifiedPRF: PasskeyBackupVerifiedLocalPRF,
            record: PasskeyBackupCredentialKeyWrapperRecord,
            expectedContext: PasskeyBackupKeyWrapperContext,
            keyWrapper: PasskeyBackupCredentialKeyWrapper = PasskeyBackupCredentialKeyWrapper()
        ) throws {
            let credentialID = Self.base64URL(verifiedPRF.credentialID)
            guard record.context == expectedContext,
                  expectedContext.credentialId == credentialID,
                  expectedContext.envelopeMetadata.storageKey == verifiedPRF.storageKey,
                  record.prfSalt == verifiedPRF.prfSalt else {
                throw PasskeyBackupVerifiedPRFKeyProviderError.bindingMismatch
            }
            self.verifiedPRF = verifiedPRF
            self.record = record
            self.expectedContext = expectedContext
            self.keyWrapper = keyWrapper
        }

        func backupKey(for metadata: PasskeyBackupEnvelopeMetadata) async throws -> Data {
            guard let verifiedPRF else { throw PasskeyBackupPRFError.invalidState }
            // Burn the capability before any check or cryptographic operation, including cancellation.
            self.verifiedPRF = nil
            return try verifiedPRF.withOutput { output in
                try Task.checkCancellation()
                guard metadata == expectedContext.envelopeMetadata else {
                    throw PasskeyBackupVerifiedPRFKeyProviderError.bindingMismatch
                }
                return try keyWrapper.unwrap(record: record, prfOutput: output, expectedContext: expectedContext)
            }
        }

        nonisolated var description: String {
            "PasskeyBackupVerifiedPRFKeyProvider(<redacted>)"
        }

        nonisolated var customMirror: Mirror {
            Mirror(self, children: [:])
        }

        private static func base64URL(_ bytes: Data) -> String {
            bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        }
    }
