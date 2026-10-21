import AVFoundation
import Combine
import Foundation
import StreamLabDomain
import StreamLabPresentation

/// One process-wide owner reconnects to the OS background transfer session.
/// All metadata and delegate mutations are serialized on the main actor.
@MainActor public final class OfflineDownloadStore: NSObject, ObservableObject {
    public static let shared = OfflineDownloadStore()
    public static let sessionIdentifier = "com.example.streamlab.offline-hls.v1"
    @Published private(set) var records: [OfflineDownload] = []
    @Published private(set) var progress: [UUID: Double] = [:]
    @Published private(set) var errorMessage: String?
    @Published private(set) var retrying: Set<UUID> = []
    private struct Snapshot: Codable {
        var records: [OfflineDownload] = []
        var blockedAccounts: Set<String> = []
    }
    #if DEBUG
    @Published private(set) var validationSnapshot = "not sampled"
    private var validationPaths: Set<URL> = []
    private var validationStarted: Set<UUID> = []
    private var validationPeak = 0

    // Opt-in observation only: uses real OS tasks, journal and package paths.
    var validationEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-test-download-lifecycle")
    }
    func validationEnqueue(session: CatalogSession, count: Int) async {
        guard validationEnabled else { return }
        for number in 1...count {
            do {
                if let title = try await session.repository.detail(id: String(format: "title-%04d", number), profile: session.profile) {
                    enqueue(title: title, session: session)
                }
            } catch { validationSnapshot = "fixture error"; return }
        }
        await validationRefresh(accountID: session.accountID)
    }
    func validationInterruptTransfer() {
        guard validationEnabled else { return }
        // Real OS error callback; do not fabricate a failed record or a completion.
        tasks.values.first?.cancel()
    }
    func validationRefresh(accountID: String) async {
        guard validationEnabled else { return }
        let native = await downloads.allTasks
        let disk = journalURL.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
        let owned = records.filter { $0.accountID == accountID }
        let notificationIDs = await DownloadNotifications.shared.identifiers()
        let notificationCount = notificationIDs.filter { $0.hasPrefix(DownloadCompletionNotifier.prefix) }.count
        let files = validationPaths.filter { FileManager.default.fileExists(atPath: $0.path) }.count
        validationSnapshot = "native=\(native.count);active=\(owned.filter { $0.state == .downloading }.count);queued=\(owned.filter { $0.state == .queued }.count);complete=\(owned.filter { $0.state == .complete }.count);records=\(owned.count);disk=\(disk?.records.filter { $0.accountID == accountID }.count ?? -1);files=\(files);peak=\(validationPeak);started=\(validationStarted.count);notifications=\(notificationCount);attempt=\(owned.first?.id.uuidString ?? "none");paused=\(owned.filter { $0.state == .paused }.count);suspended=\(native.filter { $0.state == .suspended }.count)"
    }
    #endif
    private var blockedAccounts: Set<String> = []
    private var activeAccount: String?
    private var tasks: [UUID: AVAssetDownloadTask] = [:]
    private var observations: [UUID: NSKeyValueObservation] = [:]
    private var lastDiskCheck: [UUID: Date] = [:]
    private var leases: [UUID: UUID] = [:]
    private var restored = false
    private var restoring = false
    private var storageHealthy = true
    private let notifier = DownloadCompletionNotifier(backend: DownloadNotifications.shared)
    private var notificationWork = 0
    private var completionNotificationsSuppressed = false
    private var backgroundEventsFinished = false
    private var backgroundCompletion: (() -> Void)?
    private let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    private let journalURL: URL?
    private lazy var downloads: AVAssetDownloadURLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = false
        return AVAssetDownloadURLSession(configuration: config, assetDownloadDelegate: self, delegateQueue: .main)
    }()

    private override init() {
        journalURL = try? DurableMutationStore.defaultDirectory().appendingPathComponent("offline-downloads.json")
        super.init()
        do {
            guard let journalURL else { throw CocoaError(.fileReadUnknown) }
            if FileManager.default.fileExists(atPath: journalURL.path) {
                let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: journalURL))
                guard Set(snapshot.records.map(\.id)).count == snapshot.records.count,
                      snapshot.records.allSatisfy({ $0.bytes >= 0 && ($0.state != .complete || $0.relativePath != nil) && ($0.relativePath == nil || localURL($0) != nil) }) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                records = snapshot.records; blockedAccounts = snapshot.blockedAccounts
            }
        } catch {
            storageHealthy = false
            errorMessage = "다운로드 기록을 읽지 못했습니다. 기존 파일은 유지됩니다."
        }
    }

    private func save() throws {
        guard storageHealthy, let journalURL else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: journalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Snapshot(records: records, blockedAccounts: blockedAccounts))
            .write(to: journalURL, options: .atomic)
    }
    private func reportStorageFailure() {
        storageHealthy = false
        tasks.values.forEach { $0.suspend() }
        errorMessage = "다운로드 기록을 저장하지 못해 작업을 중지했습니다. 앱을 다시 실행해 주세요."
    }
    private func localURL(_ record: OfflineDownload) -> URL? {
        record.relativePath.flatMap { OfflineDownloadBudget.localURL(path: $0, home: home) }
    }
    private func index(_ id: UUID) -> Int? { records.firstIndex { $0.id == id } }

    public func activate(accountID: String) async {
        do { try await activateStore(accountID: accountID) }
        catch { reportStorageFailure() }
    }

    private func activateStore(accountID: String) async throws {
        guard storageHealthy else { throw CocoaError(.fileReadCorruptFile) }
        if blockedAccounts.contains(accountID) { try await clear(accountID: accountID) }
        blockedAccounts.remove(accountID)
        try save()
        activeAccount = accountID
        completionNotificationsSuppressed = false
        await restore()
        pump()
    }

    private func restore() async {
        if restoring {
            while restoring { try? await Task.sleep(for: .milliseconds(50)) }
            return
        }
        guard !restored else { return }
        restoring = true
        let all = await downloads.allTasks
        for task in all {
            guard let task = task as? AVAssetDownloadTask,
                  let text = task.taskDescription, let id = UUID(uuidString: text), let i = index(id),
                  (records[i].state == .downloading || records[i].state == .paused || records[i].state == .removing), storageHealthy else {
                task.cancel(); continue
            }
            tasks[id] = task; observe(task, id: id)
            if records[i].state == .removing || blockedAccounts.contains(records[i].accountID) {
                records[i].state = .removing; task.cancel()
            } else if records[i].state == .paused {
                if task.state == .running { task.suspend() }
            } else if task.state == .suspended {
                // Recover a crash after saving the journal but before resume().
                task.resume()
            }
        }
        for i in records.indices {
            if (records[i].state == .downloading || records[i].state == .paused) && tasks[records[i].id] == nil {
                records[i].state = .failed; records[i].message = "중단된 다운로드입니다. 다시 다운로드해 주세요."
                if let url = localURL(records[i]), FileManager.default.fileExists(atPath: url.path) {
                    records[i].bytes = (try? allocatedBytes(url)) ?? OfflineDownloadBudget.reservation
                }
            }
            if records[i].state == .complete, let url = localURL(records[i]),
               !FileManager.default.fileExists(atPath: url.path) {
                records[i].state = .failed; records[i].bytes = 0; records[i].relativePath = nil
                records[i].message = "기기에서 파일이 정리되었습니다. 다시 다운로드해 주세요."
            }
        }
        for record in records where record.state == .removing && tasks[record.id] == nil {
            do { try remove(record.id, schedule: false) }
            catch {
                if let i = index(record.id) {
                    records[i].state = .failed
                    records[i].message = "파일을 삭제하지 못했습니다. 삭제를 다시 시도해 주세요."
                }
                errorMessage = "중단된 다운로드 파일을 정리하지 못했습니다."
            }
        }
        restored = true; restoring = false
        do { try save(); pump() } catch { reportStorageFailure() }
    }

    func downloads(in session: CatalogSession) -> [OfflineDownload] {
        guard storageHealthy, session.isActive, activeAccount == session.accountID,
              !blockedAccounts.contains(session.accountID) else { return [] }
        return records.filter { $0.accountID == session.accountID && $0.profileID == session.profile.id }
            .sorted { $0.lastUsed == $1.lastUsed ? $0.id.uuidString < $1.id.uuidString : $0.lastUsed > $1.lastUsed }
    }

    func record(accountID: String, profileID: String, titleID: String) -> OfflineDownload? {
        records.first { $0.accountID == accountID && $0.profileID == profileID && $0.titleID == titleID }
    }

    func enqueue(title: CatalogTitle, session: CatalogSession) {
        guard storageHealthy, session.isActive, title.canView(in: session.profile),
              activeAccount == session.accountID, !blockedAccounts.contains(session.accountID) else { return }
        guard record(accountID: session.accountID, profileID: session.profile.id, titleID: title.id) == nil else { return }
        let new = OfflineDownload(accountID: session.accountID, profileID: session.profile.id,
                                  titleID: title.id, title: title.name)
        records.append(new)
        do { try save(); pump() } catch { records.removeAll { $0.id == new.id }; reportStorageFailure() }
    }

    /// Retry reauthorizes the current profile, then replaces the failed attempt
    /// with a new identity. Late callbacks/notification cancellation keep the old ID.
    func retry(_ id: UUID, session: CatalogSession) async {
        func eligible() -> Bool {
            guard storageHealthy, session.isActive, activeAccount == session.accountID,
                  !blockedAccounts.contains(session.accountID), let i = index(id) else { return false }
            return records[i].accountID == session.accountID && records[i].profileID == session.profile.id &&
                records[i].state == .failed && tasks[id] == nil && !leases.values.contains(id)
        }
        guard eligible(), !retrying.contains(id), let original = records.first(where: { $0.id == id }) else { return }
        retrying.insert(id)
        defer { retrying.remove(id) }
        let title: CatalogTitle
        do {
            guard let found = try await session.repository.detail(id: original.titleID, profile: session.profile),
                  found.canView(in: session.profile) else {
                if eligible() { errorMessage = "이 프로필에서 다시 다운로드할 수 없는 작품입니다." }
                return
            }
            title = found
        } catch {
            if eligible() { errorMessage = "작품을 확인하지 못했습니다. 잠시 후 다시 시도해 주세요." }
            return
        }
        guard eligible(), let i = index(id) else { return }
        let previous = records[i]
        do {
            if let url = localURL(previous), FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            errorMessage = "이전 다운로드 파일을 정리하지 못했습니다. 다시 시도해 주세요."
            return
        }
        notifier.cancel(id: id)
        observations[id] = nil; progress[id] = nil; lastDiskCheck[id] = nil
        var replacement = OfflineDownload(accountID: session.accountID, profileID: session.profile.id,
                                          titleID: title.id, title: title.name)
        replacement.pinned = previous.pinned
        records[i] = replacement
        do { try save() }
        catch { records[i] = previous; reportStorageFailure(); return }
        errorMessage = nil
        pump()
    }

    /// Paused native tasks retain both slot and reservation to protect partial files.
    func pause(_ id: UUID, session: CatalogSession) {
        guard owns(id, session: session), let i = index(id), records[i].state == .downloading,
              let task = tasks[id], task.state == .running else { return }
        records[i].state = .paused
        do { try save() } catch { records[i].state = .downloading; reportStorageFailure(); return }
        task.suspend()
    }

    func resume(_ id: UUID, session: CatalogSession) {
        guard owns(id, session: session), let i = index(id), records[i].state == .paused,
              let task = tasks[id], task.state == .suspended else { return }
        guard let available = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage, available >= 50_000_000 else {
            errorMessage = "기기 저장 공간이 부족해 재개할 수 없습니다. 공간을 확보한 뒤 다시 눌러 주세요."
            return
        }
        records[i].state = .downloading
        do { try save() } catch { records[i].state = .paused; reportStorageFailure(); return }
        errorMessage = nil
        task.resume()
    }

    private func owns(_ id: UUID, session: CatalogSession) -> Bool {
        guard storageHealthy, restored, session.isActive, activeAccount == session.accountID,
              !blockedAccounts.contains(session.accountID), let i = index(id) else { return false }
        return records[i].accountID == session.accountID && records[i].profileID == session.profile.id
    }

    private func pump() {
        guard storageHealthy, restored, let activeAccount, !blockedAccounts.contains(activeAccount) else { return }
        while records.filter({ $0.state == .downloading || $0.state == .paused || $0.state == .removing }).count < OfflineDownloadBudget.concurrentLimit,
              let id = records.first(where: { $0.state == .queued && $0.accountID == activeAccount })?.id {
            do {
                let evictions = try OfflineDownloadBudget.evictions(in: records, protected: Set(leases.values))
                for victim in evictions { try remove(victim, schedule: false) }
                let capacity = try home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                    .volumeAvailableCapacityForImportantUsage
                guard let capacity, capacity >= OfflineDownloadBudget.reservation + 50_000_000 else {
                    throw CocoaError(.fileWriteOutOfSpace)
                }
                guard let i = index(id), let url = PlaybackModel.Source.hls.url else { return }
                let asset = AVURLAsset(url: url)
                let config = AVAssetDownloadConfiguration(asset: asset, title: records[i].title + " · HLS 샘플")
                let task = downloads.makeAssetDownloadTask(downloadConfiguration: config)
                task.taskDescription = id.uuidString
                records[i].state = .downloading
                do { try save() } catch { task.cancel(); reportStorageFailure(); return }
                tasks[id] = task; observe(task, id: id); task.resume()
                #if DEBUG
                if validationEnabled {
                    validationStarted.insert(id)
                    validationPeak = max(validationPeak, tasks.count)
                }
                #endif
            } catch {
                guard let i = index(id) else { continue }
                records[i].state = .failed
                records[i].message = "저장 공간이 부족하거나 다운로드를 시작할 수 없습니다. 고정을 해제하거나 파일을 삭제해 주세요."
                do { try save() } catch { reportStorageFailure(); return }
            }
        }
    }

    private func observe(_ task: AVAssetDownloadTask, id: UUID) {
        observations[id] = task.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] value, _ in
            let fraction = value.fractionCompleted
            let received = task.countOfBytesReceived
            Task { @MainActor [weak self] in
                guard let self, let i = self.index(id), self.records[i].state == .downloading else { return }
                self.progress[id] = fraction.isFinite ? min(1, max(0, fraction)) : 0
                if received > OfflineDownloadBudget.reservation { NSLog("Offline HLS exceeded reservation"); self.tasks[id]?.cancel() }
                if Date().timeIntervalSince(self.lastDiskCheck[id] ?? .distantPast) >= 2 {
                    self.lastDiskCheck[id] = Date()
                    if let capacity = try? self.home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                        .volumeAvailableCapacityForImportantUsage, capacity < 50_000_000 {
                        NSLog("Offline HLS low disk capacity: %lld", capacity)
                        self.tasks[id]?.cancel()
                    }
                }
            }
        }
    }

    func togglePin(_ id: UUID) {
        guard storageHealthy, let i = index(id), records[i].accountID == activeAccount else { return }
        records[i].pinned.toggle()
        do { try save() } catch { records[i].pinned.toggle(); reportStorageFailure() }
    }

    func delete(_ id: UUID) {
        guard let i = index(id), records[i].accountID == activeAccount else { return }
        do { try remove(id) } catch { errorMessage = "사용 중이거나 삭제할 수 없는 다운로드입니다." }
    }

    private func remove(_ id: UUID, schedule: Bool = true) throws {
        guard storageHealthy, !leases.values.contains(id), let i = index(id) else { throw CocoaError(.fileWriteNoPermission) }
        notifier.cancel(id: id)
        if let task = tasks[id] {
            records[i].state = .removing
            try save() // Keep a tombstone/path until cancellation has actually completed.
            task.cancel()
            return
        }
        observations[id] = nil; progress[id] = nil; lastDiskCheck[id] = nil
        // Keep the record if deletion fails so quota accounting and later cleanup retain it.
        if let url = localURL(records[i]), FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        records.remove(at: i)
        do { try save() } catch { reportStorageFailure(); throw error }
        if schedule { pump() }
    }

    public func suppressCompletionNotifications() {
        completionNotificationsSuppressed = true
        notifier.invalidateAll()
        // Includes identifiers restored from disk, before logout can suspend.
        for record in records { notifier.cancel(id: record.id) }
    }

    public func clear(accountID: String) async throws {
        suppressCompletionNotifications()
        if activeAccount == accountID { activeAccount = nil }
        blockedAccounts.insert(accountID)
        if !storageHealthy {
            await notifier.removeAll()
            for task in await downloads.allTasks { task.cancel() }
            throw CocoaError(.fileReadCorruptFile)
        }
        try save() // Durable revocation precedes cancellation or deletion.
        await notifier.removeAll()
        await restore()
        let ids = records.filter { $0.accountID == accountID }.map(\.id)
        for id in ids { try remove(id, schedule: false) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while records.contains(where: { $0.accountID == accountID && $0.state == .removing }) {
            guard ContinuousClock.now < deadline else { throw CocoaError(.fileWriteUnknown) }
            try await Task.sleep(for: .milliseconds(50))
        }
        guard !records.contains(where: { $0.accountID == accountID }) else { throw CocoaError(.fileWriteUnknown) }
        // Retain the revocation marker until explicit sign-in succeeds.
    }

    func acquire(session: CatalogSession, titleID: String) -> (URL, UUID)? {
        guard storageHealthy, session.isActive, activeAccount == session.accountID,
              !blockedAccounts.contains(session.accountID),
              let item = record(accountID: session.accountID, profileID: session.profile.id, titleID: titleID),
              item.state == .complete, let url = localURL(item),
              AVURLAsset(url: url).assetCache?.isPlayableOffline == true, let i = index(item.id) else { return nil }
        records[i].lastUsed = Date()
        do { try save() } catch { reportStorageFailure(); return nil }
        let lease = UUID(); leases[lease] = item.id
        return (url, lease)
    }
    func release(_ lease: UUID) { leases[lease] = nil }

    private func notifyCompletion(_ id: UUID) {
        guard DownloadNotifications.shared.isInBackground else { return }
        notificationWork += 1
        Task {
            await notifier.deliver(id: id) { [weak self] in
                guard let self, let i = self.index(id) else { return false }
                return self.storageHealthy && !self.completionNotificationsSuppressed && self.records[i].state == .complete &&
                    !self.blockedAccounts.contains(self.records[i].accountID) &&
                    DownloadNotifications.shared.isInBackground
            }
            notificationWork -= 1
            finishBackgroundEventsIfReady()
        }
    }
    private func finishBackgroundEventsIfReady() {
        guard restored, !restoring, backgroundEventsFinished, notificationWork == 0, let completion = backgroundCompletion else { return }
        backgroundCompletion = nil
        backgroundEventsFinished = false
        completion()
    }

    public func handleBackgroundEvents(completion: @escaping () -> Void) {
        backgroundCompletion = completion
        Task { await restore(); finishBackgroundEventsIfReady() }
    }

    private func allocatedBytes(_ url: URL) throws -> Int64 {
        // Inspect sizes only; never move or change the private HLS package contents.
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let entries = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys)) else {
            throw CocoaError(.fileReadUnknown)
        }
        var total: Int64 = 0
        for case let file as URL in entries {
            let values = try file.resourceValues(forKeys: keys)
            if values.isRegularFile == true {
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }
        return total
    }
}

