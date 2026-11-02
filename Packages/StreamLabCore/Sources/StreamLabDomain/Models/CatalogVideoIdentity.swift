import CryptoKit
import Foundation

public enum CatalogVideoIdentity {
    public static let prefix = "catalog-video-v2-"

    public static func progressID(for url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        // Firebase identifies an immutable uploaded object by bucket and path.
        if url.host?.lowercased() == "firebasestorage.googleapis.com" {
            let items = components?.queryItems?.filter { $0.name != "token" && $0.name != "alt" }
            components?.queryItems = items?.isEmpty == false ? items : nil
        }
        let identity = components?.string ?? url.absoluteString
        return prefix + SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
