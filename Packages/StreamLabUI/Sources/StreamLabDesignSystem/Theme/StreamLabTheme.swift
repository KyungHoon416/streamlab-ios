import SwiftUI
import StreamLabDomain

public enum StreamLabTheme {
    public static let accent = Color(red: 0.9, green: 0.04, blue: 0.1)
    public static let background = Color(red: 0.035, green: 0.035, blue: 0.045)
    public static let surface = Color(red: 0.1, green: 0.1, blue: 0.12)
}

public struct StreamLabButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(StreamLabTheme.accent.opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: 12))
    }
}

public struct CatalogArtwork: View {
    let title: CatalogTitle
    public init(title: CatalogTitle) { self.title = title }
    public var body: some View {
        let hue = Double(title.visualSeed % 360) / 360
        ZStack {
            LinearGradient(colors: [Color(hue: hue, saturation: 0.65, brightness: 0.5), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: title.kind == .movie ? "film.stack" : "play.rectangle.on.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.75))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityHidden(true)
    }
}

public struct CatalogPoster: View {
    let title: CatalogTitle
    public init(title: CatalogTitle) { self.title = title }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CatalogArtwork(title: title).frame(height: 180)
            Text(title.name).font(.headline).fixedSize(horizontal: false, vertical: true)
            Text("\(title.year) · \(title.rating.rawValue)").font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: 160, alignment: .leading)
        .foregroundStyle(.white)
    }
}

public struct LoadingCard: View {
    public init() {}
    public var body: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white).accessibilityHidden(true)
            Text("콘텐츠를 가져오고 있어요")
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pagination-loading-label")
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(StreamLabTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.2)))
        .padding(24)
    }
}
