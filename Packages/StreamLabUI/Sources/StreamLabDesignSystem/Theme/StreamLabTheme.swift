import SwiftUI
import StreamLabDomain

public enum StreamLabTheme {
    private static let bundledArtworkURLs: [URL?] = (0..<6).map {
        Bundle.module.url(forResource: "poster-\($0)", withExtension: "png")
    }
    public static func bundledArtworkURL(seed: Int) -> URL? {
        bundledArtworkURLs[abs(seed % 6)]
    }

    public static let accent = Color(red: 0.9, green: 0.04, blue: 0.1)
    public static let background = Color(red: 0.035, green: 0.035, blue: 0.045)
    public static let surface = Color(red: 0.1, green: 0.1, blue: 0.12)
}

public struct StreamLabButtonStyle: ButtonStyle {
    @Environment(\.streamLabContrast) private var contrast
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background((contrast == .increased ? Color(red: 0.65, green: 0.02, blue: 0.06) : StreamLabTheme.accent).opacity(configuration.isPressed && contrast != .increased ? 0.65 : 1), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: contrast == .increased ? (configuration.isPressed ? 3 : 1) : 0))
    }
}

@MainActor public struct CatalogArtwork: View {
    let title: CatalogTitle
    @State private var loaded: DecodedArtwork?
    @State private var loadedURL: URL?
    @State private var generation = UUID()
    public init(title: CatalogTitle) { self.title = title }
    private var url: URL? {
        title.artworkURL ?? StreamLabTheme.bundledArtworkURL(seed: title.visualSeed)
    }
    public var body: some View {
        let hue = Double(title.visualSeed % 360) / 360
        // Render either decoded pixels or the placeholder, never both. One
        // rounded clip bounds scaled-to-fill pixels without a nested rectangular mask.
        Color.clear
        .overlay {
            if loadedURL == url, let loaded {
                GeometryReader { geometry in
                    Image(decorative: loaded.image, scale: 1)
                        .resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            } else {
                ZStack {
                    LinearGradient(colors: [Color(hue: hue, saturation: 0.65, brightness: 0.5), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: title.kind == .movie ? "film.stack" : "play.rectangle.on.rectangle")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // Artwork is decorative; scaled-to-fill pixels must never intercept nearby controls.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: url) {
            let ticket = UUID()
            generation = ticket
            loaded = nil; loadedURL = nil
            guard let requested = url else { return }
            do {
                let image = try await ArtworkPipeline.shared.image(for: requested)
                guard !Task.isCancelled, generation == ticket, requested == url else { return }
                loadedURL = requested; loaded = image
            } catch {
                // Keep the existing offline placeholder. No failed image replaces another title.
            }
        }
        .onDisappear {
            generation = UUID()
            loaded = nil; loadedURL = nil
        }
    }
}

public struct CatalogPoster: View {
    @Environment(\.streamLabContrast) private var contrast
    let title: CatalogTitle
    public init(title: CatalogTitle) { self.title = title }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CatalogArtwork(title: title).frame(height: 220)
                .overlay(alignment: .topLeading) {
                    Text(title.typeLabel).font(.caption.bold())
                        .padding(8).background(.black.opacity(contrast == .increased ? 1 : 0.65), in: Capsule())
                        .padding(10)
                }
            Text(title.name).font(.headline).fixedSize(horizontal: false, vertical: true)
            Text("\(title.year) · \(title.rating.rawValue)").font(.caption).foregroundStyle(.secondary)
            Text(title.genre).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 160, alignment: .leading)
        // The enclosing link owns the entire card, including decorative artwork.
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title.name), \(title.rating.rawValue)")
        .foregroundStyle(.white)
    }
}

public struct LoadingCard: View {
    @Environment(\.streamLabContrast) private var contrast
    public init() {}
    public var body: some View {
        VStack(spacing: 12) {
            StreamLabLoadingIndicator().accessibilityHidden(true)
            Text("콘텐츠를 가져오고 있어요")
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pagination-loading-label")
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(StreamLabTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(contrast == .increased ? 1 : 0.2)))
        .padding(24)
    }
}


public struct StreamLabLoadingIndicator: View {
    @Environment(\.streamLabReduceMotion) private var reduceMotion
    public init() {}
    public var body: some View {
        Group {
            if reduceMotion { Image(systemName: "hourglass").accessibilityIdentifier("loading-static-indicator") }
            else { ProgressView().tint(.white) }
        }
    }
}

public struct StreamLabMotionPolicy: ViewModifier {
    @Environment(\.streamLabReduceMotion) private var reduceMotion
    public init() {}
    public func body(content: Content) -> some View {
        content.transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }
}

/// Keep determinate progress visible; only replace indefinite spinning.
public struct StreamLabProgressStyle: ProgressViewStyle {
    @Environment(\.streamLabReduceMotion) private var reduceMotion
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        if configuration.fractionCompleted != nil {
            ProgressView(configuration).progressViewStyle(.linear)
        } else if reduceMotion {
            HStack {
                Image(systemName: "hourglass").accessibilityHidden(true)
                configuration.label
            }
            .accessibilityElement(children: .combine)
        } else {
            ProgressView(configuration).progressViewStyle(.circular)
        }
    }
}

public extension EnvironmentValues {
    // System settings remain authoritative in release; deterministic debug-only UI coverage.
    var streamLabContrast: ColorSchemeContrast {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-increased-contrast") { return .increased }
        #endif
        return colorSchemeContrast
    }
    var streamLabReduceMotion: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-reduce-motion") { return true }
        #endif
        return accessibilityReduceMotion
    }
}
