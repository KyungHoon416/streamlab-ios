import AVKit
import SwiftUI
import StreamLabDesignSystem

@MainActor struct PlaybackView: View {
    @StateObject private var model: PlaybackModel
    @State private var source: PlaybackModel.Source = .bundled
    @State private var scrubPosition: Double = 0
    @State private var scrubbing = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    private let title: String

    init(titleID: String, title: String, session: CatalogSession) {
        self.title = title
        _model = StateObject(wrappedValue: PlaybackModel(titleID: titleID, session: session))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(title).font(.title.bold()).fixedSize(horizontal: false, vertical: true)
                    Text("모든 작품은 동일한 테스트 영상을 재생합니다. 오프라인 데모는 30초 무음 영상이며, HLS는 인터넷 연결이 필요합니다.")
                        .font(.callout).foregroundStyle(.secondary)
                    Picker("영상 소스", selection: $source) {
                        ForEach(PlaybackModel.Source.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("playback-source")
                    if let player = model.player {
                        VideoPlayer(player: player)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .frame(minHeight: 180)
                            .accessibilityLabel("데모 영상")
                    }
                    Text(model.status.label)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("playback-status")
                    if model.status == .loading { ProgressView("로딩 중") }
                    if case .failed = model.status {
                        Button("재생 다시 시도") { model.load() }
                            .buttonStyle(StreamLabButtonStyle())
                            .accessibilityIdentifier("playback-retry")
                    }
                    if model.duration > 0 {
                        Slider(value: Binding(get: { scrubbing ? scrubPosition : model.position },
                                              set: {
                                                  scrubPosition = $0
                                                  if !scrubbing { model.seek(to: $0) }
                                              }),
                               in: 0...max(1, model.duration)) { Text("재생 위치") }
                            onEditingChanged: { editing in
                                if editing { scrubPosition = model.position }
                                scrubbing = editing
                                if !editing { model.seek(to: scrubPosition) }
                            }
                            .disabled(!model.canSeek)
                            .accessibilityValue("\(Int(model.position))초, 전체 \(Int(model.duration))초")
                            .accessibilityIdentifier("playback-position")
                        Text("\(Int(model.position))초 / \(Int(model.duration))초")
                            .monospacedDigit().accessibilityIdentifier("playback-time")
                    }
                    VStack(spacing: 12) {
                        Button(model.status == .ended ? "다시 재생" : (model.status == .playing ? "일시 정지" : "재생")) {
                            model.togglePlayback()
                        }
                        .buttonStyle(StreamLabButtonStyle())
                        .disabled(model.player == nil || model.status == .loading || model.isSeeking)
                        .accessibilityIdentifier("playback-toggle")
                        Button("10초 뒤로") { model.seek(to: model.position - 10) }
                            .disabled(!model.canSeek).accessibilityIdentifier("playback-backward")
                        Button("10초 앞으로") { model.seek(to: model.position + 10) }
                            .disabled(!model.canSeek).accessibilityIdentifier("playback-forward")
                    }
                }
                .padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }
            .background(StreamLabTheme.background)
            .navigationTitle("데모 재생")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { model.stop(); dismiss() }
                        .accessibilityIdentifier("playback-close")
                }
            }
        }
        .tint(StreamLabTheme.accent)
        .onAppear { model.setForeground(phase == .active); model.load(source) }
        .onDisappear { model.stop() }
        .onChange(of: source) { _, value in scrubbing = false; model.load(value) }
        .onChange(of: phase) { _, value in model.setForeground(value == .active) }
    }
}
