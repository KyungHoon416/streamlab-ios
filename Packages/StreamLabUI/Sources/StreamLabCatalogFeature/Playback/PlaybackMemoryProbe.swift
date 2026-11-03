import Darwin
import StreamLabDomain
import SwiftUI

@MainActor final class PlaybackMemoryProbe: ObservableObject {
    static let enabled = ProcessInfo.processInfo.arguments.contains("--measure-hls-memory")
    @Published private(set) var run: PlaybackMemoryRun?
    @Published private(set) var error: String?
    private var played = false
    private var pending: Task<Void, Never>?

    func start() {
        guard let bytes = footprint() else { error = "메모리를 읽지 못했습니다."; return }
        pending?.cancel()
        played = false
        error = nil
        run = PlaybackMemoryRun(baseline: bytes)
    }

    func didPlay() { if run != nil { played = true } }

    func dismissed() {
        guard played, run?.finished == false else { return }
        played = false
        run?.close(played: true)
        guard run?.awaitingSample == true else { return }
        pending = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self else { return }
            guard let bytes = footprint() else {
                error = "메모리 측정에 실패했습니다. 새 측정을 시작하세요."
                return
            }
            run?.sample(bytes)
        }
    }

    private func footprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.stride)
        let capacity = Int(count)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : nil
    }

    deinit { pending?.cancel() }
}
