import SwiftUI
import StreamLabDomain

public enum StreamLabTheme {
    public static let background = Color(red: 0.045, green: 0.05, blue: 0.07)
    public static let surface = Color(red: 0.095, green: 0.105, blue: 0.14)
    public static let accent = Color(red: 0.90, green: 0.13, blue: 0.17)
}

public struct PosterArtwork: View {
    public let title: CatalogTitle
    public var showName: Bool

    public init(title: CatalogTitle, showName: Bool = true) {
        self.title = title
        self.showName = showName
    }

    private var palette: [Color] {
        let palettes: [[Color]] = [
            [.indigo, .black], [.orange, .red], [.teal, .indigo],
            [.purple, .black], [.blue, .black], [.brown, .black],
            [.pink, .purple], [.cyan, .blue], [.red, .black],
            [.mint, .indigo], [.yellow, .orange], [.gray, .indigo]
        ]
        return palettes[title.visualSeed % palettes.count]
    }

    private var symbol: String {
        let symbols = ["sparkles.tv", "moon.stars.fill", "globe.americas.fill", "mountain.2.fill",
                       "film.stack.fill", "bolt.fill", "safari.fill", "cloud.moon.fill",
                       "waveform", "camera.filters", "star.circle.fill", "theatermasks.fill"]
        return symbols[title.visualSeed % symbols.count]
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: symbol)
                    .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.46, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.34))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if showName {
                    LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                    Text(title.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .padding(12)
                }
            }
            .clipped()
        }
        .accessibilityLabel("\(title.name) 포스터")
    }
}

public struct PosterCard: View {
    public let title: CatalogTitle

    public init(title: CatalogTitle) { self.title = title }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterArtwork(title: title)
                .frame(width: 146, height: 205)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(title.genre + " · " + title.rating.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 146, alignment: .leading)
    }
}
