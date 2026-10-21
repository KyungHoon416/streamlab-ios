import SwiftUI
import StreamLabDomain
import StreamLabDesignSystem

@MainActor public struct DownloadsView: View {
    private let session: CatalogSession
    @ObservedObject private var store = OfflineDownloadStore.shared
    @ObservedObject private var notifications = DownloadNotifications.shared
    @Environment(\.scenePhase) private var phase
    @StateObject private var orientation = PlaybackOrientationSession()
    @State private var playing: OfflineDownload?

    public init(session: CatalogSession) { self.session = session }

    private var items: [OfflineDownload] { store.downloads(in: session) }
    private var savedBytes: Int64 {
        items.reduce(0) { total, item in
            let result = total.addingReportingOverflow(item.bytes)
            return result.overflow ? Int64.max : result.partialValue
        }
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(session.profile.displayName)의 다운로드")
                        .font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("downloads-profile")
                    Text("\(items.count)개 · 저장 공간 \(ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file))")
                        .accessibilityIdentifier("downloads-summary")
                    Text("현재 프로필의 Apple HLS 샘플입니다. 실제 작품 영상이 아닙니다.")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("기기 전체 관리 예산 1GB · 동시 다운로드 2개. 진행 중인 파일의 크기는 완료 후 반영됩니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)

                storageSummary
                Text("과제용 이용 기간: 저장 완료 후 7일. 만료 후에는 다시 다운로드해야 새로 재생할 수 있습니다. 실제 DRM 라이선스가 아닌 Mock 정책입니다.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                notificationSettings
                #if DEBUG
                if store.validationEnabled {
                    VStack {
                        Button("검증: 실제 HLS 1개") { Task { await store.validationEnqueue(session: session, count: 1) } }
                            .accessibilityIdentifier("download-validation-one")
                        Button("검증: 실제 HLS 3개") { Task { await store.validationEnqueue(session: session, count: 3) } }
                            .accessibilityIdentifier("download-validation-three")
                        Button("검증 상태 새로고침") { Task { await store.validationRefresh(accountID: session.accountID) } }
                            .accessibilityIdentifier("download-validation-refresh")
                        Button(store.validationLowDisk ? "검증: 공간 부족 해제" : "검증: 공간 부족 재현") {
                            store.validationToggleLowDisk()
                        }.accessibilityIdentifier("download-validation-low-disk")
                            .accessibilityValue(store.validationLowDisk ? "켜짐" : "꺼짐")
                        Button("검증: 이용 기간 만료") { store.validationExpire(session: session) }
                            .accessibilityIdentifier("download-validation-expire")
                        Button("검증: 만료 파일 재생 시도") {
                            guard let item = items.first(where: { $0.state == .expired }), playing == nil else { return }
                            orientation.begin(); playing = item
                        }.accessibilityIdentifier("download-validation-play-expired")
                        Button("검증: 전송 오류 발생") { store.validationInterruptTransfer() }
                            .accessibilityIdentifier("download-validation-interrupt")
                        Text(store.validationSnapshot).font(.caption)
                            .accessibilityIdentifier("download-validation-status")
                    }
                }
                #endif
                if let error = store.errorMessage {
                    Text(error).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("downloads-error")
                }
                if items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("아직 다운로드한 샘플이 없습니다", systemImage: "arrow.down.circle")
                            .font(.headline)
                        Text("홈이나 검색에서 작품을 열고 ‘HLS 샘플 다운로드’를 눌러 주세요.")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("downloads-empty")
                } else {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(item.title).font(.headline).accessibilityAddTraits(.isHeader)
                                .fixedSize(horizontal: false, vertical: true)
                            OfflineDownloadActions(item: item, session: session, idPrefix: "library-\(item.titleID)") {
                                guard session.isActive, playing == nil else { return }
                                orientation.begin()
                                playing = item
                            }
                            NavigationLink(value: item.titleID) {
                                Label("작품 상세 보기", systemImage: "chevron.right")
                                    .frame(minHeight: 44)
                            }
                            .accessibilityIdentifier("library-\(item.titleID)-detail")
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(StreamLabTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityElement(children: .contain)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("downloads-scroll")
        .background(StreamLabTheme.background)
        .background(PlaybackPresenterScene(session: orientation).frame(width: 0, height: 0))
        .task { store.refreshExpiration(); await notifications.refresh() }
        .onChange(of: phase) { _, value in
            if value == .active { store.refreshExpiration(); Task { await notifications.refresh() } }
        }
        .navigationTitle("다운로드")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $playing, onDismiss: { orientation.finish() }) { item in
            PlaybackView(titleID: item.titleID, title: item.title, session: session,
                         orientationSession: orientation, initialSource: .downloadedHLS)
                .id("\(session.id.uuidString):\(item.id.uuidString)")
        }
    }
    @ViewBuilder private var storageSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("기기 전체 다운로드 예산").font(.headline)
            if let usage = try? OfflineDownloadBudget.usage(in: store.records) {
                ProgressView(value: usage.fraction)
                    .accessibilityLabel("다운로드 예산 사용량")
                    .accessibilityValue("\(Int(usage.fraction * 100))퍼센트")
                Text("저장 완료 \(size(usage.completedBytes)) · 기타 파일 \(size(usage.otherFileBytes))")
                Text("전송 예약 \(size(usage.reservedBytes)) · 남은 예산 \(size(usage.remainingBytes))")
                    .accessibilityIdentifier("downloads-storage-remaining")
                if usage.remainingBytes < OfflineDownloadBudget.reservation {
                    Text("새 다운로드를 시작할 때 고정하지 않은 오래된 파일이 자동 정리될 수 있습니다. 공간이 부족하면 고정을 해제하거나 필요 없는 파일을 삭제해 주세요.")
                        .accessibilityIdentifier("downloads-storage-guidance")
                }
            } else {
                Text("저장량을 확인할 수 없습니다. 앱을 다시 실행해 주세요.")
            }
            Text("모든 프로필 합계 · 한도 1GB. 전송·일시정지 중인 작업은 작업당 최소 500MB와 작업 자리를 유지합니다. 기기의 실제 여유 공간과 다르며, 파일 크기는 완료 후 반영됩니다.")
                .foregroundStyle(.secondary)
        }
        .font(.caption).fixedSize(horizontal: false, vertical: true)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(StreamLabTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("downloads-storage")
    }

    private func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    @ViewBuilder private var notificationSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch notifications.permission {
            case .notDetermined:
                Button("백그라운드 다운로드 완료 알림 켜기") { Task { await notifications.request() } }
                    .buttonStyle(.bordered).disabled(notifications.requesting)
                    .accessibilityIdentifier("download-notification-enable")
            case .denied:
                Text("완료 알림이 꺼져 있습니다. 다운로드는 계속 이용할 수 있습니다.")
                Button("설정에서 알림 허용") {
                    notifications.openSettings()
                }.accessibilityIdentifier("download-notification-settings")
            default:
                Label("백그라운드 다운로드 완료 알림 켜짐", systemImage: "bell.badge")
                    .accessibilityIdentifier("download-notification-enabled")
            }
            if let error = notifications.errorMessage { Text(error).foregroundStyle(.secondary) }
        }
        .font(.callout).fixedSize(horizontal: false, vertical: true)
    }

}
