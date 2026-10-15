import SwiftUI
import StreamLabDomain
import StreamLabDesignSystem

/// Demo metadata only; each episode deliberately uses the same bundled 30-second clip.
@MainActor struct DetailEpisodeSection: View {
    let title: CatalogTitle
    let positions: [String: Double]
    let onSelect: @MainActor (PlaybackModel.Source) -> Void
    @Environment(\.dynamicTypeSize) private var textSize

    static let sources: [PlaybackModel.Source] = [.episode1, .episode2, .episode3]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("회차 · 데모 시즌 1")
                .font(.title2.bold()).accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            Text("3개 회차는 동일한 30초 무음 테스트 영상입니다. 시청 기록은 회차별로 저장됩니다.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(Self.sources.enumerated()), id: \.element.id) { index, source in
                Button { onSelect(source) } label: {
                    if textSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 12) {
                            artwork
                            information(number: index + 1, source: source)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 14) {
                            artwork.frame(width: 128)
                            information(number: index + 1, source: source)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("데모 \(index + 1)화 재생, 30초")
                .accessibilityValue(progressLabel(source))
                .accessibilityIdentifier("detail-episode-\(index + 1)")
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StreamLabTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var artwork: some View {
        CatalogArtwork(title: title)
            .frame(height: 80)
            .clipped()
            .overlay { Image(systemName: "play.circle.fill").font(.title).foregroundStyle(.white).shadow(radius: 3) }
            .accessibilityHidden(true)
    }

    private func progressLabel(_ source: PlaybackModel.Source) -> String {
        guard let seconds = positions[source.progressID] else { return "이어보기 기록 없음" }
        return "\(Int(seconds))초부터 이어보기"
    }

    private func information(number: Int, source: PlaybackModel.Source) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number)화 · 데모 영상").font(.headline)
            Text("00:00:30 · 오프라인 재생").font(.caption).foregroundStyle(.secondary)
            Text(number == 3 ? "마지막 화입니다. 종료 후 자동 재생을 멈춥니다." : "재생이 끝나면 다음 화로 이어집니다.")
                .font(.subheadline).foregroundStyle(.secondary)
            if let seconds = positions[source.progressID] {
                ProgressView(value: min(1, max(0, seconds / 30))).tint(StreamLabTheme.accent)
                Text(progressLabel(source)).font(.caption)
            } else {
                Text("처음부터 재생").font(.caption)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
