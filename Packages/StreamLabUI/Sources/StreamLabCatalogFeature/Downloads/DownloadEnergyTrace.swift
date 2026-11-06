import Foundation
import OSLog

/// Sparse phase markers only: no per-byte logging, title, URL or account data.
enum DownloadEnergyTrace {
    static let enabled = ProcessInfo.processInfo.arguments.contains("--trace-download-energy")
    private static let log = OSLog(subsystem: "com.example.streamlab.demo", category: .pointsOfInterest)
    static func event(_ name: StaticString) {
        guard enabled else { return }
        os_signpost(.event, log: log, name: name)
    }
}
