import SwiftUI
import StreamLabDomain

@MainActor struct MyListButton: View {
    let title: CatalogTitle
    @ObservedObject var store: MyListStore

    var body: some View {
        Button { store.toggle(title) } label: {
            Label {
                Text(store.contains(title) ? "나의 리스트에서 제거" : "나의 리스트 추가")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: store.contains(title) ? "checkmark" : "plus")
            }
                .font(.headline).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .foregroundStyle(.white)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.4)))
        }
        .alert("리스트 저장", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .buttonStyle(.plain)
        .accessibilityValue(store.contains(title) ? "추가됨" : "추가 안 됨")
    }
}
