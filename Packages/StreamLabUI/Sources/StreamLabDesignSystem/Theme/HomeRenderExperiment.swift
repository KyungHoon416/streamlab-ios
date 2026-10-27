import Foundation

/// Process-lifetime selection: no persisted setting, no mid-scroll switch.
/// Normal launches retain the current production rendering (both changes).
public enum HomeRenderExperiment: String, CaseIterable, Sendable {
    case control = "C"
    case poster = "P"
    case split = "V"
    case combined = "PV"

    public static let current = resolve(arguments: ProcessInfo.processInfo.arguments)

    public static func resolve(arguments: [String]) -> Self {
        let prefix = "--home-render-experiment="
        guard let argument = arguments.last(where: { $0.hasPrefix(prefix) }),
              let value = Self(rawValue: String(argument.dropFirst(prefix.count))) else { return .combined }
        return value
    }

    public var singleLayerPoster: Bool { self == .poster || self == .combined }
    public var splitHome: Bool { self == .split || self == .combined }
    public var description: String {
        "home_render_experiment=\(rawValue) poster=\(singleLayerPoster ? "layer" : "swiftui") home=\(splitHome ? "split" : "inline")"
    }
}
