import SwiftUI
import StreamLabDesignSystem

@MainActor struct PlaybackView: View {
    @StateObject private var model: PlaybackModel
    private let orientationSession: PlaybackOrientationSession
    @State private var source: PlaybackModel.Source = .bundled
    @State private var scrubPosition: Double = 0
    @State private var scrubbing = false
    @State private var interactingWithControls = false
    @State private var controlsVisible = true
    @State private var sourceSheet = false
    @State private var subtitleSheet = false
    @State private var fillsScreen = false
    @State private var landscape = true
    @State private var interaction = 0
    @State private var started = false
    @State private var showsPlaybackFailure = false
    private let onCancelFailure: (@MainActor () -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dynamicTypeSize) private var textSize
    private let title: String

    init(titleID: String, title: String, session: CatalogSession, orientationSession: PlaybackOrientationSession, initialSource: PlaybackModel.Source = .bundled, syncDeviceID: String? = nil, onCancelFailure: (@MainActor () -> Void)? = nil) {
        self.onCancelFailure = onCancelFailure
        _source = State(initialValue: initialSource)
        self.title = title
        self.orientationSession = orientationSession
        _model = StateObject(wrappedValue: PlaybackModel(titleID: titleID, session: session, syncDeviceID: syncDeviceID))
    }

    private func timeParts(_ seconds: Double) -> (hours: Int, minutes: Int, seconds: Int) {
        let total = max(0, Int(exactly: seconds.rounded(.down)) ?? 0)
        return (total / 3600, (total % 3600) / 60, total % 60)
    }

    private func timeText(_ seconds: Double) -> String {
        let value = timeParts(seconds)
        return [value.hours, value.minutes, value.seconds]
            .map { $0 < 10 ? "0\($0)" : String($0) }.joined(separator: ":")
    }

