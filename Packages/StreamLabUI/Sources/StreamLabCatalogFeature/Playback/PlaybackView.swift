import SwiftUI
import StreamLabDesignSystem

@MainActor struct PlaybackView: View {
    @StateObject private var model: PlaybackModel
    @State private var source: PlaybackModel.Source = .bundled
    @State private var scrubPosition: Double = 0
    @State private var scrubbing = false
    @State private var controlsVisible = true
    @State private var sourceSheet = false
    @State private var fillsScreen = false
    @State private var landscape = true
    @State private var interaction = 0
    @State private var started = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dynamicTypeSize) private var textSize
    private let title: String

    init(titleID: String, title: String, session: CatalogSession) {
        self.title = title
        _model = StateObject(wrappedValue: PlaybackModel(titleID: titleID, session: session))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                PlayerSurface(player: model.player, fillsScreen: fillsScreen)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                Button {
                    if controlsVisible && mayHide { controlsVisible = false }
                    else { revealControls() }
                } label: {
                    Color.clear.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(controlsVisible ? "재생 컨트롤 숨기기" : "재생 컨트롤 표시")
                .accessibilityHidden(controlsVisible && !mayHide)
                .accessibilityIdentifier(controlsVisible ? "playback-surface" : "playback-reveal-controls")
                if controlsVisible {
                    LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0.15), .black.opacity(0.85)],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea().allowsHitTesting(false)
                    if textSize.isAccessibilitySize || geometry.size.height < 300 {
                        ScrollView {
                            VStack(spacing: 20) { header; transport; footer }
                                .padding(20)
                        }
                    } else {
                        VStack(spacing: 12) {
                            header
                            Spacer(minLength: 8)
                            transport
                            Spacer(minLength: 8)
                            footer
                        }
                        .padding(20)
                    }
                }
            }
        }
        .background {
            PlaybackOrientation(landscape: landscape)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .tint(StreamLabTheme.accent)
        .preferredColorScheme(.dark)
        .statusBarHidden(!controlsVisible)
        .sheet(isPresented: $sourceSheet) { sourceSelection }
        .onAppear {
            guard !started else { return }
            started = true
            model.setForeground(phase == .active)
            model.load(source)
        }
        .onDisappear { model.stop() }
        .onChange(of: source) { _, value in
            scrubbing = false
            revealControls()
            model.load(value)
        }
        .onChange(of: phase) { _, value in
            model.setForeground(value == .active)
            if value != .active { scrubbing = false; revealControls() }
        }
        .onChange(of: model.status) { _, value in
            if value != .playing { revealControls() }
        }
        .onChange(of: voiceOver) { _, _ in revealControls() }
        .onChange(of: textSize) { _, _ in revealControls() }
        .task(id: hideKey) {
            guard mayHide, controlsVisible else { return }
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            guard !Task.isCancelled, mayHide else { return }
            controlsVisible = false
        }
    }

    private var mayHide: Bool {
        model.status == .playing && !model.isSeeking && !scrubbing && !sourceSheet
            && !voiceOver && !textSize.isAccessibilitySize && phase == .active
    }

    private struct HideKey: Equatable {
        let allowed: Bool
        let visible: Bool
        let interaction: Int
    }

    private var hideKey: HideKey {
        HideKey(allowed: mayHide, visible: controlsVisible, interaction: interaction)
    }

    private func revealControls() {
        controlsVisible = true
        interaction &+= 1
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            iconButton("닫기", symbol: "xmark", id: "playback-close") {
                model.stop()
                dismiss()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
                Text("테스트 영상 · \(source.rawValue)")
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            iconButton("영상 소스 선택", symbol: "ellipsis", id: "playback-source") {
                sourceSheet = true
            }
        }
    }

    private var transport: some View {
        VStack(spacing: 12) {
            if model.status == .loading || model.isSeeking {
                ProgressView().tint(.white).accessibilityLabel("영상 로딩 중")
            }
            Text(model.status.label)
                .font(.callout).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("playback-status")
            if case .failed = model.status {
                Button("재생 다시 시도") { revealControls(); model.load() }
                    .buttonStyle(StreamLabButtonStyle())
                    .accessibilityIdentifier("playback-retry")
            } else {
                HStack(spacing: 32) {
                    iconButton("10초 뒤로", symbol: "gobackward.10", id: "playback-backward", size: 56) {
                        model.seek(to: model.position - 10)
                    }
                    .disabled(!model.canSeek)
                    iconButton(model.status == .ended ? "다시 재생" : (model.status == .playing ? "일시 정지" : "재생"),
                               symbol: model.status == .ended ? "arrow.counterclockwise" : (model.status == .playing ? "pause.fill" : "play.fill"),
                               id: "playback-toggle", size: 64) {
                        model.togglePlayback()
                    }
                    .disabled(model.player == nil || model.status == .loading || model.isSeeking)
                    iconButton("10초 앞으로", symbol: "goforward.10", id: "playback-forward", size: 56) {
                        model.seek(to: model.position + 10)
                    }
                    .disabled(!model.canSeek)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if model.duration > 0 {
                Slider(value: Binding(get: {
                    min(model.duration, max(0, scrubbing ? scrubPosition : model.position))
                }, set: { scrubPosition = $0 }), in: 0...max(1, model.duration)) {
                    Text("재생 위치")
                } onEditingChanged: { editing in
                    revealControls()
                    if editing { scrubPosition = model.position }
                    scrubbing = editing
                    if !editing { model.seek(to: scrubPosition) }
                }
                .frame(minHeight: 44)
                .disabled(!model.canSeek)
                .accessibilityValue("\(Int(model.position))초, 전체 \(Int(model.duration))초")
                .accessibilityAdjustableAction { direction in
                    revealControls()
                    switch direction {
                    case .increment: model.seek(to: model.position + 10)
                    case .decrement: model.seek(to: model.position - 10)
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier("playback-position")
            }
            HStack(spacing: 12) {
                Text("\(Int(scrubbing ? scrubPosition : model.position))초 / \(Int(model.duration))초")
                    .font(.caption).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("playback-time")
                Spacer(minLength: 0)
                iconButton(fillsScreen ? "영상 전체 보기" : "화면 채우기", symbol: fillsScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", id: "playback-fit") {
                    fillsScreen.toggle()
                }
                .accessibilityValue(fillsScreen ? "화면 채우기" : "영상 전체 보기")
                iconButton(landscape ? "세로 화면 요청" : "가로 화면 요청", symbol: "rotate.right", id: "playback-rotate") {
                    landscape.toggle()
                }
            }
        }
    }

    private func iconButton(_ label: String, symbol: String, id: String, size: CGFloat = 44,
                            action: @escaping @MainActor () -> Void) -> some View {
        Button {
            revealControls()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: size >= 56 ? 30 : 21, weight: .semibold))
                .frame(width: size, height: size)
                .background(.black.opacity(0.45), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private var sourceSelection: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PlaybackModel.Source.allCases) { option in
                        Button {
                            source = option
                            sourceSheet = false
                            revealControls()
                        } label: {
                            HStack {
                                Text(option.rawValue).fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                if source == option { Image(systemName: "checkmark") }
                            }
                        }
                        .accessibilityValue(source == option ? "선택됨" : "")
                    }
                } footer: {
                    Text("모든 작품은 같은 테스트 영상을 재생합니다. 오프라인 데모는 30초 무음이며 HLS는 인터넷 연결이 필요합니다. 소스를 바꾸면 처음부터 재생합니다.")
                }
            }
            .navigationTitle("영상 소스")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { sourceSheet = false; revealControls() }
                }
            }
        }
    }
}