extension OfflineDownloadStore: AVAssetDownloadDelegate {
    nonisolated public func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, willDownloadTo location: URL) {
        // AVAssetDownloadURLSession was explicitly configured with OperationQueue.main.
        MainActor.assumeIsolated {
            guard let text = assetDownloadTask.taskDescription, let id = UUID(uuidString: text), let i = index(id),
                  storageHealthy else { assetDownloadTask.cancel(); return }
            guard let relative = OfflineDownloadBudget.relativePath(location: location, home: home) else {
                NSLog("Offline HLS rejected package location outside app container")
                #if DEBUG
                let diagnostic = "Offline HLS path diagnostic: home=\(home.path) parent=\(location.deletingLastPathComponent().path) extension=\(location.pathExtension)\n"
                FileHandle.standardOutput.write(Data(diagnostic.utf8))
                #endif
                assetDownloadTask.cancel(); return
            }
            #if DEBUG
            if validationEnabled, let url = OfflineDownloadBudget.localURL(path: relative, home: home) {
                validationPaths.insert(url)
            }
            #endif
            records[i].relativePath = relative
            do { try save() } catch { assetDownloadTask.cancel(); reportStorageFailure() }
            if records[i].state == .removing || blockedAccounts.contains(records[i].accountID) { assetDownloadTask.cancel() }
        }
    }

    nonisolated public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        MainActor.assumeIsolated {
            guard let text = task.taskDescription, let id = UUID(uuidString: text), let i = index(id) else { return }
            if let error = error as NSError? { NSLog("Offline HLS transfer failed: %@ %ld", error.domain, error.code) }
            let completedWhilePaused = records[i].state == .paused
            tasks[id] = nil; observations[id] = nil; progress[id] = nil
            guard storageHealthy else { return }
            if records[i].state == .removing || blockedAccounts.contains(records[i].accountID) {
                do { try remove(id) } catch {
                    if let remaining = index(id) {
                        records[remaining].state = .failed
                        records[remaining].message = "파일을 삭제하지 못했습니다. 삭제를 다시 시도해 주세요."
                        do { try save() } catch { reportStorageFailure() }
                    }
                    errorMessage = "다운로드 파일 정리를 완료하지 못했습니다."
                }
                return
            }
            do {
                guard !blockedAccounts.contains(records[i].accountID), error == nil,
                      let url = localURL(records[i]), AVURLAsset(url: url).assetCache?.isPlayableOffline == true else {
                    throw CocoaError(.fileReadUnknown)
                }
                let bytes = try allocatedBytes(url)
                records[i].bytes = bytes
                guard bytes > 0, bytes <= OfflineDownloadBudget.reservation else { throw CocoaError(.fileWriteOutOfSpace) }
                records[i].bytes = bytes; records[i].state = .complete; records[i].message = nil
                try save()
                if !completedWhilePaused { notifyCompletion(id) }
            } catch {
                records[i].state = .failed
                records[i].message = "다운로드를 완료하지 못했습니다. Wi-Fi와 저장 공간을 확인한 뒤 다시 다운로드해 주세요."
                if let url = localURL(records[i]), FileManager.default.fileExists(atPath: url.path) {
                    do {
                        try FileManager.default.removeItem(at: url)
                        records[i].relativePath = nil; records[i].bytes = 0
                    } catch { records[i].bytes = max(records[i].bytes, (try? allocatedBytes(url)) ?? OfflineDownloadBudget.reservation) }
                }
                do { try save() } catch { reportStorageFailure() }
            }
            pump()
        }
    }

    nonisolated public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        MainActor.assumeIsolated {
            backgroundEventsFinished = true
            finishBackgroundEventsIfReady()
        }
    }
}
