import Foundation

/// Public diagnostics never include arbitrary descriptions, domains, URLs or userInfo.
public enum SafeDiagnosticError {
    public static func summary(_ error: any Error) -> String {
        let value = error as NSError
        let domain: String
        switch value.domain {
        case NSURLErrorDomain: domain = "NSURLErrorDomain"
        case NSCocoaErrorDomain: domain = "NSCocoaErrorDomain"
        case NSPOSIXErrorDomain: domain = "NSPOSIXErrorDomain"
        case "AVFoundationErrorDomain": domain = "AVFoundationErrorDomain"
        case "UIWindowSceneErrorDomain": domain = "UIWindowSceneErrorDomain"
        default: domain = "other"
        }
        return "domain=\(domain) code=\(value.code)"
    }
}