    private func spokenTime(_ seconds: Double) -> String {
        let value = timeParts(seconds)
        return "\(value.hours)시간 \(value.minutes)분 \(value.seconds)초"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                PlayerSurface(player: model.player, fillsScreen: fillsScreen, pictureInPicture: model.pictureInPicture, onLayerAvailable: model.attachVideoLayer)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                // Behind the HUD: gestures cannot steal taps from buttons or the slider.
                if !voiceOver {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture(count: 2)
                                .exclusively(before: SpatialTapGesture(count: 1))
                                .onEnded { value in
                                    switch value {
                                    case .first(let tap):
                                        guard model.canSeek else { return }
                                        revealControls()
                                        model.seek(to: model.position + (tap.location.x < geometry.size.width / 2 ? -10 : 10))
                                    case .second:
                                        if controlsVisible && mayHide { controlsVisible = false }
                                        else { revealControls() }
                                    }
                                }
                        )
                        .accessibilityHidden(true)
                }
                if !controlsVisible {
                    Button { revealControls() } label: { Color.clear.contentShape(Rectangle()) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("재생 컨트롤 표시")
                        .accessibilityValue(model.status.label)
                        .accessibilityIdentifier("playback-reveal-controls")
                        .highPriorityGesture(
                            SpatialTapGesture(count: 2)
                                .exclusively(before: SpatialTapGesture(count: 1))
                                .onEnded { value in
                                    revealControls()
                                    if case .first(let tap) = value, model.canSeek {
                                        model.seek(to: model.position + (tap.location.x < geometry.size.width / 2 ? -10 : 10))
                                    }
                                }
                        )
                }
                if !controlsVisible {
                    VStack { Spacer(); subtitleCaption.padding(.horizontal, 24).padding(.bottom, 24) }
                        .allowsHitTesting(false)
                }
                if controlsVisible {
                    LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0.15), .black.opacity(0.85)],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea().allowsHitTesting(false)
                    if textSize.isAccessibilitySize {
                        // At accessibility sizes, preserve full scrolling and untruncated text.
                        VStack(spacing: 0) {
                            header.padding(.horizontal, 20).padding(.vertical, 8)
                            ScrollView {
                                VStack(spacing: 12) {
                                    transport(compact: false)
                                    footer
                                }
                                .padding(20)
                            }
                            .accessibilityIdentifier("playback-controls-scroll")
                        }
                    } else {
                        let compact = geometry.size.height < 500
                        ZStack {
                            VStack(spacing: 0) {
                                VStack(spacing: compact ? 4 : 12) {
                                    header
                                    ScrollView {
                                        transport(compact: compact, includesButtons: false)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .accessibilityIdentifier("playback-controls-scroll")
                                    .onScrollPhaseChange { _, scrollPhase in
                                        interactingWithControls = scrollPhase != .idle
                                        if scrollPhase == .idle { revealControls() }
                                    }
                                }
                                // Reserve the middle 88pt for the transport buttons.
                                .frame(height: max(0, geometry.size.height / 2 - 44 - (compact ? 8 : 20)))
                                Spacer(minLength: 88)
                                footer
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, compact ? 8 : 20)
                            playbackButtons
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .allowsHitTesting(!subtitleSheet)
        .accessibilityHidden(subtitleSheet)
        .overlay {
            if subtitleSheet { subtitleSelection }
        }
        .background {
            PlaybackOrientation(landscape: landscape, session: orientationSession)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .tint(StreamLabTheme.accent)
        .preferredColorScheme(.dark)
        .statusBarHidden(!controlsVisible)
        .sheet(isPresented: $sourceSheet) { sourceSelection }
        .alert("영상을 불러올 수 없습니다", isPresented: $showsPlaybackFailure) {
            Button("취소", role: .cancel) {
                model.stop()
                orientationSession.stopRequests()
                onCancelFailure?()
                dismiss()
            }
            Button("재시도") {
                revealControls()
                model.retryPlayback()
            }
            .disabled(!model.canRetryPlayback)
        } message: {
            Text("\(model.status.label)\n\n남은 재시도: \(model.retryBudget.remaining)회. 모두 사용하면 플레이어를 닫고 다시 열어 주세요.")
        }

        .onAppear {
            guard !started else { return }
            started = true
            model.setForeground(phase == .active)
            model.load(source)
        }
        .onDisappear { model.stop(); orientationSession.stopRequests() }
        .onChange(of: source) { _, value in
            scrubbing = false
            revealControls()
            if value != model.source { model.load(value) }
        }
        .onChange(of: model.source) { _, value in
            source = value
            scrubbing = false
            revealControls()
        }
        .onChange(of: phase) { _, value in
            model.setForeground(value == .active)
            if value != .active { scrubbing = false; revealControls() }
        }
        .onChange(of: model.status) { _, value in
            if value != .playing { revealControls() }
            if case .failed = value, model.source.isHLS || model.failureIsMediaReset {
                showsPlaybackFailure = true
            }
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
        #if DEBUG
        // Keep real playback state observable during the opt-in HLS end-to-end test.
        // This changes only HUD visibility, never player state or episode timing.
        if ProcessInfo.processInfo.arguments.contains("--ui-test-keep-playback-controls") { return false }
        #endif
        return model.status == .playing && !model.isSeeking && !scrubbing && !interactingWithControls && !sourceSheet && !subtitleSheet
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
                orientationSession.stopRequests()
                dismiss()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
                Text("테스트 영상 · \(source.rawValue)")
                    .accessibilityIdentifier("playback-source-label")
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            iconButton(model.pipRunning ? "전체 화면으로 복귀" : "작은 화면으로 재생",
                       symbol: model.pipRunning ? "pip.exit" : "pip.enter", id: "playback-pip") {
                revealControls()
                model.togglePictureInPicture()
            }
            .disabled(!model.pictureInPicture.supported || (!model.pipRunning && !model.pipPossible))
            .accessibilityHint(pipAvailabilityMessage.isEmpty
                ? "먼저 이 버튼을 누른 뒤 홈으로 이동하면 작은 창에서 재생합니다."
                : pipAvailabilityMessage)
            iconButton("영상 소스 선택", symbol: "ellipsis", id: "playback-source") {
                model.cancelNextEpisode()
                sourceSheet = true
            }
        }
    }

    private var pipAvailabilityMessage: String {
        if !model.pictureInPicture.supported {
            return "현재 실행 환경에서는 PiP를 지원하지 않습니다. PiP를 지원하는 실제 iPhone 또는 iPad에서 확인해 주세요."
        }
        if !source.isHLS {
            return "PiP는 HLS 영상에서 사용할 수 있습니다."
        }
        if !model.pipRunning && !model.pipPossible {
            return "PiP 준비 중입니다. 영상이 재생된 뒤에도 버튼이 비활성화되어 있으면 실행 환경과 재생 상태를 확인해 주세요."
        }
        return ""
    }

    private func transport(compact: Bool, includesButtons: Bool = true) -> some View {
        VStack(spacing: compact ? 4 : 12) {
            subtitleCaption
            if !pipAvailabilityMessage.isEmpty && !(model.status == .ended && model.source.nextEpisode != nil) {
                Text(pipAvailabilityMessage)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("playback-pip-availability")
            }
            if model.pipRunning {
                Text("작은 화면에서 재생 중")
                    .accessibilityIdentifier("playback-pip-active")
            }
            if !model.pipMessage.isEmpty {
                Text(model.pipMessage).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("playback-pip-error")
            }
            if model.status == .ended, let next = model.source.nextEpisode {
                VStack(spacing: compact ? 4 : 8) {
                    let headingLayout = compact ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 8))
                    headingLayout {
                        Text(next.rawValue).font(compact ? .caption : .headline)
                            .fixedSize(horizontal: false, vertical: true)
                        if let seconds = model.nextEpisodeSeconds {
                            Text("\(seconds)초 후 다음 화 재생")
                                .font(compact ? .caption : .body)
                                .accessibilityIdentifier("playback-next-countdown")
                        }
                    }
                    // In landscape the upper viewport is short. Keep both timed
                    // actions on one row; accessibility sizes retain vertical scrolling.
                    let actionLayout = compact ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 8))
                    actionLayout {
                        if model.nextEpisodeSeconds != nil {
                            Button { model.cancelNextEpisode() } label: {
                                Text("자동 다음 화 취소")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("playback-next-cancel")
                        }
                        Button("다음 화 지금 재생") { revealControls(); model.playNextEpisode() }
                            .buttonStyle(StreamLabButtonStyle())
                            .accessibilityIdentifier("playback-next-now")
                    }
                }
            }
            if !model.syncMessage.isEmpty {
                Text(model.syncMessage).font(.caption).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("playback-sync-status")
            }
            if !model.resumeMessage.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { resumeControls }
                    VStack(spacing: 4) { resumeControls }
                }
            }
            if !model.seekMessage.isEmpty {
                Text(model.seekMessage)
                    .font(.callout).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("playback-seek-message")
            }
            Text(model.status.label)
                .font(.callout).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("playback-status")
            if case .failed = model.status {
                Button("재생 다시 시도") { revealControls(); model.retryPlayback() }
                    .buttonStyle(StreamLabButtonStyle())
                    .accessibilityIdentifier("playback-retry")
                    .disabled(!model.canRetryPlayback)
                Text("남은 재시도: \(model.retryBudget.remaining)회")
                    .accessibilityIdentifier("playback-retry-remaining")
            } else if includesButtons {
                playbackButtons
            }
        }
    }

    private var isShowingLoading: Bool {
        model.status == .loading || model.isSeeking
    }

    @ViewBuilder private var playbackButtons: some View {
        if case .failed = model.status {
            EmptyView()
        } else {
                HStack(spacing: 32) {
                    iconButton("10초 뒤로", symbol: "gobackward.10", id: "playback-backward", size: 56) {
                        model.seek(to: model.position - 10)
                    }
                    .disabled(!model.canSeek)
                    ZStack {
                        iconButton(model.status == .ended ? "다시 재생" : (model.status == .playing ? "일시 정지" : "재생"),
                                   symbol: model.status == .ended ? "arrow.counterclockwise" : (model.status == .playing ? "pause.fill" : "play.fill"),
                                   id: "playback-toggle", size: 64) {
                            model.togglePlayback()
                        }
                        .disabled(model.player == nil || model.status == .loading || model.isSeeking)
                        .opacity(isShowingLoading ? 0 : 1)
                        .accessibilityHidden(isShowingLoading)
                        if isShowingLoading {
                            ProgressView()
                                .tint(.white)
                                .controlSize(.large)
                                .frame(width: 64, height: 64)
                                .background(.black.opacity(0.45), in: Circle())
                                .accessibilityLabel("영상 로딩 중")
                                .accessibilityIdentifier("playback-loading")
                        }
                    }
                    .frame(width: 64, height: 64)
                    iconButton("10초 앞으로", symbol: "goforward.10", id: "playback-forward", size: 56) {
                        model.seek(to: model.position + 10)
                    }
                    .disabled(!model.canSeek)
                }
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var resumeControls: some View {
        Text(model.resumeMessage).font(.caption)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("playback-resumed")
        Button("처음부터 보기") { revealControls(); model.restartFromBeginning() }
            .fixedSize(horizontal: true, vertical: false)
            .frame(minHeight: 44)
            .disabled(!model.canSeek)
            .accessibilityIdentifier("playback-restart")
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
                .accessibilityValue("\(spokenTime(scrubbing ? scrubPosition : model.position)), 전체 \(spokenTime(model.duration))")
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
                Text("\(timeText(scrubbing ? scrubPosition : model.position)) / \(timeText(model.duration))")
                    .font(.caption).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("playback-time")
                    .accessibilityValue(model.isSeeking ? "재생 위치 이동 중" :
                        (model.seekMessage.isEmpty ? "재생 위치 확인됨" : "재생 위치 이동 실패"))
                Spacer(minLength: 0)
                iconButton("자막 및 오디오 선택", symbol: "captions.bubble", id: "playback-subtitles") {
                    model.cancelNextEpisode()
                    subtitleSheet = true
                }
                .accessibilityValue(model.subtitleLabel)
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

    @ViewBuilder private var subtitleCaption: some View {
        if !model.subtitleText.isEmpty {
            Text(model.subtitleText)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
                .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityIdentifier("playback-caption")
        }
    }

    private var subtitleSelection: some View {
        GeometryReader { geometry in
            let columns = geometry.size.width >= 650 && !textSize.isAccessibilitySize
            ZStack {
                Color.black.opacity(0.9).ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button {
                            closeLanguageSelection()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("자막 및 오디오 닫기")
                        .accessibilityIdentifier("playback-subtitle-done")
                    }
                    .padding(.horizontal, 12).padding(.top, 8)
                    if columns {
                        HStack(alignment: .top, spacing: 28) {
                            languageColumn("음성", id: "playback-audio-list") { audioChoices }
                            languageColumn("자막", id: "playback-subtitle-list") { subtitleChoices }
                        }
                        .padding(.horizontal, 28).padding(.bottom, 20)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                Text("음성").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                                audioChoices
                                Divider().overlay(.white.opacity(0.15))
                                Text("자막").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                                subtitleChoices
                            }.padding(.horizontal, 20).padding(.bottom, 20)
                        }
                        .accessibilityIdentifier("playback-language-list")
                    }
                }
                .frame(maxWidth: 1100)
                .frame(height: max(0, geometry.size.height - 32))
                .background(Color(white: 0.075), in: RoundedRectangle(cornerRadius: 28))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.25)))
                .padding(.horizontal, columns ? 24 : 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
        .accessibilityAction(.escape) { closeLanguageSelection() }
    }

    private func closeLanguageSelection() {
        subtitleSheet = false
        revealControls()
    }

    private func languageColumn<Content: View>(_ title: String, id: String,
                                               @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) { content() }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier(id)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var audioChoices: some View {
        if !model.audioOptions.isEmpty {
            audioRow(id: "automatic", label: "기본 오디오")
            ForEach(model.audioOptions) { option in
                audioRow(id: option.id, label: option.label + (option.audioRole == .audioDescription ? " · 화면 해설" : " · 일반 음성"))
            }
        }
        if model.audioLoading { ProgressView("오디오 목록을 불러오는 중…") }
        if !model.audioMessage.isEmpty {
            Text(model.audioMessage)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white.opacity(0.7))
                .accessibilityIdentifier("playback-audio-message")
        }
        if model.audioLoadFailed {
            Button("오디오 목록 다시 시도") { model.retryAudio() }
                .frame(minHeight: 44)
                .accessibilityIdentifier("playback-audio-retry")
        }
    }

    @ViewBuilder private var subtitleChoices: some View {
        Toggle("음소거 시 자막 자동 켜기", isOn: Binding(
            get: { model.captionsWhenMuted },
            set: { model.setCaptionsWhenMuted($0) }
        ))
        .accessibilityIdentifier("playback-auto-captions")
        Text("미디어 볼륨이 0이면 자막을 켭니다. 볼륨을 올리면 이전 설정으로 돌아갑니다. 직접 선택한 자막은 유지합니다.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        subtitleRow(id: "off", label: "끄기")
            .disabled(!model.canDisableSubtitles || model.subtitlesLoading)
        ForEach(model.subtitleOptions) { option in
            subtitleRow(id: option.id, label: option.label)
        }
        if model.subtitlesLoading { ProgressView("자막 목록을 불러오는 중…") }
        if !model.subtitleMessage.isEmpty {
            Text(model.subtitleMessage)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white.opacity(0.7))
                .accessibilityIdentifier("playback-subtitle-message")
        }
        if model.subtitleLoadFailed {
            Button("자막 목록 다시 시도") { model.retrySubtitles() }
                .frame(minHeight: 44)
                .accessibilityIdentifier("playback-subtitle-retry")
        }
    }

    private func languageLabel(_ label: String, selected: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .opacity(selected ? 1 : 0)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(label)
                .font(.body.weight(selected ? .semibold : .regular))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(selected ? .white : .white.opacity(0.65))
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func audioRow(id: String, label: String) -> some View {
        Button { model.selectAudio(id) } label: {
            languageLabel(label, selected: model.selectedAudioID == id)
        }
        .buttonStyle(.plain)
        .accessibilityValue(model.selectedAudioID == id ? "선택됨" : "")
        .accessibilityIdentifier("playback-audio-\(id)")
    }

    private func subtitleRow(id: String, label: String) -> some View {
        Button { model.selectSubtitle(id) } label: {
            languageLabel(label, selected: model.selectedSubtitleID == id)
        }
        .buttonStyle(.plain)
        .accessibilityValue(model.selectedSubtitleID == id ? "선택됨" : "")
        .accessibilityIdentifier("playback-subtitle-\(id)")
    }

    private var sourceSelection: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PlaybackModel.Source.allCases.filter { $0 != .downloadedHLS }) { option in
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
                        .accessibilityIdentifier("source-\(option.progressID)")
                    }
                } footer: {
                    Text("모든 작품은 선택한 테스트 소스를 재생합니다. 오프라인 데모는 30초 무음이며 HLS는 인터넷 연결이 필요합니다. 오디오 비교 소스는 영어 일반 음성과 영어 화면 해설(DVS)을 제공합니다. 서로 다른 언어의 더빙은 아닙니다. 소스별로 저장된 위치에서 이어봅니다. 연속 재생 데모 1~3화는 동일한 영상을 사용하며 화별 진행 기록은 분리됩니다. HLS 테스트 시즌은 공개 샘플 2개를 연결한 검증용 구성으로 실제 작품의 회차가 아닙니다. 1화는 테스트 패턴, 2화는 오디오 비교 샘플이며 마지막 화에서는 자동 재생이 멈춥니다.")
                }
            }
            .accessibilityIdentifier("playback-source-list")
            .navigationTitle("영상 소스")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { sourceSheet = false; revealControls() }
                }
            }
        }
    }
}
