import SwiftUI
import StreamLabDomain
import StreamLabDesignSystem

@MainActor public struct ProfileSelectionView: View {
    private let onSelect: (ViewerProfile) -> Void
    public init(onSelect: @escaping (ViewerProfile) -> Void) { self.onSelect = onSelect }

    public var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("STREAMLAB").font(.largeTitle.bold()).foregroundStyle(StreamLabTheme.accent)
                Text("누가 시청하시나요?").font(.title.bold()).accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 24)], spacing: 24) {
                    ForEach(ViewerProfile.demo) { profile in
                        Button { onSelect(profile) } label: {
                            VStack(spacing: 12) {
                                Image(systemName: profile.avatarSymbol)
                                    .font(.largeTitle)
                                    .frame(width: 100, height: 100)
                                    .background(profile.kind == .kids ? Color.indigo : StreamLabTheme.accent, in: RoundedRectangle(cornerRadius: 20))
                                Text(profile.displayName).font(.title3.bold())
                                if profile.kind == .kids { Text("키즈 · ALL / 7+").font(.caption) }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(profile.displayName)
                        .accessibilityHint(profile.kind == .kids ? "키즈 콘텐츠로 이동" : "홈으로 이동")
                        .accessibilityIdentifier("profile-\(profile.id)")
                    }
                }
                Text("나만의 다음 이야기를 만나보세요.").font(.body).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(StreamLabTheme.background)
        .foregroundStyle(.white)
    }
}
