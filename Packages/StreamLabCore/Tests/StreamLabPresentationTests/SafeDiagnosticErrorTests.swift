import Foundation
import Testing
import StreamLabPresentation

@Suite("C2 diagnostic error privacy")
struct SafeDiagnosticErrorTests {
    @Test func knownDomainPreservesCodeButDropsSensitiveMetadata() {
        let secret = "secret-token-member-title-position-1234"
        let error = NSError(domain: NSURLErrorDomain, code: -999, userInfo: [
            NSLocalizedDescriptionKey: secret,
            NSURLErrorFailingURLErrorKey: URL(string: "https://example.test/play?token=\(secret)")!,
            NSUnderlyingErrorKey: NSError(domain: secret, code: 42),
            NSFilePathErrorKey: "/private/container/\(secret)"
        ])
        #expect(SafeDiagnosticError.summary(error) == "domain=NSURLErrorDomain code=-999")
    }
    @Test func unknownDomainCannotInjectSecretsOrNewLogLines() {
        let error = NSError(domain: "https://example.test?token=secret\nmember=123", code: 7)
        #expect(SafeDiagnosticError.summary(error) == "domain=other code=7")
    }
    @Test func approvedSystemDomainsRemainRecognizable() {
        for domain in [NSCocoaErrorDomain, NSPOSIXErrorDomain, "AVFoundationErrorDomain", "UIWindowSceneErrorDomain"] {
            #expect(SafeDiagnosticError.summary(NSError(domain: domain, code: 101)) == "domain=\(domain) code=101")
        }
    }
}
