import SwiftUI
import StreamLabDomain
import StreamLabDesignSystem

@MainActor struct OfflineDownloadSection: View {
    let title: CatalogTitle
    let session: CatalogSession
    let play: () -> Void
    @ObservedObject private var store = OfflineDownloadStore.shared
    private var record: OfflineDownload? {
        store.record(accountID: session.accountID, profileID: session.profile.id, titleID: title.id)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오프라인 다운로드").font(.headline).accessibilityAddTraits(.isHeader)
            Text("Wi-Fi에서 Apple HLS 샘플을 저장합니다. 실제 작품 영상이 아닙니다. 총 1GB, 동시 2개까지 관리하며 공간이 부족하면 고정하지 않은 오래된 파일을 정리합니다.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let item = record {
                switch item.state {
                case .queued:
                    Text("다운로드 대기 중").accessibilityIdentifier("download-queued")
                case .downloading:
                    ProgressView(value: store.progress[item.id] ?? 0) {
                        Text("다운로드 중 · Wi-Fi 연결을 유지해 주세요")
                    }.accessibilityIdentifier("download-progress")
                case .complete:
                    Text("저장 완료 · \(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))")
                        .accessibilityIdentifier("download-complete")
                    Button(action: play) { Label("다운로드한 샘플 재생", systemImage: "play.fill") }
                        .buttonStyle(StreamLabButtonStyle()).accessibilityIdentifier("download-play")
                    Button(item.pinned ? "고정 해제" : "자동 정리에서 보호") { store.togglePin(item.id) }
                        .buttonStyle(.bordered).accessibilityIdentifier("download-pin")
                        .accessibilityValue(item.pinned ? "고정됨" : "고정 안 됨")
                case .removing:
                    Text("다운로드를 취소하고 파일을 정리하는 중…")
                case .failed:
                    Text(item.message ?? "다운로드를 완료하지 못했습니다.")
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("download-failed")
                }
                Button(item.state == .complete ? "다운로드 삭제" : "취소 및 기록 삭제", role: .destructive) { store.delete(item.id) }
                    .buttonStyle(.bordered).accessibilityIdentifier("download-delete").disabled(item.state == .removing)
            } else {
                Button { store.enqueue(title: title, session: session) } label: {
                    Label("HLS 샘플 다운로드", systemImage: "arrow.down.circle")
                }.buttonStyle(.bordered).accessibilityIdentifier("download-start")
            }
            if let error = store.errorMessage {
                Text(error).font(.caption).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("download-error")
            }
            Text("다운로드한 음성·자막만 오프라인에서 제공됩니다. 로그아웃하면 다운로드도 삭제됩니다.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(StreamLabTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }
}
