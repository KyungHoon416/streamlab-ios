import SwiftUI
import StreamLabDomain
import StreamLabDesignSystem

public struct ProfileSelectionView: View {
    public let onSelect: (ViewerProfile) -> Void

    public init(onSelect: @escaping (ViewerProfile) -> Void) { self.onSelect = onSelect }

    public var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("STREAMLAB")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(StreamLabTheme.accent)
            Text("누가 시청하나요?")
                .font(.title2.bold())
                .foregroundStyle(.white)
            HStack(alignment: .top, spacing: 18) {
                ForEach(ViewerProfile.demo) { profile in
                    Button {
                        onSelect(profile)
                    } label: {
                        VStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 17)
                                .fill(profile.kind == .kids ? Color.orange.gradient : Color.indigo.gradient)
                                .frame(width: 94, height: 94)
                                .overlay {
                                    Image(systemName: profile.avatarSymbol)
                                        .font(.system(size: 36))
                                        .foregroundStyle(.white)
                                }
                            Text(profile.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(profile.displayName) 프로필 선택")
                }
            }
            Spacer()
            Text("독립적인 학습용 Mock 콘텐츠 · 실제 Netflix와 무관")
                .font(.caption)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StreamLabTheme.background)
    }
}
