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
                OfflineDownloadActions(item: item, session: session, play: play)
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

/// Shared by Detail and the profile download library so state/actions stay consistent.
@MainActor struct OfflineDownloadActions: View {
    let item: OfflineDownload
    let session: CatalogSession
    var idPrefix = "download"
    let play: () -> Void
    @ObservedObject private var store = OfflineDownloadStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch item.state {
            case .queued:
                Text("다운로드 대기 중").accessibilityIdentifier("\(idPrefix)-queued")
            case .downloading:
                let fraction = store.progress[item.id] ?? 0
                VStack(alignment: .leading, spacing: 6) {
                    Text("다운로드 중 · \(min(99, Int(fraction * 100)))%")
                        .monospacedDigit().accessibilityIdentifier("\(idPrefix)-percentage")
                    ProgressView(value: fraction)
                    Text("Wi-Fi 연결을 유지해 주세요. 앱을 나가도 다운로드가 계속됩니다.")
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                }.accessibilityElement(children: .contain)
                    .accessibilityIdentifier("\(idPrefix)-progress")
                Button("일시정지") { store.pause(item.id, session: session) }
                    .buttonStyle(.bordered).accessibilityIdentifier("\(idPrefix)-pause")
            case .paused:
                Text("일시정지됨").accessibilityIdentifier("\(idPrefix)-paused")
                Text("진행 중인 작업과 저장 공간을 유지합니다. 재개하면 같은 작업을 이어받습니다.")
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
                Button("다운로드 재개") { store.resume(item.id, session: session) }
                    .buttonStyle(.bordered).accessibilityIdentifier("\(idPrefix)-resume")
            case .complete:
                Text("저장 완료 · \(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))")
                    .accessibilityIdentifier("\(idPrefix)-complete")
                Button(action: play) { Label("다운로드한 샘플 재생", systemImage: "play.fill") }
                    .buttonStyle(StreamLabButtonStyle()).accessibilityIdentifier("\(idPrefix)-play")
                Button { store.togglePin(item.id) } label: {
                    Text(item.pinned ? "고정 해제" : "자동 정리에서 보호")
                        .fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
                }
                    .buttonStyle(.bordered).accessibilityIdentifier("\(idPrefix)-pin")
                    .accessibilityValue(item.pinned ? "고정됨" : "고정 안 됨")
            case .removing:
                Text("다운로드를 취소하고 파일을 정리하는 중…")
            case .failed:
                Text(item.message ?? "다운로드를 완료하지 못했습니다.")
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("\(idPrefix)-failed")
                Button { Task { await store.retry(item.id, session: session) } } label: {
                    Label(store.retrying.contains(item.id) ? "다시 다운로드 준비 중…" : "다시 다운로드", systemImage: "arrow.clockwise")
                        .fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(store.retrying.contains(item.id) || !session.isActive)
                .accessibilityIdentifier("\(idPrefix)-retry")
            }
            Button(role: .destructive) { store.delete(item.id) } label: {
                Text(item.state == .complete ? "다운로드 삭제" : "취소 및 기록 삭제")
                    .fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
            }
                .buttonStyle(.bordered).accessibilityIdentifier("\(idPrefix)-delete").disabled(item.state == .removing)
        }
    }
}
