# Export-compliance technical inventory

The embedded Azahar core contains Crypto++ and LibreSSL-derived cryptographic functionality. Standard cryptography is used for compatibility with console data, including AES-based console-content decryption and other emulated services. The app does not provide a VPN, secure messenger, password manager or general-purpose encryption product. It is incorrect to answer that there is no cryptographic code, or that it relies exclusively on Apple's OS encryption.

The existing `ITSAppUsesNonExemptEncryption = false` assertion was removed for this submission preparation. The source inventory alone does not certify whether every compiled cryptographic path qualifies for an export exemption. App Store Connect may therefore show **Missing Compliance** after upload. Complete its questions before assigning the build for testing; choose the applicable standard-encryption/decryption or ancillary-use exemption only if it accurately covers this build. Supply documentation if Apple requests it. No proprietary cryptographic algorithm was added by the Swift frontend.

After the appropriate classification is confirmed, record it here and set `ITSAppUsesNonExemptEncryption` accurately for a later build to avoid repeating the questionnaire. Do not add `ITSEncryptionExportComplianceCode` unless Apple provides an actual approval code.

Apple references: [export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/), [encryption documentation](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation/), [beta export information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-export-compliance-information-for-beta-builds/).

Build 5 also uses Apple CryptoKit SHA-256 to check local save-state integrity. This is a standard hash, not an additional proprietary encryption algorithm; the embedded third-party cryptography described above remains present.
